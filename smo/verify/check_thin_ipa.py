#!/usr/bin/env python3
"""Check shell/personal IPA boundaries, including native game code sections.

The explicit legacy policy is only for the old packaging tools. New public
packages must pass shell; nxnative personal packages must pass personal.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import plistlib
import struct
import sys
import zipfile

FORBIDDEN_SUFFIXES = (".nsp", ".xci", ".nsz", ".xcz", ".nca", ".tik", ".szs", ".sharc", ".sharcb", ".bfsha", ".patched.bin", ".keys")


def code_sections(stream) -> list[str]:
    header = stream.read(32)
    if header[:4] != b"\xcf\xfa\xed\xfe":
        return []
    if len(header) != 32:
        raise ValueError("Truncated Mach-O header")
    _, cpu, _, _, count, size, _, _ = struct.unpack("<8I", header)
    if cpu != 0x100000c or size > 16 * 1024 ** 2 or count > size // 8:
        raise ValueError("Invalid arm64 Mach-O load commands")
    commands = stream.read(size)
    if len(commands) != size:
        raise ValueError("Truncated Mach-O commands")
    found, offset = [], 0
    for _ in range(count):
        if offset + 8 > size:
            raise ValueError("Truncated Mach-O command")
        kind, length = struct.unpack_from("<II", commands, offset)
        if length < 8 or offset + length > size:
            raise ValueError("Invalid Mach-O command length")
        if kind == 0x19:
            if length < 72:
                raise ValueError("Invalid Mach-O segment")
            segment = commands[offset + 8:offset + 24].split(b"\0")[0].decode("ascii")
            n = struct.unpack_from("<I", commands, offset + 64)[0]
            if 72 + n * 80 > length:
                raise ValueError("Invalid Mach-O section count")
            if segment.lower().startswith("__dm"):
                found.append(segment)
            for i in range(n):
                name = commands[offset + 72 + 80 * i:offset + 88 + 80 * i].split(b"\0")[0].decode("ascii")
                if name.lower().startswith("__dm"):
                    found.append(name)
        offset += length
    return found

def inspect(path: Path, policy: str = "shell") -> dict:
    if policy not in ("shell", "personal", "legacy"):
        raise ValueError("Unknown IPA policy: " + policy)
    if not path.is_file():
        raise ValueError(f"IPA not found: {path}")
    forbidden, native_sections, errors = [], {}, []
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            errors.append("Duplicate ZIP entries")
        for name in names:
            normalized = "/" + name.replace("\\", "/").lower()
            raw = any(normalized.endswith(s) for s in FORBIDDEN_SUFFIXES) or "/exefs/" in normalized or "/romfs/" in normalized
            raw |= normalized.rsplit("/", 1)[-1].startswith("romfs.smoa.")
            derived = any(x in normalized for x in ("/msl/", "/runtimeshaders/", "/guest.framework/"))
            derived |= normalized.endswith((".metallib", ".metal", ".air", ".smoa", "/icon.jpg", "/control.nacp"))
            if policy == "shell":
                derived |= normalized.endswith((".fixups.tsv", ".gates.tsv", ".params.tsv", ".cuts.tsv", ".obs.tsv"))
                derived |= normalized.endswith(("/shader_map.tsv", "/pso_manifest.tsv", "/c1_full.tsv"))
            if raw or (policy != "legacy" and derived and not name.endswith("/")):
                forbidden.append(name)
            if name.endswith("/"):
                continue
            with archive.open(name) as stream:
                prefix = stream.read(4)
            if prefix in (b"NSO0", b"MTLB") and policy != "legacy":
                forbidden.append(name)
            if prefix in (b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca",
                          b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf") and policy != "legacy":
                errors.append("Unexpected non-arm64 or universal executable: " + name)
            if prefix == b"\xcf\xfa\xed\xfe" and policy != "legacy":
                with archive.open(name) as stream:
                    sections = code_sections(stream)
                if sections:
                    native_sections[name] = sections
                    if policy == "shell":
                        forbidden.append(name)
        if policy != "legacy":
            app_roots = sorted({"/".join(n.split("/")[:2]) for n in names
                                if n.startswith("Payload/") and len(n.split("/")) > 2 and n.split("/")[1].endswith(".app")})
            if len(app_roots) == 1:
                try:
                    info = plistlib.loads(archive.read(app_roots[0] + "/Info.plist"))
                    executable = app_roots[0] + "/" + info["CFBundleExecutable"]
                    with archive.open(executable) as stream:
                        if stream.read(4) != b"\xcf\xfa\xed\xfe":
                            errors.append("Main executable is not arm64 Mach-O")
                    if info.get("MinimumOSVersion") != "26.0":
                        errors.append("MinimumOSVersion must be 26.0")
                    main_sections = native_sections.get(executable, [])
                    if policy == "personal":
                        for module in ("main", "subsdk0", "sdk"):
                            for suffix in ("x0", "x1"):
                                if f"__dm{module}{suffix}" not in main_sections:
                                    errors.append(f"Missing embedded {module} {suffix}")
                except (KeyError, ValueError, plistlib.InvalidFileException) as error:
                    errors.append("Invalid application metadata: " + str(error))
    apps = sorted({n.split("/", 2)[0] + "/" + n.split("/", 2)[1] + "/"
                   for n in names if n.startswith("Payload/") and len(n.split("/", 2)) > 1
                   and n.split("/", 2)[1].endswith(".app")})
    runtime = [n for n in names if "/runtimeshaders/" in ("/" + n.lower())]
    forbidden = sorted(set(forbidden))
    return {"ipa": str(path.resolve()), "bytes": path.stat().st_size, "entries": len(names), "policy": policy,
            "apps": apps, "runtime_shader_entries": len(runtime),
            "forbidden_entries": forbidden, "native_game_sections": native_sections, "errors": errors,
            "thin": not forbidden and not errors and len(apps) == 1}

def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--json", type=Path)
    parser.add_argument("--policy", choices=("shell", "personal", "legacy"), default="shell")
    args = parser.parse_args(argv)
    try:
        report = inspect(args.ipa, args.policy)
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
