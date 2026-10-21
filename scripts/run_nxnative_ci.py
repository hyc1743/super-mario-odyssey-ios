#!/usr/bin/env python3
"""Run a public personal build with bounded, private progress snapshots."""
from __future__ import annotations

import argparse
import concurrent.futures
from pathlib import Path
import re
import subprocess
import sys
import time

from nxnative_github import publish


def progress(log):
    """Expose counts/stages only, keeping tool output and file paths private."""
    try:
        with log.open("rb") as stream:
            stream.seek(max(0, log.stat().st_size - 16384))
            tail = stream.read().decode("utf-8", errors="replace")
    except OSError:
        return "Starting build"
    counts = re.findall(r"(\d[\d,]*)/(\d[\d,]*) shaders", tail)
    if "Building unsigned personal IPA" in tail:
        return "Building iOS application"
    files = re.findall(r"External resources: (\d+) files", tail)
    if files:
        return f"Archiving external resources: {files[-1]} files"
    if counts:
        return f"Preparing shader libraries: {counts[-1][0]} / {counts[-1][1]}"
    return "Preparing game modules and shader libraries"


def supervise(command, output, storage_repo, tag, *, tick=30, snapshot_interval=300, upload=publish):
    output.mkdir(parents=True, exist_ok=True)
    log = output / "build-console.log"
    pending = None
    next_snapshot = time.monotonic() + snapshot_interval
    # Only one snapshot upload runs at a time. It does not block process
    # collection and never becomes part of the public Actions artifacts.
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor, log.open("w", encoding="utf-8") as stream:
        child = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
        try:
            while True:
                try:
                    result = child.wait(timeout=tick)
                    break
                except subprocess.TimeoutExpired:
                    print(progress(log), flush=True)
                if pending and pending.done():
                    try:
                        pending.result()
                    except Exception:
                        print("Private progress snapshot unavailable; build continues.", flush=True)
                    pending = None
                if pending is None and time.monotonic() >= next_snapshot:
                    from types import SimpleNamespace
                    request = SimpleNamespace(private_repo=storage_repo, directory=output, tag=tag, logs_only=True)
                    pending = executor.submit(upload, request)
                    next_snapshot = time.monotonic() + snapshot_interval
        except BaseException:
            child.terminate()
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill(); child.wait()
            raise
        finally:
            if pending:
                try:
                    pending.result()
                except Exception:
                    pass
    print(f"Personal build exited with code {result}. Detailed logs remain private.", flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--private-repo", required=True)
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()
    command = [sys.executable, "-u", str(Path(__file__).with_name("build_nxnative_ipa.py")),
               "--mode", "personal", "--base-nsp", str(args.inputs / "base.nsp"),
               "--update-nsp", str(args.inputs / "update.nsp"), "--keys", str(args.inputs / "prod.keys"),
               "--output", str(args.output), "--discard-runner-inputs"]
    return supervise(command, args.output, args.private_repo, args.tag)


if __name__ == "__main__":
    sys.exit(main())
