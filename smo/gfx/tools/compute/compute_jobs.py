"""Compute shader jobs for one ShaderData archive (default alComputeShader): candidate starts = 0x100-aligned nonzero offsets in the code
section; each job gets the code from its start to the end of the section so the
translator decodes the real control flow (ctx.Size) instead of stopping at the first EXIT."""
import sys, struct, json, hashlib, pathlib
romfs = pathlib.Path(sys.argv[1]); repo = pathlib.Path(sys.argv[2]); out = pathlib.Path(sys.argv[3])
name = sys.argv[4] if len(sys.argv) > 4 else "alComputeShader"
sys.path.insert(0, str(repo / "smo" / "tools"))
import nintendo_archives as na
out.mkdir(parents=True, exist_ok=True)
d = na.yaz0_decompress((romfs / "ShaderData" / (name + ".szs")).read_bytes())
for member, off, size in na.Sarc(d).entries:
    if member.endswith(".sharcb"):
        b = d[off:off + size]
base = struct.unpack_from("<I", b, 0x1c)[0]
jobs = []
for o in range(base, len(b), 0x100):
    if not any(b[o:o + 16]):
        continue
    tail = b[o:]
    key = "%s_%05x" % (name[:8], o - base)
    p = out / (key + ".bin")
    p.write_bytes(tail)
    jobs.append({"key": key, "stage": "cs", "code": str(p), "debug": False,
                 "tex": {}, "img": {}, "attr": {}, "fout": {}, "local": [1, 1, 1]})
json.dump(jobs, open(out / "jobs.json", "w"))
print(len(jobs), "candidate starts")
