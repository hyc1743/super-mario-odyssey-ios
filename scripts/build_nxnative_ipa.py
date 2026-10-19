#!/usr/bin/env python3
"""Build a public nxnative shell or a private 1.4.1 IPA with external data.

Run on macOS with Xcode 26+, XcodeGen and Python. Personal builds additionally
need .NET 10, zstd, spirv-cross, lz4, capstone and fonttools. Neither mode signs
or installs the app. The pristine pinned checkout is never modified.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "smo/nxnative"))
sys.path.insert(0, str(ROOT / "smo/verify"))
from package import LOCK, identity, json_bytes, sha256, validate_build, write_resources
from check_thin_ipa import inspect


def run(command, *, cwd=None, env=None, log=None):
    command = [str(c) for c in command]
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        with log.open("w", encoding="utf-8") as output:
            result = subprocess.run(command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT)
        if result.returncode:
            print("\n".join(log.read_text(encoding="utf-8", errors="replace").splitlines()[-45:]), flush=True)
            raise RuntimeError(f"{Path(command[0]).name} failed; see {log}")
        return ""
    return subprocess.check_output(command, cwd=cwd, env=env, text=True).strip()


def load_upstream(source):
    path = source / "scripts/build_ipa_from_nsp.py"
    spec = importlib.util.spec_from_file_location("nxnative_build", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.PROG.mode = "lines"
    return module


def checkout(destination, supplied=None):
    source = Path(supplied).resolve() if supplied else destination / "nxnative-pristine"
    if not source.exists():
        source.mkdir(parents=True)
        run(["git", "init", source])
        run(["git", "-C", source, "remote", "add", "origin", LOCK["repository"]])
        run(["git", "-C", source, "fetch", "--depth", "1", "origin", LOCK["commit"]])
        run(["git", "-C", source, "checkout", "--detach", "FETCH_HEAD"])
    if run(["git", "-C", source, "rev-parse", "HEAD"]) != LOCK["commit"]:
        raise ValueError("nxnative checkout is not the pinned commit")
    if subprocess.run(["git", "-C", source, "diff", "--quiet", "HEAD", "--"]).returncode:
        raise ValueError("nxnative checkout has tracked modifications; provide a clean checkout")
    return source


def adapt(source):
    """Only the iOS boot adapter and resource list differ from pinned upstream."""
    ios = source / "dm/ios"
    for name in ("main.m", "SMOResources.h", "SMOResources.m"):
        shutil.copy2(ROOT / "smo/nxnative" / name, ios / "Sources" / name)
    project = ios / "project.yml"
    text = project.read_text(encoding="utf-8")
    block = "      - path: Gen/msl         # iOS metallib + reflection json (DM_MSL_DIR)\n        type: folder\n        buildPhase: resources\n"
    if text.count(block) != 1:
        raise ValueError("Pinned nxnative iOS resource layout changed")
    project.write_text(text.replace(block, ""), encoding="utf-8", newline="\n")


def fonts(destination):
    sys.path.insert(0, str(ROOT / "smo/tools"))
    from prepare_shared_fonts import FILES, fetch
    destination.mkdir(parents=True, exist_ok=True)
    for name in ("standard.ttf", "OFL-CJK.txt"):
        fetch((name, FILES[name]), destination)


def assemble(source, work, output, mode, expected, *, patched=None, resources=None):
    ios = source / "dm/ios"
    gen = ios / "Gen"
    gen.mkdir()
    (gen / "dm/font").mkdir(parents=True)
    env = dict(os.environ, GAME=LOCK["title_id"], DM_GAME=LOCK["title_id"],
               DM_GAMES_DIR=str(source / "dm/games"), DM_ROOT=str(work),
               DM_BUNDLE_ID=LOCK["bundle_id"], DM_DISPLAY_NAME=LOCK["display_name"],
               DM_APP_VERSION="1.4.1", DM_TEAM_ID="0000000000", DM_APP_CATEGORY="public.app-category.games")
    config = run([sys.executable, ios / "tools/gen_build.py", source / "dm/host", gen], env=env)
    link = ""
    if mode == "personal":
        link = run([sys.executable, ios / "tools/gen_embed.py", patched, gen / "embed.S", "main", "subsdk0", "sdk"], env=env)
        for suffix in ("fixups", "gates", "params", "cuts", "obs"):
            for file in patched.glob(f"*.{suffix}.tsv"):
                shutil.copy2(file, gen / "dm" / file.name)
        for name in ("shader_map.tsv", "pso_manifest.tsv", "c1_full.tsv"):
            shutil.copy2(source / "dm/games" / LOCK["title_id"] / name, gen / "dm" / name)
    else:
        (gen / "embed.S").write_text("// Public shell: no game code or data.\n", encoding="utf-8")
    (gen / "dm.xcconfig").write_text(config + "\nOTHER_LDFLAGS = $(inherited) $(DM_FRAMEWORKS) " + link + "\nDM_APPICON = AppIcon\n", encoding="utf-8")
    package_identity = dict(expected, package_kind=mode)
    if resources:
        package_identity["resource_manifest_sha256"] = resources["resource_manifest_sha256"]
    (gen / "dm/package_identity.json").write_bytes(json_bytes(package_identity))
    fonts(work / "fonts")
    for name in ("standard.ttf", "OFL-CJK.txt"):
        shutil.copy2(work / "fonts" / name, gen / "dm/font" / name)
    run([sys.executable, source / "dm/tools/make_ext_font.py", gen / "dm/font/nintendo_ext.ttf"], log=work / "logs/font.log")
    shutil.copytree(ROOT / "smo/ios/Resources/Assets.xcassets", gen / "Assets.xcassets")
    notices = gen / "dm/Licenses"
    notices.mkdir()
    shutil.copy2(source / "LICENSE", notices / "nxnative-MIT.txt")
    shutil.copy2(ROOT / "LICENSE", notices / "SMOMobile-MIT.txt")
    third_party = source / "dm/third_party"
    for path in third_party.rglob("*"):
        if path.is_file() and (path.name.upper().startswith(("LICENSE", "COPYING")) or path.name == "README.md"):
            target = notices / path.relative_to(third_party)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    run(["xcodegen", "generate", "--spec", "project.yml"], cwd=ios, env=env, log=work / "logs/xcodegen.log")
    print(f"Building unsigned {mode} IPA from nxnative {LOCK['commit'][:12]}", flush=True)
    run(["xcodebuild", "-project", "DmIOS.xcodeproj", "-scheme", "DmIOS", "-configuration", "Release",
         "-destination", "generic/platform=iOS", "-derivedDataPath", work / "DerivedData",
         "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=", "build"],
        cwd=ios, env=env, log=work / "logs/xcodebuild.log")
    app = work / "DerivedData/Build/Products/Release-iphoneos/DmIOS.app"
    if not app.is_dir():
        raise ValueError("xcodebuild did not produce DmIOS.app in the requested DerivedData")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != LOCK["bundle_id"] or info.get("MinimumOSVersion") != LOCK["minimum_ios"]:
        raise ValueError("Unexpected app bundle ID or deployment target")
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(p for p in app.rglob("*") if p.is_file()):
            relative = path.relative_to(app)
            if "_CodeSignature" in relative.parts or path.name == "embedded.mobileprovision":
                continue
            archive.write(path, "Payload/SMOMobile.app/" + relative.as_posix())
    report = inspect(output, policy=mode)
    if not report["thin"]:
        raise ValueError("IPA content boundary failed: " + json.dumps(report))
    return report


def personal_inputs(args):
    for name in ("base_nsp", "update_nsp", "keys"):
        value = getattr(args, name)
        if not value or not value.is_file():
            raise ValueError(f"Personal mode requires --{name.replace('_', '-')} pointing to a file")
    for path in (args.base_nsp, args.update_nsp):
        with path.open("rb") as f:
            if f.read(4) != b"PFS0":
                raise ValueError(f"Not an NSP/PFS0 file: {path.name}")
    if args.base_nsp.resolve() == args.update_nsp.resolve():
        raise ValueError("Base and update NSP must be separate files")


def build(args):
    if args.mode == "personal":
        personal_inputs(args)
    if sys.platform != "darwin":
        raise ValueError("IPA builds require macOS/Xcode; run the current repository's GitHub Actions workflow")
    sdk = run(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"])
    if int(sdk.split(".")[0]) < 26:
        raise ValueError("The selected Xcode needs an iOS 26+ SDK")
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    pristine = checkout(out / "work", args.nxnative_root)
    work = out / "work"
    work.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="nxnative-build-", dir=work) as temporary:
        source = Path(temporary) / "source"
        shutil.copytree(pristine, source, ignore=shutil.ignore_patterns(".git", "__pycache__"))
        adapt(source)
        expected = identity(source / "dm/games" / LOCK["title_id"])
        patched, parts, shader_report = None, None, None
        upstream = None
        try:
            if args.mode == "personal":
                upstream = load_upstream(source)
                sys.path.insert(0, str(source / "dm/games"))
                import game
                profile = game.load(LOCK["title_id"])
                env = dict(os.environ, GAME=LOCK["title_id"], DM_GAME=LOCK["title_id"],
                           DM_GAMES_DIR=str(source / "dm/games"), DM_ROOT=str(work), WORK=str(work / "tmp"),
                           J=os.environ.get("J", "3"))
                env["PATH"] = os.pathsep.join(upstream.TOOL_PATHS + [env.get("PATH", "")])
                (work / "tmp").mkdir(exist_ok=True)
                xlate = source / "dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate"
                upstream.check_prereqs(env, xlate)
                # Record the runner's actual tools and rebuild their chain in
                # this disposable checkout rather than bypassing the tool lock.
                chain_tool = source / "dm/gfx/tools/dmsh_chain.py"
                run([sys.executable, chain_tool, "--update-lock"], env=env, log=work / "logs/shader-tools.log")
                run([sys.executable, chain_tool, "--header"], env=env, log=work / "logs/shader-chain.log")
                expected = identity(source / "dm/games" / LOCK["title_id"])
                upstream.PROG.plan(5)
                upstream.PROG.stage("build nx_extract")
                nx = upstream.build_nx_extract(source, work, work / "logs", env)
                upstream.PROG.end()
                extracted = upstream.extract(nx, args.keys.resolve(), work / "extract", LOCK["package"],
                                             args.base_nsp.resolve(), args.update_nsp.resolve(), None, work / "logs", profile)
                validate_build(extracted / "ExeFS", expected)
                # Only disposable runner inputs may be removed to make room for shader compilation.
                if args.discard_runner_inputs:
                    runner_temp = Path(os.environ["RUNNER_TEMP"]).resolve()
                    for file in (args.base_nsp, args.update_nsp):
                        if not file.resolve().is_relative_to(runner_temp):
                            raise ValueError("Refusing to discard inputs outside RUNNER_TEMP")
                    args.base_nsp.unlink(); args.update_nsp.unlink()
                patched = work / "patched_v393216"
                upstream.rewrite(sys.executable, source, extracted / "ExeFS", patched, env, work / "logs", profile)
                sh = work / "shader"
                upstream.split_shaders(sys.executable, source, [extracted / "RomFS"], [extracted / "ExeFS/main"],
                                       sh / "pkg", env, work / "logs", profile)
                ios = upstream.build_shaders(sys.executable, source, sh, xlate, env, work / "logs", profile)
                shader_text = (work / "logs/dmsh_build.log").read_text(encoding="utf-8", errors="replace")
                counts = re.search(r"着色器 (\d+)：成功 (\d+)", shader_text)
                shader_report = {"ios_libraries": len(list((ios / ("b-" + expected["shader_chain"])).glob("*_b.metallib")))}
                if counts:
                    total, ready = map(int, counts.groups())
                    shader_report.update(total=total, ready=ready, failed=total - ready)
                run([sys.executable, source / "dm/gfx/tools/c1_guard.py", sh / "cache" / ("b-" + expected["shader_chain"]),
                     profile.table("c1_full.tsv")], env=env, log=work / "logs/c1-guard.log")
                shutil.copy2(source / "dm/gfx/tools/dmsh_chain.lock", out / "shader-toolchain.lock")
                _, parts = write_resources(extracted / "RomFS", ios, expected, out / "resources")
            name = "SMOMobile-shell.ipa" if args.mode == "shell" else "SMOMobile-1.4.1.ipa"
            report = assemble(source, work, out / name, args.mode, expected, patched=patched, resources=parts)
            summary = dict(expected, mode=args.mode, ipa=name, ipa_sha256=sha256(out / name), ipa_bytes=(out / name).stat().st_size,
                           validation=report, resource_parts=parts, shader_build=shader_report,
                           device_validation="not performed; user sideload required")
            (out / "build_report.json").write_bytes(json_bytes(summary))
            (out / "thin_ipa_report.json").write_bytes(json_bytes(report))
            shutil.copy2(ROOT / "docs/README_INSTALL.md", out / "README_INSTALL.md")
            if args.mode == "personal":
                # Ship a standalone restore tool with the private resource package.
                shutil.copy2(ROOT / "scripts/restore_nxnative_resources.py", out / "resources/restore_nxnative_resources.py")
                # The standalone copy has its module beside it, instead of the repository layout.
                tool = out / "resources/restore_nxnative_resources.py"
                text = tool.read_text(encoding="utf-8").replace('str(Path(__file__).resolve().parents[1] / "smo/nxnative")', 'str(Path(__file__).resolve().parent)')
                tool.write_text(text, encoding="utf-8")
                shutil.copy2(ROOT / "smo/nxnative/package.py", out / "resources/package.py")
                shutil.copy2(ROOT / "smo/nxnative/lock.json", out / "resources/lock.json")
            print(f"Verified {args.mode} IPA: {out / name}", flush=True)
        finally:
            if upstream:
                upstream.PROG.close(ok=False)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("shell", "personal"), default="shell")
    parser.add_argument("--base-nsp", type=Path)
    parser.add_argument("--update-nsp", type=Path)
    parser.add_argument("--keys", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "out/nxnative")
    parser.add_argument("--nxnative-root", type=Path, help="optional clean checkout of the pinned commit")
    parser.add_argument("--discard-runner-inputs", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        build(args)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Build failed: {error}\n")


if __name__ == "__main__":
    main()
