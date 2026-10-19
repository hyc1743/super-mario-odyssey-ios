#!/usr/bin/env python3
"""Small, platform-independent tests for the thin-IPA resource gate."""

from pathlib import Path
import tempfile

from build_ipa import ResourceError, inspect_resources


def touch(path: Path, data: bytes = b"fixture") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def make_exefs(root: Path) -> None:
    for name in ("main", "sdk", "subsdk0", "rtld"):
        touch(root / "ExeFS" / name, name.encode())


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="smo-build-ipa-") as temp:
        root = Path(temp)
        make_exefs(root)
        touch(root / "RomFS" / "SystemData" / "fixture")
        report = inspect_resources(root)
        assert report["romfs_entries"] == 1
        assert len(report["romfs_volumes"]) == 0

        volume_root = root / "volume-only"
        make_exefs(volume_root)
        touch(volume_root / "RomFS.smoa.0", b"SMOA\0\1")
        volume_report = inspect_resources(volume_root)
        assert len(volume_report["romfs_volumes"]) == 1

        broken = root / "broken"
        make_exefs(broken)
        touch(broken / "RomFS.smoa.1", b"bad")
        try:
            inspect_resources(broken)
        except ResourceError:
            pass
        else:
            raise AssertionError("non-contiguous volumes must be rejected")

    print("build_ipa resource gate selftest: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
