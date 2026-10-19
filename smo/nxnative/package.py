"""Portable resource manifests, bounded ZIP parts and verified restoration."""
from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import zipfile

PART_BYTES = 1024 ** 3
BLOCK = 1024 ** 2
LOCK = json.loads(Path(__file__).with_name("lock.json").read_text(encoding="utf-8"))


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        while data := stream.read(BLOCK):
            digest.update(data)
    return digest.hexdigest()


def safe_name(name):
    if not isinstance(name, str) or not name or "\\" in name or ":" in name:
        raise ValueError("Invalid relative file name")
    p = PurePosixPath(name)
    if p.is_absolute() or ".." in p.parts or str(p) != name:
        raise ValueError("Unsafe relative file name: " + name)
    return name


def identity(profile):
    rows = [line.split("\t") for line in (profile / "game.tsv").read_text(encoding="utf-8").splitlines()
            if line and not line.startswith("#")]
    version = next(r for r in rows if r[0] == "build" and r[1] == LOCK["package"])
    import re
    chain = re.search(r'#define DMSH_CHAIN "([a-f0-9]+)"',
                      (profile / "dmsh_chain.h").read_text(encoding="utf-8")).group(1)
    return {"format": 1, "title_id": LOCK["title_id"], "game_version": LOCK["game_version"],
            "nxnative_commit": LOCK["commit"], "shader_chain": chain,
            "build_ids": dict(item.split("=", 1) for item in version[3:])}


def validate_build(exefs, expected):
    for module, want in expected["build_ids"].items():
        path = exefs / module
        with path.open("rb") as f:
            header = f.read(0x60)
        if len(header) != 0x60 or header[:4] != b"NSO0" or header[0x40:0x50].hex() != want:
            raise ValueError(f"{module}: NSO Build ID does not match {LOCK['game_version']}")


def validate_shader_libraries(msl, profile, chain):
    """Only Odyssey's upstream geometry shaders may be absent from a release."""
    expected, geometry = set(), set()
    for line in (profile / "shader_map.tsv").read_text(encoding="utf-8").splitlines():
        columns = line.split("\t")
        if len(columns) < 5 or not (columns[0].endswith(".bin") or columns[0].startswith("main.rodata@")):
            continue
        expected.add(columns[3])
        if columns[0].startswith("gs_"):
            geometry.add(columns[3])
    if not expected:
        raise ValueError("The profile has no shader records")
    directory = Path(msl) / ("b-" + chain)
    missing = set()
    for key in expected:
        library, reflection = directory / (key + "_b.metallib"), directory / (key + "_b.json")
        if not library.is_file() or not reflection.is_file():
            missing.add(key)
            continue
        with library.open("rb") as stream:
            if stream.read(4) != b"MTLB":
                raise ValueError("Invalid Metal library: " + key)
        record = json.loads(reflection.read_text(encoding="utf-8"))
        if record.get("chain") != chain:
            raise ValueError("Metal reflection chain mismatch: " + key)
    unexpected = missing - geometry
    if unexpected:
        raise ValueError(f"Missing {len(unexpected)} required shader libraries/reflections: {', '.join(sorted(unexpected)[:8])}")
    return {"total": len(expected), "ready": len(expected - missing), "failed": len(missing),
            "known_missing_geometry": sorted(missing), "unexpected_missing": []}


class PartWriter(io.RawIOBase):
    """A non-seekable ZIP sink; never keeps a whole archive or part in memory."""
    def __init__(self, root, prefix, limit=PART_BYTES):
        super().__init__()
        if limit <= 0:
            raise ValueError("Part size must be positive")
        self.root, self.prefix, self.limit = Path(root), prefix, limit
        self.root.mkdir(parents=True, exist_ok=True)
        self.parts, self.stream, self.position = [], None, 0
        self.count, self.digest = 0, None

    def tell(self):
        return self.position

    def writable(self):
        return True

    def finish_part(self):
        if self.stream:
            self.stream.close()
            self.parts.append({"name": self.name, "bytes": self.count, "sha256": self.digest.hexdigest()})
            self.stream = None

    def write(self, data):
        view = memoryview(data)
        size = len(view)
        while view:
            if self.stream is None:
                self.name = f"{self.prefix}.part{len(self.parts):03d}"
                self.stream = (self.root / self.name).open("wb")
                self.count, self.digest = 0, hashlib.sha256()
            n = min(len(view), self.limit - self.count)
            chunk = view[:n]
            self.stream.write(chunk)
            self.digest.update(chunk)
            self.count += n
            self.position += n
            view = view[n:]
            if self.count == self.limit:
                self.finish_part()
        return size

    def close(self):
        if not self.closed:
            self.finish_part()
        super().close()


def write_resources(romfs, msl, expected, destination, part_bytes=PART_BYTES):
    destination = Path(destination)
    chain_dir = Path(msl) / ("b-" + expected["shader_chain"])
    if not list(chain_dir.glob("*_b.metallib")):
        raise ValueError("No iOS libraries for the expected shader chain")
    marker = Path(romfs) / "SoundData/SeResourceStd2nd.aras"
    if not marker.is_file():
        raise ValueError("Missing merged 1.4.1 RomFS marker: " + str(marker))
    manifest = dict(expected, files=[])
    writer = PartWriter(destination, "SMO-Resources-1.4.1.zip", part_bytes)
    try:
        with zipfile.ZipFile(writer, "w", zipfile.ZIP_STORED, allowZip64=True) as archive:
            for prefix, root in (("romfs", Path(romfs)), ("msl/" + chain_dir.name, chain_dir)):
                for path in sorted(p for p in root.rglob("*") if p.is_file()):
                    if path.is_symlink():
                        raise ValueError("Resource symlinks are not supported: " + str(path))
                    name = safe_name(prefix + "/" + path.relative_to(root).as_posix())
                    info = zipfile.ZipInfo(name)
                    info.file_size = path.stat().st_size
                    digest, size = hashlib.sha256(), 0
                    with path.open("rb") as source, archive.open(info, "w", force_zip64=True) as target:
                        while data := source.read(BLOCK):
                            target.write(data)
                            digest.update(data)
                            size += len(data)
                    manifest["files"].append({"path": name, "bytes": size, "sha256": digest.hexdigest()})
                    if len(manifest["files"]) % 1000 == 0:
                        print(f"External resources: {len(manifest['files'])} files", flush=True)
            data = json_bytes(manifest)
            archive.writestr(zipfile.ZipInfo("resource_manifest.json"), data)
    finally:
        writer.close()
    (destination / "resource_manifest.json").write_bytes(data)
    parts = {"format": 1, "archive": "SMO-Resources-1.4.1.zip", "parts": writer.parts,
             "resource_manifest_sha256": hashlib.sha256(data).hexdigest()}
    (destination / "resources-parts.json").write_bytes(json_bytes(parts))
    return manifest, parts


def join_parts(root, parts, output):
    """Verify every part before atomically exposing the restored file."""
    root, output = Path(root), Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_name(output.name + ".partial")
    try:
        with partial.open("wb") as target:
            for part in parts:
                name = safe_name(part["name"])
                if "/" in name:
                    raise ValueError("Parts must be immediate children")
                digest, size = hashlib.sha256(), 0
                with (root / name).open("rb") as source:
                    while data := source.read(BLOCK):
                        target.write(data)
                        digest.update(data)
                        size += len(data)
                if size != part["bytes"] or digest.hexdigest() != part["sha256"]:
                    raise ValueError("Part is truncated or corrupt: " + name)
        os.replace(partial, output)
    finally:
        partial.unlink(missing_ok=True)


def restore_resources(parts_file, destination):
    parts_file, destination = Path(parts_file), Path(destination).resolve()
    spec = json.loads(parts_file.read_text(encoding="utf-8"))
    destination.mkdir(parents=True, exist_ok=True)
    # Do not leave an older completion manifest after a failed restore.
    (destination / "resource_manifest.json").unlink(missing_ok=True)
    # The joined archive is temporary; it never appears in the phone's directory.
    import tempfile
    with tempfile.TemporaryDirectory(prefix="smo-restore-", dir=destination.parent) as temp:
        archive_path = Path(temp) / "resources.zip"
        join_parts(parts_file.parent, spec["parts"], archive_path)
        with zipfile.ZipFile(archive_path) as archive:
            raw = archive.read("resource_manifest.json")
            if hashlib.sha256(raw).hexdigest() != spec["resource_manifest_sha256"]:
                raise ValueError("Resource manifest checksum mismatch")
            manifest = json.loads(raw)
            entries = {}
            for row in manifest["files"]:
                name = safe_name(row["path"])
                if not name.startswith(("romfs/", "msl/")) or name in entries:
                    raise ValueError("Unexpected or duplicate resource path: " + name)
                entries[name] = row
            names = archive.namelist()
            if len(names) != len(set(names)) or set(names) != set(entries) | {"resource_manifest.json"}:
                raise ValueError("ZIP entries do not match the resource manifest")
            for name, row in entries.items():
                path = destination / name
                if not path.resolve().is_relative_to(destination):
                    raise ValueError("Resource destination escapes through a symlink")
                path.parent.mkdir(parents=True, exist_ok=True)
                partial = path.with_name(path.name + ".partial")
                try:
                    digest, size = hashlib.sha256(), 0
                    with archive.open(name) as source, partial.open("wb") as target:
                        while data := source.read(BLOCK):
                            target.write(data)
                            digest.update(data)
                            size += len(data)
                    if size != row["bytes"] or digest.hexdigest() != row["sha256"]:
                        raise ValueError("Resource checksum mismatch: " + name)
                    os.replace(partial, path)
                finally:
                    partial.unlink(missing_ok=True)
            (destination / "resource_manifest.json").write_bytes(raw)
    return manifest
