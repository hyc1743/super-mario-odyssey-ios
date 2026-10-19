#!/usr/bin/env python3
"""Check that all iOS build surfaces use the same minimum OS version."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
EXPECTED = "26.0"

def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")

def main() -> int:
    project = read(ROOT / "smo/ios/project.yml")
    frontend = read(ROOT / "smo/ios/frontend-tests.yml")
    guest = read(ROOT / "smo/ios/tools/guest_dylib.py")
    workflow = read(ROOT / ".github/workflows/build-shell-ipa.yml")
    checks = {
        "application deployment target": 'iOS: "26.0"' in project,
        "frontend deployment target": 'iOS: "26.0"' in frontend,
        "guest Mach-O target": "MIN_IOS = 26 << 16" in guest,
        "guest Info.plist target": "<string>26.0</string>" in guest,
        "CI syntax target": "apple-ios26.0" in workflow,
    }
    failed = [name for name, ok in checks.items() if not ok]
    if failed:
        print("iOS contract failed: " + ", ".join(failed), file=sys.stderr)
        return 1
    print(f"iOS contract: PASS (minimum {EXPECTED})")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
