#!/usr/bin/env python3
import tempfile
from pathlib import Path
import zipfile
from check_thin_ipa import inspect

def main() -> int:
    with tempfile.TemporaryDirectory(prefix="smo-thin-ipa-") as temp:
        root = Path(temp)
        good = root / "good.ipa"
        with zipfile.ZipFile(good, "w") as archive:
            archive.writestr("Payload/SMOMobile.app/Info.plist", b"plist")
            archive.writestr("Payload/SMOMobile.app/RuntimeShaders/shaders.smoa", b"shader")
        report = inspect(good)
        assert report["thin"] and report["runtime_shader_entries"] == 1
        bad = root / "bad.ipa"
        with zipfile.ZipFile(bad, "w") as archive:
            archive.writestr("Payload/SMOMobile.app/ExeFS/main", b"game")
        assert not inspect(bad)["thin"]
    print("check_thin_ipa selftest: PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
