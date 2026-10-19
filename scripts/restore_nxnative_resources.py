#!/usr/bin/env python3
"""Verify and restore the external resource ZIP parts on Windows, macOS or Linux."""
import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "smo/nxnative"))
from package import restore_resources


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("parts", type=Path, help="resources-parts.json from the personal delivery")
    parser.add_argument("destination", type=Path, help="folder whose contents will be copied to Documents")
    args = parser.parse_args()
    try:
        manifest = restore_resources(args.parts, args.destination)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"Restore failed: {error}\n")
    print(f"Verified {len(manifest['files'])} files. Copy the contents of {args.destination} to the app's Documents.")


if __name__ == "__main__":
    main()
