#!/usr/bin/env python3
"""Build private runtime shader fixtures from existing local translation outputs.

No game data belongs in the public source tree. The ZIP contains the exact-span
index, MSL, translator resource facts, and SPIRV-Cross reflection. It does not
claim that Metal compilation or actual guest rendering has been validated.
Run with smo/env.sh loaded on Windows so spirv-cross can find its runtime DLLs.
"""
from concurrent.futures import ThreadPoolExecutor
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

import shader_index

MSL_FLAGS = ["--msl", "--msl-version", "20300", "--msl-argument-buffers",
             "--msl-texture-buffer-native"]


def metal_arguments(source):
    """Preserve the compiler's emitted argument IDs, never infer them from bindings."""
    result = []
    for declaration, name, array, index in re.findall(
            r"([^;{}\n]+?)\s+(\w+)(\s*\[[^]]+\])?\s*\[\[id\((\d+)\)\]\]", source):
        result.append({"name": name, "id": int(index),
                       "declaration": declaration.strip(), "array": array.strip()})
    return result


def bindings(key, stage, source, metadata):
    """Join compiler-assigned IDs to guest slots through SPIR-V resource names."""
    resources = metadata["resources"]
    reflected = metadata["spirv"]
    names = {}
    for category in ("ubos", "ssbos", "textures", "separate_images", "separate_samplers", "images"):
        for entry in reflected.get(category, []):
            names[entry["name"]] = (category, entry)
    arguments, unsupported = [], []
    for arg in metadata["metal_arguments"]:
        name = arg["name"]
        sampler = arg["declaration"] == "sampler"
        reflected_name = name[:-5] if sampler and name.endswith("Smplr") else name
        match = names.get(reflected_name)
        if not match:
            unsupported.append(arg)
            continue
        category, original = match
        slot = original.get("binding")
        kind = {"ubos": "cbuf", "ssbos": "sbuf", "images": "image"}.get(category, "texture")
        family = {"cbuf": "cbufs", "sbuf": "sbufs", "image": "images", "texture": "textures"}[kind]
        resource = next((r for r in resources.get(family, []) if r["binding"] == slot), None)
        if original["name"] == "support_buffer":
            kind, resource = "support", {"binding": slot, "bytes": original.get("block_size", 0)}
        if resource is None:
            unsupported.append(arg)
            continue
        argument = {**resource, "id": arg["id"], "name": name,
                    "kind": "sampler" if sampler else kind}
        # NVN graphics user UBOs occupy Maxwell c3..c16. The reference
        # maxwell_refs.py uses this ABI; SMO's first system vertex shader reads
        # c3 and its recorded vertex BindUniformBuffer supplies slot 0.
        # c0..c2 are driver/constant banks and must not use this mapping.
        if kind == "cbuf" and 3 <= resource.get("slot", -1) <= 16:
            argument["nvn_slot"] = resource["slot"] - 3
        # c1 = 着色器常数段（参考实现的 NVN_RB_C1）：c1.bin 存在时嵌入真数据；不存在时
        # 运行时读全 0（参考实现 zero_bank，其全库 600 份长 0）。不再要求 constant_data。
        if kind == "cbuf" and resource.get("slot") == 1:
            argument["kind"] = "constant"
        if kind == "sbuf" and resource.get("cb_slot") == 0 and stage in (1, 5):
            base = 0x110 if stage == 1 else 0x510
            offset = resource["cb_offset"] * 4 - base
            if 0 <= offset < 0x100 and offset % 16 == 0:
                argument["nvn_slot"] = offset // 16
        # SMO combined handles occupy c2[0x20 + 8*slot], rather than the
        # reference game's separate-handle table at 0x168. The complete SMO
        # fixture uses only immediate indices 8,10,...,70 (32 texture slots).
        # Keep other handle forms unresolved instead of applying this layout.
        handle = resource.get("handle", -1)
        if (kind == "texture" and resource.get("cbuf_slot") == -1 and
                not resource.get("separate", False) and resource.get("array") == 1 and
                8 <= handle <= 70 and handle % 2 == 0):
            argument["nvn_slot"] = (handle - 8) // 2
        arguments.append(argument)
    inputs = reflected.get("inputs", []) if stage == 1 else []
    # Preserve actual compiler attributes rather than assuming dense locations.
    attribute_locations = {int(i) for i in re.findall(r"\[\[attribute\((\d+)\)\]\]", source)}
    inputs = [i for i in inputs if i.get("location") in attribute_locations]
    result = {"version": 1, "key": key, "stage": stage, "entry": "main0",
            "argument_buffer": 0, "arguments": arguments, "vertex_inputs": inputs,
            "unsupported_arguments": unsupported}
    if "constant_data" in resources:
        result["constant_data"] = resources["constant_data"]
    if "depth_clip_source" in metadata:
        result["depth_clip_source"] = metadata["depth_clip_source"]
    return result


def write_shader(z, row, key, source, metadata):
    z.writestr(row[2], source)
    z.writestr(key + ".reflection.json", json.dumps(metadata, sort_keys=True))
    z.writestr(key + ".bindings.json", json.dumps(bindings(key, row[1], source, metadata), sort_keys=True))


def repack(archive, output, index=None, spans=None):
    """Upgrade an already converted private fixture without rerunning compilers."""
    temporary = output.with_suffix(output.suffix + ".partial")
    with zipfile.ZipFile(archive) as old, zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as z:
        manifest = json.loads(old.read("manifest.json"))
        names = set(old.namelist())
        z.writestr("shaders.idx", index.read_bytes() if index else old.read("shaders.idx"))
        for shader in manifest["shaders"]:
            key = shader["key"]
            flat = key + ".metal" in names
            source = old.read(key + ".metal" if flat else "msl/" + key + ".metal").decode()
            metadata = json.loads(old.read(key + ".reflection.json" if flat else "reflection/" + key + ".json"))
            if spans:
                span = json.loads((spans / (key + ".span.json")).read_text())
                size = span["span_bytes"]
                resource = metadata["resources"]
                if (span["key"] != key or span["archive_bytes"] != shader["span"] or
                        not 0x58 <= size <= span["archive_bytes"] or
                        resource.get("span_bytes", size) != size):
                    raise ValueError("inconsistent decoded shader span: " + key)
                resource["span_bytes"] = size
            write_shader(z, (None, shader["stage"], key + ".metal"), key, source, metadata)
            if "depth_clip_sha256" in shader:
                name = key + ".clip.metal"
                data = old.read(name)
                if hashlib.sha256(data).hexdigest() != shader["depth_clip_sha256"]:
                    raise ValueError("depth variant digest mismatch: " + key)
                z.writestr(name, data)
        z.writestr("manifest.json", json.dumps(manifest, sort_keys=True))
    temporary.replace(output)
    print(f"repacked={len(manifest['shaders'])} zip_bytes={output.stat().st_size} "
          f"sha256={hashlib.sha256(output.read_bytes()).hexdigest()}")


def translate(row, unpack, cross, reuse=None):
    key = Path(row[2]).stem
    spv = unpack / "msl" / (key + ".spv")
    facts = unpack / "msl" / (key + ".res.json")
    resource = json.loads(facts.read_text(encoding="utf-8"))
    constant = unpack / key / "c1.bin"
    if constant.is_file():
        data = constant.read_bytes()
        if len(data) > 65536:
            raise ValueError("shader constants exceed NVN bank size: " + key)
        resource["constant_data"] = data.hex()
    if resource["key"] != key:
        raise ValueError("resource reflection key mismatch: " + key)
    digest = hashlib.sha256(spv.read_bytes()).hexdigest()
    if reuse and key in reuse[1]:
        old, manifest, baselines = reuse
        metadata = json.loads(old.read(key + ".reflection.json"))
        previous = metadata.get("spirv_sha256")
        if previous is None:
            baseline = next((root / "msl" / (key + ".spv") for root in baselines
                             if (root / "msl" / (key + ".spv")).is_file()), None)
            if baseline:
                previous = hashlib.sha256(baseline.read_bytes()).hexdigest()
        if previous == digest:
            source = old.read(key + ".metal").decode()
            if hashlib.sha256(source.encode()).hexdigest() != manifest[key]["msl_sha256"]:
                raise ValueError("cached Metal source digest mismatch: " + key)
            metadata["resources"] = resource
            metadata["spirv_sha256"] = digest
            # This build returns the base source only. Add verified variants
            # afterward with shader_depth_variants.py.
            metadata.pop("depth_clip_source", None)
            return row, key, source, metadata
    source = subprocess.check_output([cross, str(spv), *MSL_FLAGS]).decode("utf-8")
    source = source.replace("\r\n", "\n")
    reflection = json.loads(subprocess.check_output([cross, str(spv), "--reflect"]))
    metadata = {"resources": resource, "spirv": reflection,
                "metal_arguments": metal_arguments(source), "spirv_sha256": digest}
    return row, key, source, metadata


def merge(archives, output):
    """Combine independently converted resource families without hiding conflicts."""
    temporary = output.with_suffix(output.suffix + ".partial")
    shaders, unsupported, rows, assets = {}, {}, set(), {}
    flags = None
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as target:
            for path in archives:
                with zipfile.ZipFile(path) as archive:
                    manifest = json.loads(archive.read("manifest.json"))
                    if flags is not None and flags != manifest["msl_flags"]:
                        raise ValueError("shader compiler options differ")
                    flags = manifest["msl_flags"]
                    rows.update(line for line in archive.read("shaders.idx").decode().splitlines()
                                if line and not line.startswith("#"))
                    for item in manifest.get("unsupported", []):
                        unsupported[item["key"]] = item
                    for item in manifest["shaders"]:
                        key = item["key"]
                        suffixes = [".metal", ".bindings.json", ".reflection.json"]
                        if "depth_clip_sha256" in item:
                            suffixes.append(".clip.metal")
                        for suffix in suffixes:
                            name = key + suffix
                            data = archive.read(name)
                            digest = hashlib.sha256(data).digest()
                            if name in assets:
                                if assets[name] != digest:
                                    raise ValueError("conflicting shader asset: " + name)
                            else:
                                target.writestr(name, data)
                                assets[name] = digest
                        if key in shaders and shaders[key] != item:
                            raise ValueError("conflicting shader manifest: " + key)
                        shaders[key] = item
            target.writestr("shaders.idx", "# merged exact shader spans\n" + "\n".join(sorted(rows)) + "\n")
            target.writestr("manifest.json", json.dumps({"version": 1, "msl_flags": flags,
                "shaders": list(shaders.values()), "unsupported": list(unsupported.values())}, sort_keys=True))
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"merged={len(shaders)} index_rows={len(rows)} zip_bytes={output.stat().st_size} "
          f"sha256={hashlib.sha256(output.read_bytes()).hexdigest()}")


def build(unpack, output, cross, keys=None, jobs=8, reuse_path=None, baselines=(), index=None):
    rows = shader_index.build(str(unpack))
    selected = [r for r in rows if keys is None or Path(r[2]).stem in keys]
    if not selected or keys and len(selected) != len(keys):
        raise ValueError("requested shader key is absent from exact-span index")
    unsupported = [{"key": Path(r[2]).stem, "stage": r[1],
                    "reason": "Metal geometry shaders require separate emulation"}
                   for r in selected if r[1] == 4]
    selected = [r for r in selected if r[1] != 4]
    manifest = {"version": 1, "msl_flags": MSL_FLAGS, "shaders": [], "unsupported": unsupported}
    output.parent.mkdir(parents=True, exist_ok=True)
    # Build atomically: a failed conversion must not leave a usable-looking ZIP.
    temporary = output.with_suffix(output.suffix + ".partial")
    old = None
    try:
        reuse = None
        if reuse_path:
            old = zipfile.ZipFile(reuse_path)
            previous = json.loads(old.read("manifest.json"))
            if previous["msl_flags"] != MSL_FLAGS:
                raise ValueError("cached Metal compiler options differ")
            reuse = old, {s["key"]: s for s in previous["shaders"]}, baselines
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
            z.writestr("shaders.idx", index.read_bytes() if index else shader_index.render(rows))
            with ThreadPoolExecutor(max_workers=jobs) as workers:
                converted = workers.map(lambda row: translate(row, unpack, cross, reuse), selected)
                for count, (row, key, source, metadata) in enumerate(converted, 1):
                    write_shader(z, row, key, source, metadata)
                    manifest["shaders"].append({"key": key, "span": row[3], "stage": row[1],
                                                "msl_sha256": hashlib.sha256(source.encode()).hexdigest()})
                    if count % 1000 == 0:
                        print(f"converted={count}/{len(selected)}", flush=True)
            z.writestr("manifest.json", json.dumps(manifest, sort_keys=True))
        temporary.replace(output)
    finally:
        if old:
            old.close()
        temporary.unlink(missing_ok=True)
    print(f"shaders={len(selected)} unsupported={len(unsupported)} zip_bytes={output.stat().st_size} "
          f"sha256={hashlib.sha256(output.read_bytes()).hexdigest()}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unpack", type=Path, default=Path("work/shaders_all"))
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--repack", type=Path, help="upgrade a legacy converted fixture, no translation")
    parser.add_argument("--merge", nargs="+", type=Path, help="merge flat fixtures, reject conflicting assets")
    parser.add_argument("--index", type=Path, help="replace the exact-span index while repacking")
    parser.add_argument("--spans", type=Path, help="validate and preserve decoded span metadata while repacking")
    parser.add_argument("--reuse", type=Path, help="reuse Metal only for identical SPIR-V and compiler options")
    parser.add_argument("--baseline-unpack", nargs="+", type=Path, default=[],
                        help="trusted original SPIR-V directories for legacy fixtures without SPIR-V hashes")
    parser.add_argument("--spirv-cross", default="spirv-cross")
    parser.add_argument("--jobs", type=int, default=8)
    parser.add_argument("--keys", nargs="+", help="optional SHA256-prefix shader keys; default all")
    args = parser.parse_args()
    if args.merge:
        merge(args.merge, args.out)
        return
    if args.repack:
        repack(args.repack, args.out, args.index, args.spans)
        return
    build(args.unpack, args.out, args.spirv_cross, set(args.keys) if args.keys else None, args.jobs,
          args.reuse, args.baseline_unpack, args.index)


if __name__ == "__main__":
    main()
