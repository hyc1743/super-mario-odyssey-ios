"""Store bounded runtime shader and frame evidence in the private repository.

Never attach these raw captures to public CI artifacts or print their contents.
Only hashes, sizes and the resulting private commit ID are logged.
"""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import urllib.request
import urllib.error
import zipfile


def archive_captures(directory, frame_directory=None):
    files = sorted([*directory.glob("shader-*.bin"), *directory.glob("metal-error-*.txt")])
    if len(files) > 24 or any(p.stat().st_size > 65536 for p in files):
        raise ValueError("shader capture exceeds bounded diagnostic limits")
    # frame-recent-*.ppm only feed the local packaging gate; keep the upload to the
    # first two frames and the latest one.
    frames = sorted(p for p in frame_directory.glob("frame-*.ppm")
                    if not p.name.startswith("frame-recent-")) if frame_directory else []
    if len(frames) > 3 or any(p.stat().st_size > 13 * 1024 * 1024 for p in frames):
        raise ValueError("frame capture exceeds bounded diagnostic limits")
    if not files and not frames:
        return None
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in files + frames:
            archive.writestr(path.name, path.read_bytes())
    return output.getvalue()


def main():
    data = archive_captures(Path(os.environ.get("SMO_SHADER_CAPTURE_DIR", "/tmp/smo-private-shader-capture")),
                            Path(os.environ.get("SMO_FRAME_CAPTURE_DIR", "/tmp/smo-private-frame-capture")))
    if data is None:
        print("No private runtime captures to upload")
        return
    repo = os.environ["PRIVATE_REPO"]
    run = os.environ["GITHUB_RUN_ID"]
    if not run.isdecimal() or len(repo.split("/")) != 2:
        raise ValueError("invalid private diagnostic destination")
    token = os.environ["SMO_PRIVATE_TOKEN"]
    headers = {"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
               "Content-Type": "application/json"}

    def api(path, body=None):
        request = urllib.request.Request("https://api.github.com/repos/" + repo + path,
                                         headers=headers, data=None if body is None else json.dumps(body).encode(),
                                         method="GET" if body is None else "PUT")
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response)

    if api("").get("private") is not True:
        raise ValueError("runtime captures require a private repository")
    path = "/contents/diagnostics/shaders-" + run + ".zip"
    body = {
        "message": "Capture bounded private runtime evidence for run " + run,
        "branch": "embed-input", "content": base64.b64encode(data).decode("ascii"),
    }
    try:
        body["sha"] = api(path + "?ref=embed-input")["sha"]
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
    result = api(path, body)
    print("Private runtime diagnostic uploaded: bytes=" + str(len(data)) +
          " sha256=" + hashlib.sha256(data).hexdigest() + " commit=" + result["commit"]["sha"])


if __name__ == "__main__":
    main()
