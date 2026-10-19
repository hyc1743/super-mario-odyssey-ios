#!/usr/bin/env python3
"""Verify that an IPA is a shell package and has no game payload."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys
import zipfile

FORBIDDEN_SUFFIXES = (".nsp", ".nca", ".tik", ".szs", ".sharc", ".sharcb", ".bfsha")

def inspect(path: Path) -> dict:
    if not path.is_file():
        raise ValueError(f"IPA not found: {path}")
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
    forbidden = []
    for name in names:
        normalized = "/" + name.replace("\\", "/").lower()
        if any(normalized.endswith(s) for s in FORBIDDEN_SUFFIXES) or "/exefs/" in normalized or "/romfs/" in normalized:
            forbidden.append(name)
    apps = sorted({n.split("/", 2)[0] + "/" + n.split("/", 2)[1] + "/"
                   for n in names if n.startswith("Payload/") and len(n.split("/", 2)) > 1
                   and n.split("/", 2)[1].endswith(".app")})
    runtime = [n for n in names if "/runtimeshaders/" in ("/" + n.lower())]
    return {"ipa": str(path.resolve()), "bytes": path.stat().st_size, "entries": len(names),
            "apps": apps, "runtime_shader_entries": len(runtime),
            "forbidden_entries": forbidden, "thin": not forbidden and len(apps) == 1}

def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args(argv)
    try:
        report = inspect(args.ipa)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"thin IPA check failed: {error}", file=sys.stderr)
        return 2
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))
    if not report["thin"]:
        print("thin IPA check failed: game payload found or app entry count is invalid", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
