#!/usr/bin/env python3
"""Offline compute-shader extraction for the SMO ShaderData archives.

Compute programs live in .sharcb archives next to graphics shaders, but have no
0x12345678 slot marker and no 0x50-byte SPH, so smo/tools/sharcb.py never sees
them. In the shipped RomFS only alComputeShader.sharcb contains compute programs.

Layout (verified on alComputeShader.sharcb):

- header dword 0x1c is the code-section base
- a program record starts with dwords N, 3, 0, N-0x10, code_offset, 0, 0x7d1, 0x60;
  code_offset is relative to the code base. Records of size >= 0x7c4 are compute
  programs and carry the GLSL `local_size` at record+0x7b8 (16,8,8 / 1536,1,1 /
  32,1,1, matching the archive's own GLSL source); shorter records are variations
  that reuse the same code offsets
- a compute program may EXIT before its real end, so the exact span comes from the
  translator itself (`dmsh_xlate --spans`, ctx.Size), starting at the record offset

  compute_jobs.py jobs   <romfs> <out>          # one job per program record
  compute_jobs.py select <out> <spans-dir>      # exact spans → <out>/jobs.json
"""
import hashlib
import json
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "smo" / "tools"))
import nintendo_archives as na  # noqa: E402

MAX_THREADS = 1536  # Maxwell compute limit; also the largest size the game declares


def sharcb_members(romfs):
    for path in sorted((romfs / "ShaderData").glob("*.szs")):
        data = na.yaz0_decompress(path.read_bytes())
        for member, offset, size in na.Sarc(data).entries:
            if member.endswith(".sharcb"):
                yield path.stem, data[offset:offset + size]


def records(blob):
    """Compute program records: code offset (code-relative) → set of thread-group sizes.

    Full records (>= 0x7c4 bytes) carry the size at +0x7b8. Short variation records
    instead hold a signed offset at +0x1c back into the full record they share
    (record + int32(+0x1c) lands inside it), and inherit that size."""
    u = lambda o: struct.unpack_from("<I", blob, o)[0]
    base = u(0x1c)
    full, short = [], []
    for o in range(0, base - 0x20, 4):
        n = u(o)
        if not (n and u(o + 4) == 3 and u(o + 8) == 0 and u(o + 12) == n - 0x10 and
                u(o + 20) == 0 and u(o + 24) == 0x7d1):
            continue
        if n >= 0x7c4 and o + 0x7c4 <= base:
            size = tuple(u(o + 0x7b8 + 4 * i) for i in range(3))
            if not (all(1 <= v <= MAX_THREADS for v in size) and size[0] * size[1] * size[2] <= MAX_THREADS):
                size = None
            full.append((o, n, u(o + 16), size))
        else:
            short.append((o, u(o + 16), struct.unpack_from("<i", blob, o + 0x1c)[0]))
    found = {}
    for o, n, code, size in full:
        found.setdefault(code, set()).add(size)
    for o, code, back in short:
        target = o + back
        owner = next((f for f in full if f[0] <= target < f[0] + f[1]), None)
        found.setdefault(code, set()).add(owner[3] if owner else None)
    return base, found


def jobs(romfs, out):
    out.mkdir(parents=True, exist_ok=True)
    result = []
    for archive, blob in sharcb_members(romfs):
        base, recs = records(blob)
        for offset, sizes in sorted(recs.items()):
            if len(sizes) != 1:
                raise ValueError(f"{archive}@{offset:#x}: thread-group size {sorted(sizes)} is not unique")
            start = base + offset
            # Bound the input: the translator stops at the decoded end; the next
            # record (or the section end) is a safe upper limit.
            later = [base + o for o in recs if o > offset]
            tail = blob[start:min(later) if later else len(blob)]
            name = f"{archive}@{offset:x}"
            path = out / "code" / (hashlib.sha256(name.encode()).hexdigest()[:16] + ".bin")
            path.parent.mkdir(exist_ok=True)
            path.write_bytes(tail)
            result.append({"key": path.stem, "stage": "cs", "code": str(path), "debug": False,
                           "tex": {}, "img": {}, "attr": {}, "fout": {}, "local": list(sizes.pop()),
                           "origin": name})
    (out / "candidates.json").write_text(json.dumps(result, indent=1))
    print(f"compute_programs={len(result)} archives={len({j['origin'].split('@')[0] for j in result})}")


def select(out, spans):
    """Cut each program to its decoded span and key it by content (sha256 prefix)."""
    candidates = json.loads((out / "candidates.json").read_text())
    selected = {}
    for job in candidates:
        span = json.loads((spans / (job["key"] + ".span.json")).read_text())
        size = span["span_bytes"]
        code = pathlib.Path(job["code"]).read_bytes()[:size]
        if len(code) != size:
            raise ValueError("decoded span exceeds bounded input: " + job["origin"])
        key = hashlib.sha256(code).hexdigest()[:16]
        exact = out / "exact" / (key + ".bin")
        exact.parent.mkdir(exist_ok=True)
        exact.write_bytes(code)
        previous = selected.get(key)
        if previous and previous["local"] != job["local"]:
            raise ValueError(f"identical compute code with different thread-group sizes: {key}")
        selected[key] = {**job, "key": key, "code": str(exact), "span_bytes": size}
    (out / "jobs.json").write_text(json.dumps(list(selected.values()), indent=1))
    print(f"programs={len(candidates)} unique={len(selected)}")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "jobs":
        jobs(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))
    elif command == "select":
        select(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))
    else:
        raise SystemExit(__doc__)
