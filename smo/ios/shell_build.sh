#!/bin/bash
# 构建 App 壳并打成**未签名 IPA**。CI（GitHub 的 macOS runner）与本机都能跑。
#
# 需要一个装了 Xcode 的 macOS；xcodegen 用来生成 .xcodeproj。
#   brew install xcodegen
#
# 用法：  bash smo/ios/shell_build.sh
# 环境变量：
#   SMO_OUT      产物目录（默认 smo/ios/out）
#   SMO_VERSION  版本号（默认取 git describe，取不到就是 0.1.0）
#                —— 注意会做合法性归化：CFBundleShortVersionString 只允许「数字 + 点」，
#                   传 git SHA 进来（CI 在分支推送时会这么传）也自动回落到 0.1.0
set -euo pipefail
# 注意用 if 而不是「[ … ] && set -x」：后者在 set -e 下，条件不成立时整条 AND-OR 列表返回非零，
# 有的 bash（例如 macOS 自带的 3.2）会因此当场中止脚本。
if [ -n "${SMO_DEBUG:-}" ]; then set -x; fi      # CI 上开：日志里能看到死在哪个命令
cd "$(dirname "$0")"

ROOT=$(cd ../.. && pwd)                 # 仓库根（本脚本在 smo/ios/ 下）
PY=${SMO_PY:-python3}                   # 本机跑可用 smo/env.sh 里的 $PY；CI 上是 python3

OUT=${SMO_OUT:-out}

# 版本号归化：v1.2.3 → 1.2.3；别的（例如 40 位 SHA）→ 0.1.0
# 注意：**先给 VERSION 默认值**。本脚本带 set -u，只要哪个 case 分支没命中就会当场报
# 「VERSION: unbound variable」（CI 上已经这么挂过一次，且本地跑同样的片段是好的，
#  所以除了修，还把 shell 版本号与实际取值打出来，让下次失败自己说明白）。
VERSION=0.1.0
RAW="${SMO_VERSION:-$(git describe --tags --always 2>/dev/null || true)}"
case "$RAW" in
  v[0-9]*.[0-9]*)     VERSION="${RAW#v}" ;;
  [0-9]*.[0-9]*)      VERSION="$RAW" ;;
esac
echo "== shell: bash ${BASH_VERSION:-?} | RAW=[$RAW] VERSION=[$VERSION] =="
# 注意：变量一律加花括号。macOS 自带的 bash 3.2 是多字节不安全的：
# 「$VERSION，来源」里的全角逗号会被当成变量名的一部分（查 VERSION， → unbound），
# 而本地 bash 5.x 是好的 —— 这个坑真实地把 CI 挂掉过，见 STATUS.md。
echo "== 构建 SMOMobile 壳（版本 ${VERSION}，来源 '${RAW}'）=="
sw_vers
xcodebuild -version

command -v xcodegen >/dev/null || { echo "缺 xcodegen：brew install xcodegen"; exit 1; }

# 部署目标：不能写死太低 —— 新版 Xcode 会当场拒绝（"range of supported deployment target versions"）。
# 从 SDK 自己的 SDKSettings.plist 读它允许的最低值，并取「工程里写的」与「SDK 允许的」中较大者。
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
SDK_VER=$(xcrun --sdk iphoneos --show-sdk-version)
SDK_MIN=$(/usr/libexec/PlistBuddy -c "Print :MinimumDeploymentTarget" "$SDK_PATH/SDKSettings.plist" 2>/dev/null || true)
[ -n "$SDK_MIN" ] || SDK_MIN=$SDK_VER
# 注意两个 macOS 坑（踩过）：
#   1) BSD sort 不支持 -V（那是 GNU coreutils），用 awk 比版本号；
#   2) 管道接 head -1 在 pipefail 下可能被 SIGPIPE 判失败，所以用 awk 「打印后立即 exit」。
PROJ_DEP=$(awk -F'"' '/^ *iOS: "/{print $2; exit}' project.yml)
DEP=$(awk -v a="${PROJ_DEP:-0}" -v b="$SDK_MIN" 'BEGIN{
  na=split(a,x,"."); nb=split(b,y,".");
  for(i=1;i<=3;i++){ xa=x[i]+0; yb=y[i]+0; if(xa>yb){print a; exit} if(yb>xa){print b; exit} }
  print a }')
echo "== 部署目标：工程写的 ${PROJ_DEP:-无}，SDK $SDK_VER 允许的最低 $SDK_MIN ⇒ 用 $DEP =="

python3 tools/gen_icon.py

rm -rf Gen "$OUT"
mkdir -p Gen "$OUT"
"$PY" "$ROOT/smo/tools/prepare_shared_fonts.py" "$ROOT/smo/ios/Resources/SharedFonts"

# Optional resource gate used by the thin-IPA entry point.
# The validator only reads existing ExeFS/RomFS and writes a small report.
if [ -n "${SMO_RESOURCE_ROOT:-}" ]; then
  echo "== 检查外置游戏资源（不复制进 IPA） =="
  "$PY" "$ROOT/smo/tools/build_ipa.py" \
    --resources "$SMO_RESOURCE_ROOT" \
    --output "$OUT" \
    --report "$OUT/build_report.json"
fi

# 在当前目录生成工程（**不是** Gen/）：xcodegen 把 --project 指定的目录当作相对基准，
# 若生成到 Gen/，project.yml 里的 info.path(Sources/Resources) 都会被拼成 Gen/Gen/Info.plist、
# Gen/Sources 之类 —— CI 上就是这么报的：Build input file cannot be found: .../Gen/Gen/Info.plist

# 构建日志同时落到文件：CI 在失败时把它传成 artifact，否则只有管理员能看日志
LOG="$OUT/xcodebuild.log"

# ---- 三段内嵌（可选）：只有本机已生成改写产物时才做 ----
# iOS 真机不许运行时生成/改代码，客体映像必须在出包时就编进可执行文件（见 loader_apple.c 开头的说明）。
# 生成物：smo/ios/Sources/Embedded.S（三个签名段：__TEXT,__dm<模块>x0 / __DM<模块>W,__img / __TEXT,__dm<模块>x1）
# 已做的：生成 .S + manifest，并**校验三段能拼回原映像**（check_embed.py，不需要 macOS 也能跑）。
# 还差的一步：把打印出来的 -segprot 参数接进 Xcode 链接（xcodegen 的 settings 里加 OTHER_LDFLAGS），
# 以及 loader_apple.c 的 iOS 分支（vm_allocate 保留 + 三段 mach_vm_remap 回同一基址）。
# 注意：这一段必须在 **xcodebuild 那一整条命令之前**（它有多行续行，插中间会把 build 变成独立命令）。
EMBED_SRC="$ROOT/smo/ios/Sources/Embedded.S"
if ls "$ROOT/work/rewrite/"*.patched.bin >/dev/null 2>&1; then
  echo "== 三段内嵌：把改写产物编进壳 =="
  "$PY" "$ROOT/smo/ios/tools/gen_embed.py" "$ROOT/work/rewrite" "$EMBED_SRC" sdk subsdk0 main | tee "$OUT/embed_flags.txt"
  "$PY" "$ROOT/smo/ios/tools/check_embed.py" "$EMBED_SRC"
  echo "   链接参数（待接进 Xcode）：$(tail -1 "$OUT/embed_flags.txt")"
else
  echo "== 跳过三段内嵌（没有 work/rewrite/*.patched.bin；壳仍然能编，只是没有客体映像）=="
fi

BUILD_OPTIONS=()
if [ -f "$EMBED_SRC" ]; then
  EMBED_CONFIG="${EMBED_SRC%.*}.xcconfig"
  [ -f "$EMBED_CONFIG" ] || { echo "Missing embedded build configuration"; exit 1; }
  BUILD_OPTIONS=(-xcconfig "$EMBED_CONFIG")
fi
# Enumerate generated C/assembly only after they exist.
xcodegen generate --spec project.yml --project .

set +e
xcodebuild \
  "${BUILD_OPTIONS[@]}" \
  -project SMOMobile.xcodeproj \
  -scheme SMOMobile \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath Gen/dd \
  IPHONEOS_DEPLOYMENT_TARGET="$DEP" \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build > "$LOG" 2>&1
RC=$?
set -e
tail -40 "$LOG"
[ $RC = 0 ] || { echo "🔴 xcodebuild 失败（完整日志在 ${LOG}）"; exit $RC; }

APP=$(find Gen/dd/Build/Products -maxdepth 3 -name 'SMOMobile.app' -type d | head -1)
[ -n "$APP" ] || { echo "没找到 SMOMobile.app"; exit 1; }
echo "== .app: $APP =="
du -sh "$APP"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist" || true
lipo -info "$APP/SMOMobile" || true

# The private native startup fixture must accompany its embedded guest code.
# Never publish an embedded app that only worked with CI's temporary shader paths.
if [ -f "$EMBED_SRC" ] && [ -z "${SMO_SHADER_ARCHIVE:-}" ]; then
  echo "Embedded device packaging requires SMO_SHADER_ARCHIVE"; exit 1
fi
if [ -n "${SMO_SHADER_ARCHIVE:-}" ]; then
  # SMO_SHADER_EXTRA：额外合并的私有 fixture（计算着色器），空格分隔
  # shellcheck disable=SC2086
  "$PY" "$ROOT/smo/ios/tools/prepare_runtime_shaders.py" "$SMO_SHADER_ARCHIVE" "$APP/RuntimeShaders" ${SMO_SHADER_EXTRA:+--extra $SMO_SHADER_EXTRA}
fi
if [ -f "$EMBED_SRC" ]; then
  "$PY" "$ROOT/smo/ios/tools/check_device_payload.py" "$APP/SMOMobile" "$EMBED_SRC.manifest.tsv"
fi

# 未签名 IPA = Payload/<App>.app 打包成 zip。签名由使用者在自己的机器上做
# （Sideloadly / AltStore + 自己的 Apple ID），与参考项目 docs/NO_XCODE.md 的口径一致。
rm -rf "$OUT/Payload"
mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/"
( cd "$OUT" && zip -qry "SMOMobile-shell.ipa" Payload )
rm -rf "$OUT/Payload"

echo "== 产物 =="
ls -la "$OUT"
echo "== 检查：壳里不许有任何游戏内容 =="
# 与参考项目 shell_build.sh 末尾同样的自我检查：壳只该有自己的代码、图标与几张小表。
"$PY" "$ROOT/smo/verify/check_thin_ipa.py" "$OUT/SMOMobile-shell.ipa" --policy legacy --json "$OUT/thin_ipa_report.json"
echo "thin IPA check passed"
