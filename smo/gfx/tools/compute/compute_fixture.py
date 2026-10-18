#!/usr/bin/env python3
"""Package translated compute shaders as a private runtime fixture (same format as
smo/gfx/shader_fixture.py) so they can be merged into the device shader bundle.

Inputs: compute_jobs.py output (jobs.json with exact spans + thread-group sizes) and
the dmsh_xlate output directory (<key>.spv, <key>.res.json).

Compute ABI (Maxwell / NVN, as in the reference project's dmsh_build.py):
- uniform buffer r is constant bank c[3 + r]  → kind cbuf, nvn_slot r
- storage buffer r's address lives at c0[0x310 + 16 r] → kind sbuf, nvn_slot r
- c0 is the driver bank; compute shaders read the storage table (0x310..0x410) and
  0x200..0x20c, which the runtime fills from the dispatch (see "driver" below)
- c1 is the compiler constant bank: control +0x700/+0x704 delimit it inside the code
  allocation; all compute programs here have an empty or all-zero c1
- images: handle index slot = (handle - 8) / 2 in c2 (same packing as textures)

Every argument either maps to a verified slot or the shader is rejected; nothing is
guessed. Lane IDs: spirv-cross maps SubgroupLocalInvocationId to
thread_index_in_simdgroup, which is only the Maxwell lane when the Metal SIMD width
is 32 (true on Apple GPUs); the runtime asserts threadExecutionWidth == 32.

  compute_fixture.py --jobs <jobs.json> --translated <dir> --romfs <RomFS> --out <zip>
"""
import argparse
import hashlib
import json
import pathlib
import re
import struct
import subprocess
import sys
import zipfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent))  # smo/gfx
import shader_index  # noqa: E402
from shader_fixture import MSL_FLAGS, metal_arguments  # noqa: E402

COMPUTE_STAGE = 0
STORAGE_BASE = 0x310          # c0 storage-buffer address table for the compute stage
STORAGE_SLOTS = 16
DRIVER_RANGES = ((0x200, 0x210), (STORAGE_BASE, STORAGE_BASE + 16 * STORAGE_SLOTS))


def driver_reads(source):
    """Byte offsets of every constant-index read of the c0 driver bank."""
    offsets, dynamic = set(), False
    for m in re.finditer(r"cp_c0\)\._m0\[([^\]]+)\]", source):
        index = m.group(1).rstrip("u")
        if index.isdigit():
            offsets.add(int(index) * 16)
        else:
            dynamic = True
    return sorted(offsets), dynamic


def bindings(key, source, resources, local):
    reflected_args = metal_arguments(source)
    sbufs = {b["binding"]: b for b in resources["sbufs"]}
    cbufs = {b["binding"]: b for b in resources["cbufs"]}
    images = {b["binding"]: b for b in resources["images"]}
    reflection = {}
    arguments, unsupported = [], []
    for arg in reflected_args:
        name = arg["name"]
        entry = {"id": arg["id"], "name": name}
        m = re.fullmatch(r"cp_c(\d+)", name)
        s = re.fullmatch(r"cp_s(\d+)", name)
        if name == "support_buffer":
            entry["kind"] = "support"
        elif m and int(m.group(1)) >= 3:
            entry.update(kind="cbuf", nvn_slot=int(m.group(1)) - 3)
        elif m and int(m.group(1)) == 1:
            entry["kind"] = "constant"
        elif m and int(m.group(1)) == 0:
            entry["kind"] = "driver"
        elif s:
            ordered = sorted(sbufs.values(), key=lambda b: b["binding"])
            index = int(s.group(1))
            buffer = ordered[index] if index < len(ordered) else None
            offset = buffer["cb_offset"] * 4 if buffer and buffer["cb_slot"] == 0 else None
            if offset is None or not STORAGE_BASE <= offset < STORAGE_BASE + 16 * STORAGE_SLOTS or (offset - STORAGE_BASE) % 16:
                unsupported.append(arg)
                continue
            entry.update(kind="sbuf", nvn_slot=(offset - STORAGE_BASE) // 16, write=bool(buffer["flags"] & 1))
        elif name.startswith("cp_i_"):
            image = next(iter(images.values()), None) if len(images) == 1 else None
            handle = image["handle"] if image else -1
            if not (image and image["cbuf_slot"] == -1 and 8 <= handle <= 70 and handle % 2 == 0):
                unsupported.append(arg)
                continue
            entry.update(kind="image", nvn_slot=(handle - 8) // 2)
        else:
            unsupported.append(arg)
            continue
        arguments.append(entry)
    reads, dynamic = driver_reads(source)
    outside = [o for o in reads if not any(a <= o < b for a, b in DRIVER_RANGES)]
    if dynamic or outside:
        unsupported.append({"name": "cp_c0", "reads": [hex(o) for o in outside], "dynamic": dynamic})
    return {"version": 1, "key": key, "stage": COMPUTE_STAGE, "entry": "main0",
            "argument_buffer": 0, "arguments": arguments, "vertex_inputs": [],
            "threadgroup_size": local, "driver_reads": reads,
            "unsupported_arguments": unsupported}, reflection


def constant_bank(romfs, origin):
    """c1 bytes from the program's NVN control record (+0x700/+0x704 relative to code)."""
    archive, offset = origin.split("@")
    sys.path.insert(0, str(HERE.parents[3] / "smo" / "tools"))
    import nintendo_archives as na
    data = na.yaz0_decompress((romfs / "ShaderData" / (archive + ".szs")).read_bytes())
    blob = next(data[o:o + s] for m, o, s in na.Sarc(data).entries if m.endswith(".sharcb"))
    u = lambda o: struct.unpack_from("<I", blob, o)[0]
    base, code = u(0x1c), int(offset, 16)
    for o in range(0, base - 0x20, 4):
        n = u(o)
        if (n >= 0x7c4 and u(o + 4) == 3 and u(o + 8) == 0 and u(o + 12) == n - 0x10 and
                u(o + 16) == code and u(o + 20) == 0 and u(o + 24) == 0x7d1 and u(o + 0x70) == 0x98761234):
            begin, end = u(o + 0x70 + 0x700), u(o + 0x70 + 0x704)
            if not begin <= end or end - begin > 65536:
                raise ValueError("invalid compute c1 range: " + origin)
            return blob[base + code + begin:base + code + end]
    return b""


def build(jobs_path, translated, romfs, output, cross):
    jobs = json.loads(pathlib.Path(jobs_path).read_text())
    manifest = {"version": 1, "msl_flags": MSL_FLAGS, "shaders": [], "unsupported": []}
    rows = []
    temporary = output.with_suffix(output.suffix + ".partial")
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as z:
        for job in jobs:
            key = job["key"]
            spv = translated / (key + ".spv")
            resources = json.loads((translated / (key + ".res.json")).read_text())
            if resources["key"] != key or resources["span_bytes"] != job["span_bytes"]:
                raise ValueError("translator output does not match job: " + key)
            code = pathlib.Path(job["code"]).read_bytes()
            if len(code) != job["span_bytes"] or hashlib.sha256(code).hexdigest()[:16] != key:
                raise ValueError("compute code changed since extraction: " + key)
            source = subprocess.check_output([cross, str(spv), *MSL_FLAGS]).decode().replace("\r\n", "\n")
            if "kernel void main0" not in source:
                raise ValueError("translated shader is not a compute kernel: " + key)
            meta, _ = bindings(key, source, resources, job["local"])
            constant = constant_bank(romfs, job["origin"])
            if any(a["kind"] == "constant" for a in meta["arguments"]):
                meta["constant_data"] = constant.hex()
            if meta["unsupported_arguments"]:
                manifest["unsupported"].append({"key": key, "stage": COMPUTE_STAGE,
                                                "reason": "unmapped compute resources"})
                continue
            z.writestr(key + ".metal", source)
            z.writestr(key + ".bindings.json", json.dumps(meta, sort_keys=True))
            z.writestr(key + ".reflection.json", json.dumps({"resources": resources, "origin": job["origin"],
                       "spirv_sha256": hashlib.sha256(spv.read_bytes()).hexdigest()}, sort_keys=True))
            manifest["shaders"].append({"key": key, "span": len(code), "stage": COMPUTE_STAGE,
                                        "msl_sha256": hashlib.sha256(source.encode()).hexdigest()})
            # Compute code has no SPH: the code-only columns equal the full span.
            full, prefix = shader_index.fnv64(code), shader_index.fnv64(code[:64])
            rows.append(f"{full:016x}\t{COMPUTE_STAGE}\t{key}.metal\t{len(code)}\t{prefix:016x}\t{full:016x}\t{prefix:016x}")
        z.writestr("shaders.idx", "# compute shaders: exact spans, no SPH (code-only = full)\n" + "\n".join(sorted(rows)) + "\n")
        z.writestr("manifest.json", json.dumps(manifest, sort_keys=True))
    temporary.replace(output)
    print(f"compute_shaders={len(manifest['shaders'])} unsupported={len(manifest['unsupported'])} "
          f"sha256={hashlib.sha256(output.read_bytes()).hexdigest()}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--jobs", required=True)
    parser.add_argument("--translated", required=True, type=pathlib.Path)
    parser.add_argument("--romfs", required=True, type=pathlib.Path)
    parser.add_argument("--out", required=True, type=pathlib.Path)
    parser.add_argument("--spirv-cross", default="spirv-cross")
    args = parser.parse_args()
    build(args.jobs, args.translated, args.romfs, args.out, args.spirv_cross)


if __name__ == "__main__":
    main()
