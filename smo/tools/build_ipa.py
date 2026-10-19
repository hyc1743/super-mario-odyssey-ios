#!/usr/bin/env python3
"""Build or validate a thin SMO iOS package.

The game payload stays outside the IPA.  This entry point validates the
existing ExeFS/RomFS layout, writes a reproducible report, and can delegate
the actual macOS Xcode build to ``smo/ios/shell_build.sh``.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import re
from typing import Iterable


ROOT = Path(__file__).resolve().parents[2]


class ResourceError(RuntimeError):
    pass


def deployment_target() -> str | None:
    project = ROOT / "smo" / "ios" / "project.yml"
    if not project.is_file():
        return None
    match = re.search(r'^\s+iOS:\s*["\']([^"\']+)["\']', project.read_text(encoding="utf-8"), re.MULTILINE)
    return match.group(1) if match else None


def sha256_file(path: Path, chunk: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while data := stream.read(chunk):
            digest.update(data)
    return digest.hexdigest()


def find_layout(root: Path) -> tuple[Path, Path | None, Path]:
    """Find ExeFS and RomFS without copying or modifying game data."""
    candidates = [root, *[p for p in root.iterdir() if p.is_dir()]] if root.is_dir() else []
    for base in candidates:
        exefs = base / "ExeFS"
        romfs = base / "RomFS"
        if exefs.is_dir() and (romfs.is_dir() or list(base.glob("RomFS.smoa.*"))):
            return exefs, romfs if romfs.is_dir() else None, base
    raise ResourceError(
        f"未找到兼容资源布局：{root} 下需要 ExeFS/ 和 RomFS/，"
        "或一个包含这两个目录的包装目录"
    )


def find_volumes(root: Path, romfs: Path | None = None) -> list[Path]:
    locations = [root]
    if romfs is not None and romfs != root:
        locations.append(romfs)
    found = []
    for location in locations:
        found.extend(location.glob("RomFS.smoa.*"))
    volumes = sorted(set(found), key=lambda p: int(p.name.rsplit(".", 1)[1])
                     if p.name.rsplit(".", 1)[1].isdigit() else 10**9)
    if not volumes:
        return []
    expected = list(range(len(volumes)))
    actual = [int(p.name.rsplit(".", 1)[1]) for p in volumes]
    if actual != expected:
        raise ResourceError(f"RomFS 分卷不连续：期望 {expected}，实际 {actual}")
    return volumes


def require_files(exefs: Path) -> list[str]:
    required = ("main", "sdk", "subsdk0", "rtld")
    return [name for name in required if not (exefs / name).is_file()]


def read_build_id(path: Path) -> str | None:
    """Read the fixed NSO build-id field without requiring the decompressor."""
    with path.open("rb") as stream:
        header = stream.read(0x60)
    if len(header) < 0x60 or header[:4] != b"NSO0":
        return None
    return header[0x40:0x60].hex()


def inspect_resources(resource_root: Path, game_version: str | None = None) -> dict:
    exefs, romfs, wrapper = find_layout(resource_root)
    volumes = find_volumes(wrapper, romfs)
    missing = require_files(exefs)
    if missing:
        raise ResourceError(f"ExeFS 缺少必要模块：{', '.join(missing)}")
    romfs_entries = sum(1 for p in romfs.rglob("*") if p.is_file()) if romfs else 0
    if not romfs_entries and not volumes:
        raise ResourceError(f"RomFS 为空：{wrapper}")

    module_info = {}
    for name in ("main", "sdk", "subsdk0", "rtld"):
        path = exefs / name
        module_info[name] = {"bytes": path.stat().st_size, "sha256": sha256_file(path)}
    volume_info = [{"name": p.name, "bytes": p.stat().st_size, "sha256": sha256_file(p)} for p in volumes]
    return {
        "format": 1,
        "resource_root": str(resource_root.resolve()),
        "wrapper": str(wrapper.resolve()) if wrapper else None,
        "exefs": str(exefs.resolve()),
        "romfs": str(romfs.resolve()) if romfs else None,
        "romfs_entries": romfs_entries,
        "romfs_volumes": volume_info,
        "exefs_modules": module_info,
        "game_build_id": read_build_id(exefs / "main"),
        "game_version": game_version or os.environ.get("SMO_GAME_VERSION"),
        "ios_deployment_target": deployment_target(),
        "guest_minimum_ios": "26.0",
        "ipa_payload_policy": "game resources remain outside IPA",
    }


def write_report(report: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_shell(output: Path, env: dict[str, str]) -> int:
    script = ROOT / "smo" / "ios" / "shell_build.sh"
    if not script.is_file():
        raise ResourceError(f"找不到 iOS 构建脚本：{script}")
    output.mkdir(parents=True, exist_ok=True)
    merged = os.environ.copy()
    merged.update(env)
    merged["SMO_OUT"] = str(output)
    return subprocess.run(["bash", str(script)], cwd=script.parent, env=merged).returncode


def package_installable(shell_ipa: Path, output: Path, rewrite: Path) -> int:
    script = ROOT / "smo" / "ios" / "tools" / "package_installable.py"
    return subprocess.run([sys.executable, str(script), "--shell-ipa", str(shell_ipa),
                           "--rewrite", str(rewrite), "--output", str(output)], cwd=ROOT).returncode


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate resources and build a thin SMO IPA")
    parser.add_argument("--resources", required=True, type=Path, help="现有 ExeFS/RomFS 或其包装目录")
    parser.add_argument("--output", type=Path, default=ROOT / "out" / "ipa", help="构建输出目录")
    parser.add_argument("--report", type=Path, help="JSON 构建报告路径")
    parser.add_argument("--build", action="store_true", help="在 macOS 上调用 shell_build.sh")
    parser.add_argument("--installable", action="store_true", help="build or reuse a shell IPA and inject Guest.framework")
    parser.add_argument("--shell-ipa", type=Path, help="existing shell IPA")
    parser.add_argument("--rewrite", type=Path, default=ROOT / "work" / "rewrite", help="patched guest output directory")
    parser.add_argument("--game-version", help="explicit game version label, e.g. v0 or 1.2.1")
    args = parser.parse_args(list(argv) if argv is not None else None)

    try:
        report = inspect_resources(args.resources.resolve(), args.game_version)
    except (OSError, ResourceError) as error:
        print(f"资源检查失败：{error}", file=sys.stderr)
        return 2
    if report["ios_deployment_target"] != report["guest_minimum_ios"]:
        print(f"iOS deployment target ????App={report['ios_deployment_target']} Guest={report['guest_minimum_ios']}", file=sys.stderr)
        return 6

    if args.shell_ipa and not args.shell_ipa.is_file():
        print(f"shell IPA ????{args.shell_ipa}", file=sys.stderr)
        return 4
    report["build_requested"] = args.build
    report["installable_requested"] = args.installable
    report["thin_ipa"] = True
    report_path = args.report or (args.output / "build_report.json")
    write_report(report, report_path)
    print(f"???????ExeFS={report['exefs_modules'].keys()} RomFS ??={report['romfs_entries']} ??={len(report['romfs_volumes'])}")
    print(f"?????{report_path}")
    print("?????????? Documents????? IPA")

    if not args.build and not args.installable:
        return 0
    shell_ipa = args.shell_ipa
    if args.build:
        if sys.platform != "darwin":
            print("?????? macOS??????????? xcodebuild?", file=sys.stderr)
            return 3
        rc = run_shell(args.output, {"SMO_RESOURCE_ROOT": str(args.resources.resolve())})
        if rc:
            return rc
        shell_ipa = args.output / "SMOMobile-shell.ipa"
    if not args.installable:
        return 0
    if shell_ipa is None:
        shell_ipa = args.output / "SMOMobile-shell.ipa"
    if not shell_ipa.is_file():
        print(f"??? shell IPA?{shell_ipa}", file=sys.stderr)
        return 5
    return package_installable(shell_ipa, args.output / "SMOMobile-installable.ipa", args.rewrite)


if __name__ == "__main__":
    raise SystemExit(main())
