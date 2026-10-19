import hashlib
import importlib.util
from pathlib import Path
import plistlib
import struct
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "smo/nxnative"))
sys.path.insert(0, str(ROOT / "smo/verify"))
from package import LOCK, PartWriter, json_bytes, restore_resources, sha256, validate_build, write_resources
from check_thin_ipa import inspect


def macho(sections=()):
    length = 72 + len(sections) * 80
    command = struct.pack("<II16sQQQQiiII", 0x19, length, b"__TEXT", 0, 0x4000, 0, 0x4000, 5, 5, len(sections), 0)
    for name in sections:
        command += struct.pack("<16s16sQQIIIIIIII", name.encode(), b"__TEXT", 0, 0, 0, 14, 0, 0, 0, 0, 0, 0)
    return struct.pack("<8I", 0xfeedfacf, 0x100000c, 0, 2, 1, length, 0, 0) + command


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="smo-nxnative-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def ipa(self, sections=(), extra=None):
        path = self.root / "test.ipa"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("Payload/SMOMobile.app/Info.plist", plistlib.dumps({"CFBundleExecutable": "SMOMobile", "MinimumOSVersion": "26.0"}))
            archive.writestr("Payload/SMOMobile.app/SMOMobile", macho(sections))
            for name, data in (extra or {}).items():
                archive.writestr("Payload/SMOMobile.app/" + name, data)
        return path

    def test_shell_and_personal_boundaries(self):
        self.assertTrue(inspect(self.ipa())["thin"])
        self.assertFalse(inspect(self.ipa(), "personal")["thin"])
        sections = [f"__dm{m}{s}" for m in ("main", "sdk", "subsdk0") for s in ("x0", "x1")]
        path = self.ipa(sections)
        self.assertFalse(inspect(path, "shell")["thin"])
        self.assertTrue(inspect(path, "personal")["thin"])
        self.assertFalse(inspect(self.ipa(sections, {"romfs/asset": b"x"}), "personal")["thin"])

    def test_renamed_code_and_game_resources_are_rejected(self):
        for name, data in {
            "Frameworks/Guest.framework/Guest": macho(),
            "Frameworks/Other.framework/Other": macho(["__dmmainx0"]),
            "data/renamed.dat": b"NSO0" + bytes(100),
            "msl/b-test/example_b.metallib": b"MTLB",
            "RuntimeShaders/shaders.smoa": b"shader",
            "folder/archive.szs": b"raw",
            "prod.keys": b"test",
            "renamed-framework": b"\xca\xfe\xba\xbe" + bytes(60),
            "dm/main.fixups.tsv": b"metadata",
        }.items():
            with self.subTest(name=name):
                self.assertFalse(inspect(self.ipa(extra={name: data}))["thin"])

    def test_malformed_macho_is_rejected(self):
        path = self.ipa(extra={"renamed": macho()[:35]})
        with self.assertRaisesRegex(ValueError, "Truncated"):
            inspect(path)

    def resources(self):
        romfs, msl = self.root / "rom", self.root / "shader"
        (romfs / "SoundData").mkdir(parents=True)
        (romfs / "SoundData/SeResourceStd2nd.aras").write_bytes(b"game-data" * 10)
        (msl / "b-test").mkdir(parents=True)
        (msl / "b-test/example_b.metallib").write_bytes(b"MTLB" + bytes(90))
        (msl / "b-test/example_b.json").write_text("{}")
        expected = dict(format=1, title_id=LOCK["title_id"], game_version="1.4.1",
                        nxnative_commit=LOCK["commit"], shader_chain="test", build_ids={"main": "a" * 32})
        return romfs, msl, expected

    def test_multi_part_zip_round_trip(self):
        romfs, msl, expected = self.resources()
        out = self.root / "parts"
        manifest, spec = write_resources(romfs, msl, expected, out, part_bytes=97)
        self.assertGreater(len(spec["parts"]), 3)
        self.assertTrue(all(part["bytes"] <= 97 for part in spec["parts"]))
        restored = self.root / "restored"
        self.assertEqual(restore_resources(out / "resources-parts.json", restored), manifest)
        for row in manifest["files"]:
            self.assertEqual(sha256(restored / row["path"]), row["sha256"])
        self.assertFalse((restored / "resources.zip").exists())
        self.assertFalse((restored / "save").exists())

    def test_truncated_or_corrupt_part_is_rejected(self):
        romfs, msl, expected = self.resources()
        out = self.root / "parts"
        _, spec = write_resources(romfs, msl, expected, out, part_bytes=100)
        part = out / spec["parts"][0]["name"]
        data = bytearray(part.read_bytes()); data[0] ^= 1; part.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "corrupt"):
            restore_resources(out / "resources-parts.json", self.root / "restored")
        self.assertFalse((self.root / "restored/resource_manifest.json").exists())

    def test_restore_rejects_zip_traversal(self):
        out = self.root / "parts"; out.mkdir()
        manifest = {"files": [{"path": "../escape", "bytes": 1, "sha256": hashlib.sha256(b"x").hexdigest()}]}
        raw = json_bytes(manifest)
        writer = PartWriter(out, "evil", 100)
        with zipfile.ZipFile(writer, "w") as archive:
            archive.writestr("../escape", b"x")
            archive.writestr("resource_manifest.json", raw)
        writer.close()
        (out / "parts.json").write_bytes(json_bytes({"parts": writer.parts, "resource_manifest_sha256": hashlib.sha256(raw).hexdigest()}))
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            restore_resources(out / "parts.json", self.root / "restored")
        self.assertFalse((self.root / "escape").exists())

    def test_nso_build_id_rejects_v0(self):
        exefs = self.root / "ExeFS"; exefs.mkdir()
        header = b"NSO0" + bytes(0x3c) + bytes.fromhex("a" * 32) + bytes(16)
        (exefs / "main").write_bytes(header)
        validate_build(exefs, {"build_ids": {"main": "a" * 32}})
        with self.assertRaisesRegex(ValueError, "Build ID"):
            validate_build(exefs, {"build_ids": {"main": "b" * 32}})

    def test_missing_update_fails_before_a_build(self):
        spec = importlib.util.spec_from_file_location("build_nxnative", ROOT / "scripts/build_nxnative_ipa.py")
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        from types import SimpleNamespace
        base = self.root / "base.nsp"; base.write_bytes(b"PFS0")
        with self.assertRaisesRegex(ValueError, "update-nsp"):
            module.personal_inputs(SimpleNamespace(base_nsp=base, update_nsp=None, keys=None))


if __name__ == "__main__":
    unittest.main()
