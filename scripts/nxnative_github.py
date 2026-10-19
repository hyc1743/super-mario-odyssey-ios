#!/usr/bin/env python3
"""Private GitHub transport for nxnative inputs and personal build outputs.

Credentials come from SMO_PRIVATE_TOKEN (CI), GH_TOKEN or Git Credential Manager.
Keys are encrypted into an Actions Secret, never uploaded as release assets.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "smo/nxnative"))
from package import BLOCK, LOCK, PART_BYTES, join_parts, json_bytes, safe_name, sha256


class RangeReader:
    def __init__(self, path, start, size):
        self.stream = Path(path).open("rb")
        self.stream.seek(start)
        self.remaining = size

    def read(self, size=-1):
        n = min(self.remaining, size if size >= 0 else BLOCK)
        data = self.stream.read(n)
        self.remaining -= len(data)
        return data

    def close(self):
        self.stream.close()


def token():
    value = os.environ.get("SMO_PRIVATE_TOKEN") or os.environ.get("GH_TOKEN")
    if value:
        return value.strip()
    result = subprocess.run(["git", "credential", "fill"], input="protocol=https\nhost=github.com\n\n",
                            capture_output=True, text=True, check=True)
    credentials = dict(row.split("=", 1) for row in result.stdout.splitlines() if "=" in row)
    if not credentials.get("password"):
        raise ValueError("No GitHub credentials available")
    return credentials["password"]


class GitHub:
    def __init__(self, repo):
        if len(repo.split("/")) != 2 or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._/" for c in repo):
            raise ValueError("Expected owner/repository")
        self.repo, self.token = repo, token()
        self.base = "https://api.github.com/repos/" + repo

    def request(self, method, url, data=None, *, accept="application/vnd.github+json", content_type="application/json", size=None):
        if not url.startswith("https://"):
            url = self.base + url
        if isinstance(data, (dict, list)):
            data = json_bytes(data)
        headers = {"Authorization": "Bearer " + self.token, "Accept": accept,
                   "User-Agent": "SMOMobile-nxnative", "X-GitHub-Api-Version": "2022-11-28",
                   "Content-Type": content_type}
        if size is not None:
            headers["Content-Length"] = str(size)
        return urllib.request.urlopen(urllib.request.Request(url, data=data, method=method, headers=headers), timeout=180)

    def api(self, method, url, data=None):
        with self.request(method, url, data) as response:
            raw = response.read()
        return json.loads(raw) if raw else None

    def private(self):
        if not self.api("GET", "")["private"]:
            raise ValueError("Game inputs and personal outputs require a private repository")

    def release(self, tag, create=False):
        try:
            return self.api("GET", "/releases/tags/" + urllib.parse.quote(tag, safe=""))
        except urllib.error.HTTPError as error:
            if error.code != 404 or not create:
                raise
        return self.api("POST", "/releases", {"tag_name": tag, "name": tag, "prerelease": True,
                                             "body": "Private user-owned nxnative build inputs or outputs. Unsigned IPA; external game resources."})

    def assets(self, release):
        result, page = [], 1
        while True:
            batch = self.api("GET", f"/releases/{release['id']}/assets?per_page=100&page={page}")
            result.extend(batch)
            if len(batch) < 100:
                return {a["name"]: a for a in result}
            page += 1

    def upload(self, release, name, path=None, *, data=None, start=0, size=None, replace=False):
        safe_name(name)
        existing = self.assets(release).get(name)
        if existing:
            if not replace:
                if existing.get("state") != "uploaded":
                    self.api("DELETE", f"/releases/assets/{existing['id']}")
                elif existing["size"] != size:
                    raise ValueError("Existing release asset size mismatch: " + name)
                else:
                    print("Reusing private asset: " + name, flush=True)
                    return
            else:
                self.api("DELETE", f"/releases/assets/{existing['id']}")
        url = release["upload_url"].split("{", 1)[0] + "?name=" + urllib.parse.quote(name)
        reader = RangeReader(path, start, size) if path else io.BytesIO(data)
        try:
            with self.request("POST", url, reader, content_type="application/octet-stream", size=size) as response:
                result = json.load(response)
            if result["size"] != size:
                raise ValueError("Incomplete release upload: " + name)
        finally:
            reader.close()
        print("Uploaded private asset: " + name, flush=True)

    def download(self, asset, destination):
        destination = Path(destination)
        for attempt in range(3):
            try:
                url = asset["url"] + "?download_nonce=" + str(time.time_ns())
                with self.request("GET", url, accept="application/octet-stream") as source, destination.open("wb") as target:
                    import shutil
                    shutil.copyfileobj(source, target, BLOCK)
                if destination.stat().st_size != asset["size"]:
                    raise ValueError("Incomplete asset download: " + asset["name"])
                return
            except (OSError, ValueError):
                if attempt == 2:
                    raise
                time.sleep(2)


def scan_input(path, role):
    path = Path(path)
    with path.open("rb") as stream:
        if stream.read(4) != b"PFS0":
            raise ValueError("Not an NSP/PFS0: " + path.name)
        stream.seek(0)
        parts, full = [], hashlib.sha256()
        while True:
            count, digest = 0, hashlib.sha256()
            while count < PART_BYTES:
                block = stream.read(min(BLOCK, PART_BYTES - count))
                if not block:
                    break
                digest.update(block); full.update(block); count += len(block)
            if not count:
                break
            checksum = digest.hexdigest()
            parts.append({"name": f"{role}-{len(parts):03d}-{checksum[:16]}.nsp-part", "bytes": count, "sha256": checksum})
    return {"role": role, "name": role + ".nsp", "bytes": path.stat().st_size, "sha256": full.hexdigest(), "parts": parts}


def prepare_inputs(args):
    private = GitHub(args.private_repo); private.private()
    release = private.release(args.input_tag, create=True)
    manifest = {"format": 1, "title_id": LOCK["title_id"], "game_version": LOCK["game_version"], "files": []}
    for role, path in (("base", args.base_nsp), ("update", args.update_nsp)):
        row = scan_input(path, role)
        offset = 0
        for part in row["parts"]:
            private.upload(release, part["name"], path, start=offset, size=part["bytes"])
            offset += part["bytes"]
        manifest["files"].append(row)
    data = json_bytes(manifest)
    private.upload(release, "nxnative-inputs.json", data=data, size=len(data), replace=True)
    if args.keys:
        from nacl import encoding, public
        public_repo = GitHub(args.repo)
        key = public_repo.api("GET", "/actions/secrets/public-key")
        sealed = public.SealedBox(public.PublicKey(key["key"].encode(), encoding.Base64Encoder())).encrypt(args.keys.read_bytes())
        public_repo.api("PUT", "/actions/secrets/SMO_PROD_KEYS", {"key_id": key["key_id"], "encrypted_value": base64.b64encode(sealed).decode()})
        print("Configured SMO_PROD_KEYS Actions Secret (value not displayed).", flush=True)
    print("Private 1.4.1 inputs ready: " + args.input_tag, flush=True)


def fetch_inputs(args):
    github = GitHub(args.private_repo); github.private()
    release = github.release(args.input_tag)
    assets = github.assets(release)
    out = args.destination.resolve(); out.mkdir(parents=True, exist_ok=True)
    github.download(assets["nxnative-inputs.json"], out / "nxnative-inputs.json")
    manifest = json.loads((out / "nxnative-inputs.json").read_text(encoding="utf-8"))
    if manifest.get("title_id") != LOCK["title_id"] or manifest.get("game_version") != LOCK["game_version"]:
        raise ValueError("Wrong game/version in private input manifest")
    rows = manifest["files"]
    if len(rows) != 2 or {r["role"] for r in rows} != {"base", "update"}:
        raise ValueError("Both base and 1.4.1 update inputs are required")
    for row in rows:
        output = out / (row["role"] + ".nsp")
        partial = output.with_suffix(".nsp.partial")
        # Download one part at a time; avoid keeping another 6 GB of input parts.
        with partial.open("wb") as target:
            for part in row["parts"]:
                name = safe_name(part["name"])
                if "/" in name:
                    raise ValueError("Invalid input asset name")
                download = out / name
                github.download(assets[name], download)
                if download.stat().st_size != part["bytes"] or sha256(download) != part["sha256"]:
                    raise ValueError("Input part checksum mismatch: " + name)
                with download.open("rb") as source:
                    import shutil
                    shutil.copyfileobj(source, target, BLOCK)
                download.unlink()
        if partial.stat().st_size != row["bytes"] or sha256(partial) != row["sha256"]:
            raise ValueError("Input NSP checksum mismatch: " + row["role"])
        os.replace(partial, output)
        print("Verified private input: " + row["role"], flush=True)
    keys = os.environ.get("SMO_PROD_KEYS", "")
    if not keys:
        raise ValueError("SMO_PROD_KEYS Actions Secret is missing")
    key_path = out / "prod.keys"
    key_path.write_text(keys, encoding="utf-8")
    key_path.chmod(0o600)


def publish(args):
    github = GitHub(args.private_repo); github.private()
    release = github.release(args.tag, create=True)
    directory = args.directory.resolve()
    if args.logs_only:
        log_archive = directory / "private-build-logs.zip"
        with zipfile.ZipFile(log_archive, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in directory.rglob("*.log"):
                archive.write(path, path.relative_to(directory).as_posix())
        paths = [log_archive]
    else:
        from importlib.util import spec_from_file_location, module_from_spec
        spec = spec_from_file_location("ipa_boundary", ROOT / "smo/verify/check_thin_ipa.py")
        checker = module_from_spec(spec); spec.loader.exec_module(checker)
        ipa = directory / "SMOMobile-1.4.1.ipa"
        if not checker.inspect(ipa, "personal")["thin"]:
            raise ValueError("Personal IPA failed publication boundary check")
        paths = [ipa, directory / "build_report.json", directory / "thin_ipa_report.json",
                 directory / "README_INSTALL.md", directory / "shader-toolchain.lock"]
        paths.extend(sorted((directory / "resources").iterdir()))
    for path in paths:
        if path.is_file():
            github.upload(release, path.name, path, size=path.stat().st_size, replace=True)
    print("Private release ready: " + args.tag, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--private-repo", default="hyc1743/super-mario-odyssey-ios-build")
    sub = parser.add_subparsers(dest="command", required=True)
    prepare = sub.add_parser("prepare-inputs")
    prepare.add_argument("--repo", default="hyc1743/super-mario-odyssey-ios")
    prepare.add_argument("--input-tag", default="nxnative-inputs-1.4.1")
    prepare.add_argument("--base-nsp", type=Path, required=True)
    prepare.add_argument("--update-nsp", type=Path, required=True)
    prepare.add_argument("--keys", type=Path)
    fetch = sub.add_parser("fetch-inputs")
    fetch.add_argument("--input-tag", default="nxnative-inputs-1.4.1")
    fetch.add_argument("--destination", type=Path, required=True)
    pub = sub.add_parser("publish")
    pub.add_argument("--tag", required=True)
    pub.add_argument("--directory", type=Path, required=True)
    pub.add_argument("--logs-only", action="store_true")
    args = parser.parse_args()
    try:
        {"prepare-inputs": prepare_inputs, "fetch-inputs": fetch_inputs, "publish": publish}[args.command](args)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"GitHub transfer failed: {error}\n")


if __name__ == "__main__":
    main()
