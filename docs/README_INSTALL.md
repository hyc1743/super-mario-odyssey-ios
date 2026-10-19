# nxnative IPA 构建与安装

使用固定 nxnative 提交 `19d7a70ad18586f6816204c1ad9271a769996a34`。
首版仅支持《超级马里奥 奥德赛》本体加 1.4.1 升级 NSP（v393216）。
安装目标为 iOS/iPadOS 26+；签名与安装由用户使用自己的侧载工具完成。

## GitHub 构建

当前工作流：`.github/workflows/build-shell-ipa.yml`，名称 `build nxnative ipa`。

**两种模式均在公共仓库 `hyc1743/super-mario-odyssey-ios` 的 GitHub-hosted macOS runner 构建。**
私有仓库 `hyc1743/super-mario-odyssey-ios-build` 仅存放 NSP 分片、个人 IPA、资源包和日志，
不启动 Actions，不消耗私有仓库的构建分钟数。工作流在私有仓库中会跳过执行。

| 模式 | 执行位置及触发 | 输出存储 |
| --- | --- | --- |
| shell | 公共仓库：main 提交、PR、tag、手动 | 公开 artifact 中的 `SMOMobile-shell.ipa`，不含游戏程序、着色器、素材或游戏图标 |
| personal | 公共仓库：仅手动选择 personal | 私有仓库 release：`SMOMobile-1.4.1.ipa`、资源分片、还原工具、构建报告 |

个人包保留游戏程序和加载表，以便正常签名执行。素材和编译后着色器不进入任何新个人 IPA。
纯壳只能显示说明与检查资源，无法仅复制 ExeFS 后运行游戏。

维护者首次配置：现有 Secret `SMO_PRIVATE_TOKEN` 需要读取和写入
`hyc1743/super-mario-odyssey-ios-build` 的 release。运行以下命令，将两个本人拥有的 NSP
按 1 GiB 分片上传到该私有仓库，将密钥加密写入当前仓库的 `SMO_PROD_KEYS` Secret：

```powershell
python -m pip install pynacl
python scripts/nxnative_github.py prepare-inputs `
  --base-nsp "<本体.nsp>" --update-nsp "<1.4.1升级档.nsp>" --keys "<prod.keys>"
```

上传工具读取 `SMO_PRIVATE_TOKEN`、`GH_TOKEN` 或 Git Credential Manager 的凭据，不打印密钥。
NSP 分片存放在私有 release `nxnative-inputs-1.4.1`；断点重跑可复用已上传的内容分片。
在公共仓库进入 Actions → `build nxnative ipa` → Run workflow → mode=`personal`。
结果位于私有仓库的 `nxnative-<run id>` release；公开 Actions 不上传个人产物或详细日志。
构建期间公开日志只显示阶段和数量；每 5 分钟将详细日志快照保存到同名私有 release，便于诊断长时间首次着色器编译。

## 安装与复制资源

1. 下载并自行签名安装个人包 `SMOMobile-1.4.1.ipa`，打开一次以建立 Documents。
2. 将同一私有 release 的所有 `SMO-Resources-1.4.1.zip.partNNN`、`resources-parts.json`、
   `restore_nxnative_resources.py`、`package.py` 和 `lock.json` 下载到同一目录。
3. 在该目录执行：

```powershell
python restore_nxnative_resources.py resources-parts.json SMO-Documents
```

也可在源码仓库中运行：

```powershell
python scripts/restore_nxnative_resources.py <下载目录>/resources-parts.json <输出目录>/SMO-Documents
```

工具逐片核对 SHA-256，校验 ZIP 中每个资源，最后写入完成清单。
需要容纳临时 ZIP 和展开资源的磁盘空间。请保留全部分片直到还原成功。

4. 将 `SMO-Documents` **里面的内容**复制进「文件 → 我的 iPhone → SMO Mobile」，不要多套一层目录。
5. 返回应用点“重新检查”。版本、着色器链和文件校验通过后，个人包自动启动游戏。

首次校验会读取所有文件；之后复用与文件大小和修改时间绑定的校验缓存。
应用缺文件或文件损坏时会显示具体路径，重新复制后可再次检查。
升级个人 IPA 后，使用对应 release 的资源包；不混用旧版 v0 资源和着色器。
保持应用包名并保留应用数据覆盖安装；卸载会删除 Documents，操作前自行备份存档。

## macOS 本地构建

需要 Apple Silicon Mac、Xcode 26+、XcodeGen；个人构建另外需要 .NET 10、zstd、spirv-cross
以及 Python `lz4`、`capstone`、`fonttools`。使用独立输出目录：

```bash
python3 scripts/build_nxnative_ipa.py --mode shell --output out/nxnative-shell
python3 scripts/build_nxnative_ipa.py --mode personal \
  --base-nsp '<base.nsp>' --update-nsp '<update.nsp>' --keys '<prod.keys>' \
  --output out/nxnative-personal
```

输出目录的 `work/` 是本机构建缓存，含本人游戏内容，不应公开。
上游源码固定提交；构建会记录实际 Metal/spirv-cross 指纹，重建相应着色器链及配套清单。
`build_report.json` 记录实际源码版本、Build ID、着色器链、IPA 校验结果和哈希；
`shader-toolchain.lock` 保存编译工具指纹。真机测试不由打包成功代替。

## 验证与诊断

```bash
python -m unittest discover -s smo/nxnative/tests -v
python smo/verify/check_thin_ipa.py <shell.ipa> --policy shell
python smo/verify/check_thin_ipa.py <personal.ipa> --policy personal
```

手机日志位于 `Documents/log.txt` 和 `log.prev.txt`；存档位于 `save/`。
`env.txt` 支持 nxnative 参数，例如 `DM_LANG=zh-Hans`。
应用校验完成后固定资源路径，配置文件不会把游戏文件切到未校验目录。
标题、进入关卡、触控/手柄、声音和长时间运行需用户侧载后分别验收。
上游 1.4.1 包含 3 个不能由现有翻译链编译的几何着色器（雷电效果）；构建报告保留成功和失败数量，不将其计为全量着色器通过。
