#!/usr/bin/env python3
"""Create an installable IPA from a thin shell and a local Guest.framework."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def inject(shell: Path, framework: Path, output: Path) -> None:
    with zipfile.ZipFile(shell) as source:
        names = source.namelist()
        apps = sorted({"Payload/" + n.split("/", 2)[1] + "/"
                       for n in names if n.startswith("Payload/") and len(n.split("/", 2)) > 1
                       and n.split("/", 2)[1].endswith(".app")})
        if not apps:
            raise ValueError("shell IPA has no Payload/*.app entry")
        app = apps[0].rstrip("/")
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as target:
            for name in names:
                if name.startswith(app + "/Frameworks/"):
                    continue
                target.writestr(name, source.read(name))
            base = app + "/Frameworks/Guest.framework/"
            for path in framework.rglob("*"):
                if path.is_file():
                    target.write(path, base + path.relative_to(framework).as_posix())

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Inject local Guest.framework into a thin IPA")
    parser.add_argument("--shell-ipa", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--framework", type=Path)
    parser.add_argument("--rewrite", type=Path, default=ROOT / "work" / "rewrite")
    args = parser.parse_args(argv)
    framework = args.framework
    if framework is None:
        sys.path.insert(0, str(HERE))
        import guest_dylib
        build_dir = args.output.parent / "Guest.framework.build"
        framework, size = guest_dylib.write(str(args.rewrite), str(build_dir), ("sdk", "subsdk0", "main"))
        framework = Path(framework)
        print(f"generated Guest.framework: {framework} ({size} bytes)")
    if not args.shell_ipa.is_file() or not (framework / "Guest").is_file():
        print("shell IPA or Guest.framework/Guest is missing", file=sys.stderr)
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    inject(args.shell_ipa, framework, args.output)
    sys.path.insert(0, str(ROOT / "smo" / "verify"))
    from check_thin_ipa import inspect
    report = inspect(args.output, policy="legacy")
    (args.output.parent / "thin_ipa_report.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if not report["thin"]:
        print("generated IPA failed thin-package verification", file=sys.stderr)
        return 3
    print(f"installable IPA: {args.output} ({args.output.stat().st_size} bytes)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
