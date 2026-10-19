# 薄 IPA 安装说明

当前 Guest.framework 和 Metal 资源路径要求 iOS/iPadOS 26.0 或更高版本。

## 1. 安装 IPA

使用 Sideloadly、AltStore 或其他支持自签名的工具安装最终 IPA。只有 shell 调试时才直接安装 `SMOMobile-shell.ipa`；带本地 Guest.framework 的安装包可按下面命令生成。

```bash
python3 smo/ios/tools/package_installable.py \
  --shell-ipa out/SMOMobile-shell.ipa \
  --framework out/smo-phone-package/①放进App安装包/Frameworks/Guest.framework \
  --output out/SMOMobile-installable.ipa
```

也可以省略 `--framework`，脚本会从 `work/rewrite` 生成 Guest.framework：

```bash
python3 smo/ios/tools/package_installable.py \
  --shell-ipa out/SMOMobile-shell.ipa \
  --rewrite work/rewrite \
  --output out/SMOMobile-installable.ipa
```

生成的 IPA 仍然不包含 RomFS/ExeFS；安装后继续复用 Documents 中的现有游戏资源。

如果在 macOS 上从当前资源直接构建，统一入口为：

```bash
python3 smo/tools/build_ipa.py \
  --resources work/game \
  --game-version v0 \
  --output out/ipa \
  --build \
  --installable \
  --rewrite work/rewrite
```

## 2. 首次打开应用

首次启动一次应用，让 iOS 在“文件”App 中创建 `SMOMobile` 目录。

## 3. 复制游戏资源

将当前项目已有的 `ExeFS` 和 `RomFS`，或 `RomFS.smoa.N` 分卷，复制到：

```text
文件 → 我的 iPhone → SMOMobile → SMO Resource/
```

推荐目录结构见 [resource_layout.md](resource_layout.md)。

## 4. 覆盖安装

后续更新只需要覆盖安装新的 IPA。只要侧载工具保留应用数据，Documents 中的游戏资源、存档和日志就不需要重新复制。

## 5. 日志和诊断

日志位于应用 Documents 目录。资源检查、宿主启动、NVN/Metal 和音频诊断会写入 `log.txt`；上一轮日志保存在 `log.prev.txt`。

构建阶段会运行 `smo/verify/check_thin_ipa.py`，检查 IPA 中只有一个 App，并确认没有 `ExeFS`、`RomFS`、NSP/NCA 或原始游戏着色器资源。

`build_report.json` 同时记录游戏 Build ID、ExeFS 模块哈希、RomFS 文件数，以及 App/Guest 的最低 iOS 版本一致性。
