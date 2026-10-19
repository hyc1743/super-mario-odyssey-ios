#!/usr/bin/env python3
import tempfile
from pathlib import Path
import zipfile

from package_installable import inject


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="smo-package-ipa-") as temp:
        root = Path(temp)
        shell = root / "shell.ipa"
        framework = root / "Guest.framework"
        output = root / "installable.ipa"
        framework.mkdir()
        (framework / "Guest").write_bytes(b"guest")
        (framework / "Info.plist").write_text("plist", encoding="utf-8")
        with zipfile.ZipFile(shell, "w") as archive:
            archive.writestr("Payload/SMOMobile.app/Info.plist", b"plist")
            archive.writestr("Payload/SMOMobile.app/RuntimeShaders/shaders.smoa", b"shader")
        inject(shell, framework, output)
        with zipfile.ZipFile(output) as archive:
            names = archive.namelist()
            assert "Payload/SMOMobile.app/Frameworks/Guest.framework/Guest" in names
            assert not any("ExeFS" in name or "RomFS" in name for name in names)
    print("package_installable selftest: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
