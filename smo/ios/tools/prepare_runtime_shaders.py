"""Copy verified private shader runtime files into an embedded iOS app.

Runtime stages: 1 = vertex (plus its GL depth variant), 5 = fragment, 0 = compute
(smo/gfx/tools/compute/compute_fixture.py). Extra fixtures (e.g. compute) are merged
into the base one; a member present in two fixtures must be byte-identical."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile
import zlib

RUNTIME_STAGES = (0, 1, 5)


def read_fixture(source, files, shaders):
    """Validate one fixture and add its runtime members. Returns (index text, depth variants)."""
    manifest = json.loads(source.read("manifest.json"))
    if manifest.get("version") != 1 or not manifest.get("shaders"):
        raise ValueError("incomplete shader fixture")
    index = source.read("shaders.idx")
    if not index.strip():
        raise ValueError("empty shader index")

    def add(name, data):
        if name in files and files[name] != data:
            raise ValueError("conflicting shader asset across fixtures: " + name)
        files[name] = data

    variants = 0
    for row in manifest["shaders"]:
        key, stage = row["key"], row["stage"]
        if not re.fullmatch(r"[0-9a-f]{16}", key) or stage not in RUNTIME_STAGES:
            raise ValueError("invalid shader identity")
        name = key + ".metal"
        data = source.read(name)
        if hashlib.sha256(data).hexdigest() != row["msl_sha256"]:
            raise ValueError("shader source digest mismatch")
        add(name, data)
        name = key + ".bindings.json"
        data = source.read(name)
        bindings = json.loads(data)
        if bindings.get("key") != key or bindings.get("stage") != stage or bindings.get("version") != 1:
            raise ValueError("shader binding identity mismatch")
        if stage == 0 and not (isinstance(bindings.get("threadgroup_size"), list) and len(bindings["threadgroup_size"]) == 3):
            raise ValueError("compute shader without thread-group size")
        add(name, data)
        if stage == 1:
            name = key + ".clip.metal"
            if bindings.get("depth_clip_source") != name:
                raise ValueError("required depth variant not bound")
            data = source.read(name)
            if hashlib.sha256(data).hexdigest() != row.get("depth_clip_sha256"):
                raise ValueError("depth variant digest mismatch")
            add(name, data)
            variants += 1
        shaders.append(row)
    return index.decode("utf8"), variants


def prepare(archive, destination, extra=()):
    files, shaders, indexes, variants = {}, [], [], 0
    for path in (archive, *extra):
        with zipfile.ZipFile(path) as source:
            text, count = read_fixture(source, files, shaders)
            indexes.append(text)
            variants += count
    canonical = canonical_assets(shaders, files)
    lines = []
    for line in "\n".join(indexes).splitlines():
        if not line or line.startswith("#"):
            lines.append(line)
            continue
        fields = line.split("\t")
        if len(fields) < 3:
            raise ValueError("invalid shader index row")
        # Preserve unimplemented stages in the exact original index. They
        # remain explicit runtime failures if requested, as in native CI.
        if int(fields[1]) not in RUNTIME_STAGES:
            lines.append(line)
            continue
        if fields[2] not in files or not fields[2].endswith(".metal"):
            raise ValueError("shader index references unavailable source")
        fields[2] = canonical.get(fields[2], fields[2])
        lines.append("\t".join(fields))
    files["shaders.idx"] = ("\n".join(lines) + "\n").encode("utf8")
    files["manifest.json"] = json.dumps({"version": 1, "shaders": shaders}, sort_keys=True).encode()
    # Validate every input before writing the app. Only flat runtime paths
    # selected above are copied; reflection and unrelated archive files stay out.
    for name, data in files.items():
        if len(name.encode("ascii")) >= 64 or len(data) > 16 * 1024 * 1024:
            raise ValueError("runtime archive member exceeds reader bounds")
    destination.mkdir(parents=True, exist_ok=False)
    (destination / "shaders.idx").write_bytes(files["shaders.idx"])
    # One signed resource replaces tens of thousands of small bundle files.
    # Runtime reads only requested members, without extracting a second copy.
    with (destination / "shaders.smoa").open("wb") as target:
        target.write(b"SMOA\0\1")
        total = 0
        for name, data in sorted(files.items()):
            encoded = name.encode("ascii")
            target.write(struct.pack("<HII", len(encoded), len(data), zlib.crc32(data)))
            target.write(encoded)
            target.write(data)
            total += len(data)
        target.write(b"END!" + struct.pack("<Q", total))
    renamed = sum(1 for name, target in canonical.items() if name != target)
    compute = sum(1 for row in shaders if row["stage"] == 0)
    print(f"IOS_RUNTIME_SHADERS shaders={len(shaders)} compute={compute} depth_variants={variants} "
          f"identical_assets_merged={renamed}")


def canonical_assets(shaders, files):
    """Map each .metal name to one representative of its byte-identical asset group.

    The offline translator emitted some machine-code blobs several times under
    different keys (37 of 21116 in the device fixture). The runtime index rejects a
    binary key that names two different assets, so those draws never matched
    (真机：NVN_SHADER_EXEC_MATCH_FAILED candidates=5 matches=3 ×852). Assets are only
    merged when MSL, depth variant and bindings (other than their own key) are
    identical, so the selected shader is the same program either way."""
    groups = collections.defaultdict(list)
    for row in shaders:
        key = row["key"]
        bindings = json.loads(files[key + ".bindings.json"])
        bindings.pop("key", None)
        clip_name = bindings.pop("depth_clip_source", None)
        clip = hashlib.sha256(files[clip_name]).hexdigest() if clip_name else None
        identity = (row["stage"], hashlib.sha256(files[key + ".metal"]).hexdigest(), clip,
                    json.dumps(bindings, sort_keys=True))
        groups[identity].append(key + ".metal")
    return {name: min(names) for names in groups.values() for name in names}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--extra", type=Path, nargs="*", default=[],
                        help="additional fixtures to merge (e.g. compute shaders)")
    args = parser.parse_args()
    prepare(args.archive, args.destination, args.extra)
