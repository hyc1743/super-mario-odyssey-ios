#!/usr/bin/env python3
"""Generate an nxnative-compatible shader profile from the local game tree.

The nxnative checkout is supplied separately with --nxnative-root; generated
tables are written to an output directory outside the repository by default.
No game bytes are copied into this source tree or into an IPA by this tool.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


GAME = "0100000000010000"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--nxnative-root", type=Path, required=True)
    ap.add_argument("--romfs", type=Path, required=True)
    ap.add_argument("--main", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    root = args.nxnative_root.resolve()
    tool = root / "dm" / "gfx" / "tools" / "shader_split.py"
    profile = root / "dm" / "games" / GAME
    if not tool.is_file() or not (profile / "game.tsv").is_file():
        raise SystemExit("nxnative checkout does not contain the Odyssey profile")
    for path in (args.romfs, args.main):
        if not path.exists():
            raise SystemExit(f"missing input: {path}")
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="smo-nxnative-profile-") as td:
        td = Path(td)
        # Keep the profile outside the repository and only override its
        # package/build identity for the current local resource set.
        local_profile = td / GAME
        shutil.copytree(profile, local_profile)
        game = local_profile / "game.tsv"
        text = game.read_text(encoding="utf-8")
        text = text.replace("package\tv393216", "package\tv0")
        text = text.replace("shader_versions\tv393216", "shader_versions\tv0")
        game.write_text(text, encoding="utf-8")
        env = os.environ.copy()
        env.update({"DM_GAME": GAME, "DM_GAMES_DIR": str(td), "PYTHONIOENCODING": "utf-8"})
        cmd = [sys.executable, str(tool), str(args.romfs), str(args.main),
               str(args.output / "shader-pkg"), str(args.output / "shader_map.tsv"),
               str(args.output / "shader_facts.tsv"), str(args.output / "shader_pairs.tsv")]
        subprocess.run(cmd, env=env, check=True)
    print(f"NXNATIVE_PROFILE_READY game={GAME} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
