#!/usr/bin/env python3
"""Fail the packaging gate when the captured game output is absent or black."""
import argparse
import json
from pathlib import Path


def read_ppm(path: Path):
    data = path.read_bytes()
    if not data.startswith(b"P6"):
        raise ValueError("capture is not binary PPM (P6)")
    pos = 2
    tokens = []
    while len(tokens) < 3:
        while pos < len(data) and data[pos] in b" \t\r\n":
            pos += 1
        if pos < len(data) and data[pos] == ord("#"):
            end = data.find(b"\n", pos)
            pos = len(data) if end < 0 else end + 1
            continue
        end = pos
        while end < len(data) and data[end] not in b" \t\r\n":
            end += 1
        if end == pos:
            raise ValueError("truncated PPM header")
        tokens.append(int(data[pos:end]))
        pos = end
    width, height, maximum = tokens
    if not 1 <= width <= 4096 or not 1 <= height <= 4096 or maximum != 255:
        raise ValueError(f"invalid PPM dimensions/maxval: {width}x{height}/{maximum}")
    while pos < len(data) and data[pos] in b" \t\r\n":
        pos += 1
    pixels = data[pos:]
    expected = width * height * 3
    if len(pixels) != expected:
        raise ValueError(f"PPM payload size {len(pixels)} != {expected}")
    return width, height, pixels


def measure(path: Path):
    width, height, pixels = read_ppm(path)
    nonblack = 0
    minimum = 255
    maximum = 0
    for offset in range(0, len(pixels), 3):
        r, g, b = pixels[offset:offset + 3]
        value = max(r, g, b)
        minimum = min(minimum, value)
        maximum = max(maximum, value)
        if value >= 8:
            nonblack += 1
    count = width * height
    return {"path": path.name, "width": width, "height": height,
            "nonblack_ratio": nonblack / count, "range": [minimum, maximum]}


def acceptable(m):
    return m["nonblack_ratio"] >= 0.01 and m["range"][1] - m["range"][0] >= 16


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("result", type=Path)
    args = parser.parse_args()
    result = json.loads(args.result.read_text(encoding="utf-8"))
    if not result.get("passed"):
        raise SystemExit("boot result did not pass")
    if result.get("test_press_a_count", 0) >= 2 and not result.get("gpu_frames_after_input"):
        raise SystemExit("no GPU frames after the automated A confirmation presses")
    # The latest capture lands at an arbitrary moment (a slow runner may stop on a fade or
    # loading frame), so also look at the recent periodic captures (one per 60 frames).
    # Passing needs real game output in at least one of them; all-black still fails.
    paths = [args.capture] + sorted(args.capture.parent.glob("frame-recent-*.ppm"))
    measured = [measure(p) for p in paths if p.exists()]
    if not measured:
        raise SystemExit("no captured game output")
    for m in measured:
        print(json.dumps(m, ensure_ascii=False))
    good = [m for m in measured if acceptable(m)]
    if not good:
        best = max(measured, key=lambda m: m["nonblack_ratio"])
        if best["nonblack_ratio"] < 0.01:
            raise SystemExit(f"captured game output is nearly black: nonblack={best['nonblack_ratio']:.3%} "
                             f"(best of {len(measured)} captures)")
        raise SystemExit(f"captured game output has insufficient range: {best['range'][0]}..{best['range'][1]}")
    best = max(good, key=lambda m: m["nonblack_ratio"])
    print(json.dumps({"passed": True, "captures": len(measured), "acceptable": len(good), **best},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
