# 准备游戏文件

> 当前 nxnative 构建使用 **v0 本体 NSP＋1.4.1 升级 NSP（v393216）**，通过上游 LibHac 工具合并提取；请勿直接混用下文历史 v0 产物。新的私有输入上传与构建流程见 [README_INSTALL.md](README_INSTALL.md)。下文保留旧运行时的开发记录。

**你必须拥有这个游戏。** 本项目只让你把自己已经买的 Nintendo Switch 版《超级马里奥 奥德赛》
跑在自己的 iPhone 上。本仓库不含任何游戏文件，以后也不会含。不要向别人索要游戏文件或分享游戏文件，
不要在 issue / PR 里贴游戏文件或下载链接。

中文 · English: 见文末

## 需要哪些文件

从你自己 Switch 上 dump 的《超级马里奥 奥德赛》**本体**（base game）。本项目目前的开发与实测都基于：

| 项目 | 值 |
|---|---|
| 标题 ID | `0100000000010000`（US） |
| 版本 | v0（初版，无更新包） |
| 键代 | KeyGeneration 3 |

你需要它的两部分：

| 部分 | 内容 | 大小 |
|---|---|---|
| 程序文件（ExeFS） | `main`、`sdk`、`subsdk0`、`rtld`、`main.npdm` | 约 22 MB |
| 资源（RomFS） | `ObjectData/`、`StageData/`、`ShaderData/`、`SoundData/` … | 约 5.5 GB |

版本要对得上：`main` 的构建号是 `3ca12dfaaf9c82da`。工具会逐项核对，对不上会直接报出来，
而不是悄悄出一个跑不起来的包。

## 从你自己的主机上 dump

用你自己的 Switch、dump 你自己买的那份。常用且长期维护的开源工具是 **nxdumptool**：

<https://github.com/DarkMatterCore/nxdumptool>

dump 时选游戏的 **Program**（NCA），把它的 **ExeFS** 与 **RomFS** 两部分取出来。

## 如果你手上已经是整包（.nsp / .xci）

本项目自带解包工具，不需要额外装 hactool：

```
smo/tools/nsp_extract.py info  <你的游戏包> <你的 prod.keys>              # 先看结构与密钥来源
smo/tools/nsp_extract.py exefs <你的游戏包> <你的 prod.keys> work/game/ExeFS
smo/tools/nsp_extract.py romfs <你的游戏包> <你的 prod.keys> work/game/RomFS
```

`prod.keys` 是从你自己主机上导出的密钥文件（同 nxdumptool 的作者生态，
例如 Lockpick_RCM 之类的工具）。**游戏包与密钥只在你自己的机器上被读取，不会被上传到任何地方。**

解包工具的算法不是猜的：每一步都逐条对照 hactool 的源码实现，出处写在
[`smo/tools/nsp_extract.py`](../smo/tools/nsp_extract.py) 的文件头注释里。

## 放到哪里

工作区默认是仓库里的 `work/`：

```
work/game/ExeFS/{main,sdk,subsdk0,rtld,main.npdm}
work/game/RomFS/{ObjectData,StageData,ShaderData,…}
```

把游戏文件放到 iPhone 上时，与参考项目一致：把 `ExeFS` 与 `RomFS` 两个目录拷进 App 自己的目录
（用「文件」App > 我的 iPhone > App 名，或 Finder 里拖到 App 上）。App 启动时会检查并列出找到了什么。

## 为什么是 Switch 版而不是别的版本

iPhone 与 Switch 是同一类处理器。Switch 版的程序几乎可以一个字节不改地在 iPhone 上执行，
这是能做到流畅的前提；PC 版是给另一种处理器编的，做不到这一点。两版的游戏数据也不通用
（纹理、界面美术、音频格式都不一样）。

## Why the Switch release and not the PC release

iPhone and Switch use the same class of processor. Almost all of the Switch release's program can run
on an iPhone without changing a single byte, which is what makes smooth play possible; the PC release
is built for a different kind of processor and cannot do that. The game data is not interchangeable
either: textures, interface art and audio use different formats in the two releases.

## 自签工具用户的流程（本地一条命令；这是**推荐**流程）

    python smo/ios/tools/make_installable.py out
    → out/SMOMobile-<版本>.ipa（壳 + 本机 Guest.framework 注入完成）

1. 首次：`prepare_phone_package.py` 生成 Guest.framework 与手机资源包（一次性）
2. 每次更新：`make_installable.py` → 自签工具签名 → **覆盖安装**（手机上的 RomFS/ExeFS 保留）
3. 游戏程序（改写产物）没变就不用重跑第 1 步 —— Guest.framework 复用

（下面的私有 fork + GUEST_URL 注入是备选：适合想让 release 自带游戏程序的用户。）

## 备选：私有 fork 注入（release IPA 直接自带游戏程序）

目标：release 产物就是**可直接自签安装的 IPA**（已含 Guest.framework），游戏资源固定在手机里，
每次更新 = 下载 → 自签 → 覆盖安装。做法与参考项目 d2r-mobile-build 一致（私有 fork + 外部 URL 注入）：

1. **建一个私有 fork**（GitHub → Fork → 设为 Private；公共仓不进游戏内容，注入只在你的私有仓发生）
2. 本机生成 guest.zip 与校验值：
   `python smo/ios/tools/prepare_phone_package.py --guest-zip out/guest.zip`
3. 把 `out/guest.zip` 上传到任意有直链的地方（网盘 / 自有服务器 / IPFS）
4. 私有 fork 的 Settings → Secrets and variables → Actions → **Variables**：
   - `GUEST_URL` = guest.zip 的直链
   - `GUEST_SHA256` = 脚本打印的 sha256（只有改写产物变了才需要重新生成与更新）
5. 打 tag（如 v0.4.0）→ CI 下载校验注入 → **release 的 IPA 已含游戏程序** → 下载 → 你的自签工具签名 → 覆盖安装
   （覆盖安装保留 App 沙盒：手机上的 ExeFS/RomFS 不用重拷；游戏资源固定不动）

首跑仍需一次性：装 App（打开一次出现 SMOMobile 文件夹）→ 把 RomFS + ExeFS 拷进该文件夹。
