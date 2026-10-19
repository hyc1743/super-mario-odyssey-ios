# Super Mario Odyssey → iOS 移植 · 状态与计划

**目标**：把 Switch 版《超级马里奥 奥德赛》移植到 iPhone（iPhone 17 Pro Max / iOS 26 起），
技术路径**完全照搬参考项目 [jhaizhou-ops/d2r-mobile](https://github.com/jhaizhou-ops/d2r-mobile)**：
不是模拟器，而是「Horizon 兼容层 + AArch64 原生执行」——游戏的 aarch64 程序直接在手机上跑，
只把「不能在苹果内核上原样执行的少量指令」改写掉，再自己实现它依赖的 Switch 系统服务与图形接口。

本文件记录**做到哪一步、依据是什么、下一步做什么**。所有结论都带可复现的命令与实测输出，
不含推测。

---

## 进度总表（随轮次更新；逐轮的实测记录在下面）

| 部件 | 状态 | 证据（可复现） |
|---|---|---|
| 解包 NSP → ExeFS / RomFS | ✅ | 4636 文件 / 5.2 GB；算法逐条对照 hactool |
| 侦察（构建号 / import / 图形入口 / NVN 名字） | ✅ | 700 个 import 里图形只有 `nvnBootstrapLoader`；469 个 NVN 名字 |
| 程序改写 4 个 NSO | ✅ 结构 + **动态等价** | Unicorn：svc 106/106、cntpct 29/29、rtld 4/4（`make -C smo/host equiv`） |
| 着色器 18470 个（SPIR-V + MSL） | ✅ 0 失败 | `sharcb.py` + `dmsh_xlate`；`glsl_facts.py` 证明翻译缺省值正确 |
| 着色器桥（运行时 → 已译） | ✅ | 真实 blob 400/400 命中（FNV-1a 64 键两边一致） |
| 宿主装载器 | ✅ 真实产物跑通 | JUMP_SLOT 639 == PLT 桩 639；宿主 import 12/4 == import_graph 12/4 |
| 内核 svc：内存族 / 线程族 | ✅ 20 + 15 断言 | `hle_svc.c` / `hle_thread.c`（真并发） |
| 服务 HLE：fs / oe / hid | ✅ 30 + 24 断言 | `hle_fs.c` / `hle_oe.c` / `hle_hid.c`；447 条接管清单 |
| NVN 接口层 469 个名字 | ✅ | `nvnLoadCProcs` → 461 个名字的机制已挖清（第十四轮） |
| NVN 核心状态层 38 个实现 | ✅ 38 断言 | `nvn_core.c` / `nvn_state.c`（不写客体对象内存） |
| 重放记账 + 管线键 | ✅ 16 断言 | `nvn_replay.c`（不含 Metal，用空后端测） |
| 纹理块线性布局（尺寸 + 解交错） | ✅ 36 断言 + **真实贴图 123/123 对上** | `nvn_tex.c`（尺寸移植自 deko3d）；`tex_layout_check.py` 对 BNTX 记录逐张核对（第十九轮） |
| 验证层 `smo/verify/` | ✅ 通过 12 · 跳过 2 | `regress.sh` 一条命令；NVN 不透明性 1012/1706 调用点 0 反例（第十八轮） |
| 纹理内容核对 | ✅ 1294 张真实贴图 0 不一致 | `tex_content_check.py`：解交错逐字节 + 解码端点逐字节/插值 ≤1（第二十三轮） |
| **Metal 重放（CI 离屏可验的部分）** | ✅ 清屏 / 着色器管线 / 纹理往返 / 管线缓存 / 合龙点 | `nvn_mtl.m` + `mtl_selftest` + `mtl_replay_selftest`（第二十二～二十五轮） |
| **Metal 重放（真机呈现）** | ❌ | 需真机：`CAMetalLayer`、GPU 可见内存、性能 |
| 内嵌装载（三段签名段 → 连续映像） | ✅ CI 可验 | `dm_embed_map`（vm_alloc/vm_remap）+ `embed_selftest` 分段 1–6（第二十四轮） |
| 壳模式（Guest.framework dlopen → remap） | ✅ CI 编译 + 本机生成验证 | `dm_image_from_dylib` + `guest_dylib.py`（第二十六轮） |
| App（宿主接入 / 日志上屏 / 导出日志 / 文件共享） | ✅ CI 编译验证 | `main.m`（RunHost + RecentLog + 导出按钮 + 一键展开）；v0.3.0 起文件 App 可见（第二十六轮） |
| 资源容器（几千小文件 → 若干卷 + App 首次展开） | ✅ 展开器 6 断言 + 真产物打卷 | `smoarc.c`；`RomFS.smoa.0…5`（每卷 ≤1 GB，共 4636 文件）（第二十七轮） |
| 出包 / 更新链路 | ✅ release v0.1.0–v0.6.12 | `make_installable.py` 一条命令：下载壳 → 注入 Guest.framework → 出 `SMOMobile-<版本>-可安装.ipa`（第二十六轮）；v0.5.0 起内嵌版由公开 runner 构建 |
| **公开 runner 出内嵌版**（私有仓计费被挡后的替代） | ✅ 端到端验证 | 公开仓免费 runner 构建：输入从私有仓 `embed-input` 分支拉、成品传私有仓 release；内容不落公开侧（第二十六轮 2.104–2.109） |
| 触屏 / 手柄 | 🚧 | 状态层与布局已验证（hid / oe），前端未接 |

**能不能玩：现在还不能。** 缺的是 Metal 重放那一半与 iOS 内嵌装载分支（两者都需要 macOS / 真机）。

---

## 项目计划 v2（2026-10 更新；结合 A–E 阶段计划与「到实机可玩」的里程碑视角）

### 一、里程碑（到「实机跑起来」）

| # | 里程碑 | 交付物 | 验证方式 | 规模估计 | 状态 |
|---|---|---|---|---|---|
| **M0** | **客体侧就绪**（不做图形也能证明的部分） | 改写（含动态等价）、装载器、内核 svc、fs/oe/hid、NVN 接口层、核心状态层、着色器全译 18470、纹理整链、重放记账、三段内嵌出包 | 本机 12 个 C 单测 + Unicorn 等价（svc 106/106、cntpct 29/29）+ 1235 张真实贴图内容核对 + CI 双绿 | ~19 万字节 | ✅ **完成** |
| **M1** | **能装、能启、日志上屏**（无图形） | `loader_apple.c` 的 iOS 分支（vm_allocate + 三段 mach_vm_remap）、`-segprot` 接 Xcode、App 内日志上屏 + RomFS 从「文件」导入、初始化路径所需服务（settings/applet/am 等） | macOS 分支可在 CI 跑；启动与日志需真机 | ~1–2k 行 | ⬜ 下一步 |
| **M2** | **第一帧**（清屏 + 一个 draw） | `nvn_mtl` 第一片：MTLDevice/CAMetalLayer/队列、Begin/EndRecording→计划项→EndRecording→Present、同步；**iOS 上 GPU 可见内存的取法**（客体地址不能直接给 GPU） | 离屏部分 CI 可验（阈值：回读像素）；呈现与内存必须真机 | ~1–3k 行 | ⬜ |
| **M3** | **标题画面能画出来** | `nvn_mtl` 主体：管线按键缓存、渲染/深度/混合状态翻译、顶点布局、纹理上传与格式映射、资源生命周期；控制段布局钉死；句柄类接口补齐 | 离屏回读 + 与 CPU 路径逐像素比（本机/CI）；画面需真机 | **~8–20k 行**（最大一块） | ⬜ |
| **M4** | **能玩** | 输入（触屏→已有 hid/oe 状态层）、音频（audio 家族里真正被调用的部分）、446 个服务按真机 UNIMPL 日志逐族补、性能（纹理常驻/拷贝策略） | 真机逐轮；参考项目的致谢显示「最后一公里」很长（社区修了多个渲染问题） | 开放量级 | ⬜ |

### 二、与参考项目的规模对照（量尺）

只比**基础设施类**（排除参考项目的游戏专属逻辑 `dm_cursor/dm_rift/dm_world` 等 —— 那些是 D2R 专属，我们不需要）：

| 部件 | 参考项目（已完成） | 我们 | 粗略完成度 |
|---|---|---|---|
| 图形层 `gfx/` | 1.21 MB（`nvn_mtl.m` 627 KB、`hle_nvn.c` 113 KB、`nvn_tex.c` 8 KB） | 193 KB | ~15%（Metal 那一半 0） |
| 宿主服务 `host/hle_*.c` | 27 文件 / 467 KB | 289 KB（多为生成的接管桩；手写 fs/oe/hid） | ~20% |
| iOS App `ios/` | 805 KB / 40 文件 | 10.6 KB | ~2% |

**我们独有的一项杠杆**：18470 个着色器已离线译成 MSL —— 参考项目走的是给 D2R **重写渲染器**的路子，不存在这一步；我们走「重放」，理论上比手写渲染器可自动化得多。

### 三、当前在制品与未决项

1. **A4 收尾（未决）**：实测游戏只有 6 种贴图格式 —— BC1/BC3/BC4/BC5 ✅、ASTC_4x4 ✅（53 张逐字节）、**RGBA8 有 6 张解交错与判据不一致**。
   已定位到一半：TRM 的 `getAddrBlockLinear` 与我们的映射**逐 texel 完全一致**（含差异 texel），所以问题在 C 侧未压缩路径的参数/循环，不在公式。影响面 0.9%。
2. **控制段确切布局（等真机）**：`nvnProgramSetShaders` 已在打印头 16 字节与大小，真机日志一到即可钉死；现在用「归档槽布局 + 滑动扫描」兜着。
3. **A–E 阶段计划的对齐**：A 只剩上面第 1 点；B（Metal 骨架 + CI 离屏像素）与 M2/M3 是同一件事；C（内嵌装载/呈现）与 M1/M2 重叠；D（真机自检 + 首跑）与 M1 后半段重叠；E 即 M4。

### 四、按「在哪能验」分工（决定推进顺序的硬约束）

| 能在哪验 | 内容 |
|---|---|
| **本机（Windows）** | 一切平台无关逻辑：纹理/着色器/重放记账/管线键、服务单测、Unicorn 等价性、内嵌三段的拼回校验、内容核对（真实贴图） |
| **CI（macOS runner，有可用 Metal：Apple Paravirtual）** | 宿主与 Metal 代码的**编译**、离屏渲染 + 回读像素断言、macOS 侧的装载分支、出未签名 IPA |
| **只能在你的 iPhone** | App 安装（Sideloadly）、`CAMetalLayer` 呈现、GPU 内存可见性、音频、触屏手感、性能、UNIMPL 日志 |

### 五、下一步顺序（短列表）

1. 修掉 A4 那 6 张 RGBA8（小，且能让纹理层彻底关闭）
2. **M1**：`loader_apple.c` iOS 分支（CI 可验）+ `-segprot` 接链接 + App 日志上屏与 RomFS 导入
3. **M2**：`nvn_mtl` 第一片 + CI 离屏像素测试（这是 Metal 层的第一块真代码）
4. 之后按 M3 → M4；每完成一块都保持「commit + push + CI 双绿 + 证据进 STATUS」

### 六、需要你决策/参与的点

- **真机环节**：M1 之后需要你装一次（Sideloadly，Windows，你自己的 Apple ID，免费 7 天）并把屏幕日志/截图发回 —— 这是唯一必须你参与的地方
- **优先级**：先做 M1（能启动、日志上屏，快的可见成果）还是先把 M2/M3 的 Metal 骨架在 CI 上搭起来（慢但直指画面）？我倾向先 M1（能拿到真机日志，后面每个决策都有依据）


---

## 一、参考项目的技术路径（先看清楚再动手）

参考项目 `dm/` 的结构与分工：

| 部件 | 参考项目位置 | 做什么 |
|---|---|---|
| 程序改写器 | `dm/tools/patch_nso.py` | 离线改写 NSO：`x18`/`tpidr_el0` 读写 → 线程槽；`svc`、`mrs cntpct_el0` → 宿主门 |
| 宿主 | `dm/host/` | 加载器（多模块映射、跨模块重定位、import 解析）+ Horizon 内核 svc + 系统服务 HLE |
| 图形 | `dm/gfx/` | NVN（523 个函数）→ Metal 重放；Maxwell 着色器离线翻译成 MSL |
| iOS 壳 | `dm/ios/` | App、触屏、界面 |
| 验证 | `dm/verify/` | 改写等价性（Unicorn）、逐拍对拍、截图闸门 |

关键前提（参考项目文档原话）：**「main 只 import 一个图形入口 `nvnBootstrapLoader`，宿主强制接管它，
SDK 里 NVN 驱动的指令一条都不执行」**。下面的侦察就是验证 SMO 是否也满足这条前提。

---

## 二、已完成（每一步都有实测证据）

### 2.1 环境

本机是 Windows 10（无 Mac、无 Xcode）。已就位：

| 项 | 位置 | 状态 |
|---|---|---|
| Python 3.12.10 | `%LOCALAPPDATA%\Programs\Python\Python312` | ✅ 含 pillow numpy lz4 capstone unicorn pycryptodome |
| LLVM/clang 23.1.3 | `C:/toolchain/llvm/LLVM/bin` | ✅ clang / llvm-objcopy … |
| mingw-w64 GCC 16.2.0 | `C:/toolchain/mingw64/bin` | ✅ g++（Windows 上唯一可用的完整 C/C++ 链接环境） |
| CMake 3.31.6 / Ninja 1.12.1 | `C:/toolchain/cmake/bin`、`C:/toolchain/ninja` | ✅ |
| .NET SDK 8.0.404 | `C:/toolchain/dotnet` | ✅ 编参考项目的着色器翻译器要用 |
| **SPIRV-Cross 1.4.357.0** | `C:/toolchain/spirv-cross/bin/spirv-cross.exe` | ✅ **本机源码编译**（vulkan-sdk-1.4.357.0，参考项目验证过的版本；换版本着色器翻译结果会变） |
| 参考项目源码 | `C:/tmp/d2r-mobile` | ✅ 对照用 |
| hactool 源码 | `C:/tmp/hactool` | ✅ 作为 NCA 解密算法的**权威对照**，不用于构建 |

### 2.1.1 开发闭环的硬约束（必须早说清楚）

参考项目是在 **Apple 芯片的 Mac** 上开发的：宿主与图形层直接在那台 Mac 上编、跑、看画面。
本机是 Windows x86-64，而**客体代码是 aarch64**，因此：

- **不能在 Windows 上原生执行游戏程序**（同一条路走不通的原因不是改写器，而是 CPU 架构）。
- 能用的三种验证方式，按可信度排序：
  1. **真机 iPhone + xtool**：把宿主编成 iOS App 装上去，靠日志迭代。最真实，但每轮要出包+装机（参考项目的 NO_XCODE 路线就是这么做的，已在 Windows 上端到端验证过）。
  2. **Mac**（若有）：与参考项目完全一致的最快闭环。
  3. **本机 Unicorn 解译**：`unicorn` 已装，参考项目也用它做改写等价性验证；可以拿它做「改写块行为等价」与「HLE 逻辑」的单元级验证（这是它原本的用途），但不适合整游戏跑。

所以后面的推进方式会是：**能在本机验证的（改写等价性、HLE 单元、着色器翻译、资源生成）在本机做；
整机行为只能在真机上看日志。**

### 2.2 游戏文件解包（自己写的，等价于参考项目的 hactool 那一步）

`hactool` 依赖 mbedtls，Windows 上从源码构建风险高，因此按 hactool 源码**逐条对照**写了
`smo/tools/nsp_extract.py`（算法出处写在文件头注释里，每条都指到 hactool 的具体函数）：

```
NCA 头 XTS      nca.c nca_decrypt_header()      aes_xtls_decrypt(header_key, 0xC00, sector=0, 0x200)
XTS tweak       aes.c get_tweak()               sector 按大端写进 16 字节 tweak
XTS 单元        mbedtls_aes_crypt_xts()         T0=AES_enc(tweak_key,iv)，逐块 gf128mul_x_ble
gf128mul        mbedtls/library/gf128mul.c      两个小端 u64，溢出异或 0x87
密钥区          nca.c nca_decrypt_key_area()    AES-128-ECB(key_area_key_application[ct], 0x40)
内容密钥        nca.c:462                       带 rights_id：AES-128-ECB-Dec(titlekek[ct], ticket 标题密钥)
                nca.c:534                       不带 rights_id：密钥区第 3 项
CTR             nca.c:493                       ctr[0..7]=反转(section_ctr)，ctr[8..15]=大端(sec_off>>4)
分区偏移        utils.h media_to_real()         media_start_offset * 0x200
PFS0 位置       nca.c:1000                      段起点 + 超级块 pfs0_offset
RomFS 数据层    nca.c nca_process_ivfc_section() 固定第 IVFC_MAX_LEVEL-1 = 5 层
```

实测结果（SMO US v0，标题 `0100000000010000`）：

```
Program NCA 0f26bd42cae0e4cefda4b5bbf7ae3d50  5,539,168,256 B  rights_id=01000000000100000000000000000003
  内容密钥 = AES-128-ECB-Dec(titlekek_02, tik[0x180:0x190])      ← 穷举全部 16 字节对齐偏移 + 两种取法，
                                                                  用「段内 PFS0 偏移处解得 PFS0 magic」做判据
  段0 = ExeFS（PFS0, CTR）  段1 = RomFS（IVFC, CTR, 5.5 GB）  段2 = logo（PFS0, 不加密）
```

**ExeFS（`work/game/ExeFS/`）**：

| 文件 | 大小 | 格式 | 构建号 |
|---|---|---|---|
| `main` | 15,388,240 B | NSO0 | `3ca12dfaaf9c82da` |
| `sdk` | 4,179,745 B | NSO0 | `ae34e75d02925f44` |
| `subsdk0` | 3,175,954 B | NSO0 | `798c30e126697f22` |
| `rtld` | 7,099 B | NSO0 | `a75512be30bb2a8c` |
| `main.npdm` | 1,476 B | META | — |

**RomFS（`work/game/RomFS/`）**：4636 个文件 / 5.50 GB。顶层目录：
`EffectData EventData LayoutData LocalizedData MovieData ObjectData ShaderData SoundData StageData SystemData`

### 2.3 模块侦察（决定移植可行性的关键事实）

`smo/tools/nso_info.py`（NSO 解压 + MOD0/动态段/符号表）、`smo/tools/import_graph.py`（解析图）、
`smo/tools/xref.py`（import ← PLT 桩 ← bl 调用点）。

| 事实 | 证据 |
|---|---|
| **`main` 只 import 一个图形入口 `nvnBootstrapLoader`** | `main` 的 700 个 import 里，图形相关只有它一条；调用点 3 处（`0x731288 / 0x731298 / 0xae9d5c`）。**与参考项目的核心前提一致** |
| 游戏通过该入口按名字取 NVN 函数 | `main.bin` 里有 **469** 个不同的 `nvn*` 名字字符串（参考项目是 523） |
| `glslc*`（Nintendo 的 GLSL 编译器）**零调用点** | 8 个 `glslc*` 是无人导出的死 import，`xref.py` 查不到任何 bl 调用点 ⇒ **着色器是预编译的 Maxwell 二进制**，可以离线翻译 |
| 引擎是 **agl + sead** | `main.bin` 字符串：`agl::TextureSampler / RenderDisplay / WorkHeap / lght …`、`sead::ThreadMgr / ResourceMgr / FileDeviceMgr …` |
| 着色器在 RomFS | `RomFS/ShaderData/` 27 个 `al*.szs`（Yaz0 + SARC，`al` = agl） |
| `main`/`subsdk0` **没有裸 `svc`** | 系统调用全走 `sdk` 里的 nn::os 包装；`sdk` 有 106 处 svc、29 处 `cntpct_el0` |

`main` 的 import 分布（这是宿主 HLE 的工作面）：

```
nn::audio 92  nn::os 71  nn::hid 48  nn::socket 28  nn::util 26  nn::fontll 24
nn::fs 21  nn::oe 20  nn::account 19  nn::diag 14  nn::nfp 13  nn::nifm 9
nn::time 8  nn::mem 8  nn::web 8  nn::crypto 7  nn::friends 6  nn::vi 6
nn::prepo 5  nn::image 5  nn::ssl 4  nn::pl 3  nn::lmem 3  nn::settings 2
```

模块间解析图：

| 模块 | 符号 | import | export | 无人导出（必须宿主提供） |
|---|---|---|---|---|
| `main` | 91,231 | 700 | 90,530 | 12（含 8 个 `glslc*` 死引用） |
| `subsdk0` | 11,388 | 609 | 10,776 | 4 |
| `sdk` | 19,866 | 13 | 19,850 | 5 |
| `rtld` | 22 | 19 | 0 | 16（`__rel_dyn_*` 等装载器符号） |

> 注意：**「sdk 导出了 `nn::fs::OpenFile`」不等于宿主可以不管它**。参考项目的做法是对服务层
> `nn::` 用 `HLE_FORCE` **强制接管**（因为 SDK 的客户端实现要走 IPC，而宿主里没有服务进程）。
> 所以真正的 HLE 清单是「游戏实际调用的服务层函数」，比上表大得多。

### 2.4 程序改写器（移植 + 扩展，四个模块全部通过）

`smo/tools/patch_nso.py`（由 `smo/tools/port_rewriter.py` 从参考项目生成：只搬运通用机制，
去掉其 D2R 专属的 CUTS / OBS / PARAMS / touch-run-v4 规则表），新增了 SMO 需要的跳转表形状。

**为什么需要新增**：参考项目认的是 D2R 编译器生成的形状

```
adr x18, table ; ldrb w?, [x18, idx] ; add x18, x18, w?, lsl #2 ; br x18
```

而 SMO 的 `sdk`/`subsdk0` 里是（`xB` 由 adrp+add 变成常量，表里存 **4 字节有符号偏移**）

```
ldrsw xR, [xB, xIdx, lsl #2] ; add x18, xR, xB ; br x18        共 6 处（sdk 2 / subsdk0 4）
```

`main` 恰好没有这种表（所以 `main` 一次就过）。新增的处理：改写期把整张表读出来（表在 rodata 是常量），
把 `br x18` 换成「按槽 K18 里的目标值分发」的比较链，每条目标一个直接分支垫片，
到目标前恢复借用的 `x16/x17`——**任何寄存器都不会带着被改过的值到达目标**，表本身也不动。
兜底是 `brk #0x180`（原版有 `b.hi` 越界守卫，理论不可达；真到了要响亮地崩）。

实测（`smo/tools/patch_nso.py <NSO> work/rewrite <模块名>`）：

| 模块 | 改写统计 | 补丁大小 | 宿主门 |
|---|---|---|---|
| `main` | plain 2127 · cond 33 · pcrel 6 · window 2 | 86,864 B | 0 |
| `sdk` | plain 6286 · cond 87 · pcrel 30 · **jt_smo 2** · svc 106 · cntpct 29 · tpidr 50 · window 7 | 264,380 B | 135 |
| `subsdk0` | plain 6699 · cond 174 · pcrel 23 · **jt_smo 4** | 279,484 B | 0 |
| `rtld` | plain 3 · pcrel 1 · svc 4 | 316 B | 4 |

改写机制（照搬参考项目）：**运行时绝不改客体代码**。补丁块放在映像尾部，键页（只读）告诉它用哪个线程槽；
每个改写点原址换成一条 `b 补丁块`。所以游戏代码在装载时就是「只读+可执行」的，符合 iOS 的要求。

**结构自检**（`smo/tools/rewrite_check.py`，参考项目 `verify/structck.py` 的等价物）——全部通过：

```
main     映像 0x025c5350 改写点 2166（+窗口 2）        门 0                            补丁区 0x25b0000..  OK
rtld     映像 0x0001013c 改写点 8                     门 4 {svc:4}                    补丁区 0x10000..    OK
sdk      映像 0x00a608bc 改写点 6594（+窗口 7）        门 135 {svc:106, cntpct:29}     补丁区 0xa20000..   OK
subsdk0  映像 0x007043bc 改写点 6900                    门 0                            补丁区 0x6c0000..   OK
```

检查项：每个改写点确实是 `b` 且目标落在补丁区；每个宿主门的返回地址落在补丁区；键页区全 0（由装载器运行时填）。

6 张跳转表读出结果（`work/rewrite/*.jt.tsv`）：

```
sdk      0x3ea2c  表 0x73ab0c  4 项    0x3ea30 0x3ea4c 0x3ea84 0x3eadc
sdk      0x6f1dc  表 0x741928  4 项    0x6f224 0x6f1e0 0x6f1f0 0x6f238
subsdk0  0x1a77fc 表 0x4a8f30  25 项   …
subsdk0  0x1a8884 表 0x4a9388  27 项   …
subsdk0  0x1aae0c 表 0x4a9bd8  25 项   …
subsdk0  0x1abea8 表 0x4aa030  27 项   …
```

（共 6 处，与逐条反汇编找到的 `br x18` 处数一致；目标全部落在 .text 内。）

---

## 三、下一步（按依赖顺序）

| # | 任务 | 说明 | 依赖 |
|---|---|---|---|
| 1 | **着色器翻译链** | `ShaderData/*.szs` = Yaz0→SARC→agl 着色器程序（Maxwell SASS）。复用参考项目的 `gfx/tools/dmsh_*`（Ryujinx 解码器 → SPIR-V → spirv-cross → MSL）。需要先写 SARC 解包与 agl 程序格式解析 | LLVM/spirv-cross/.NET 安装 |
| 2 | **宿主加载器** | 移植 `host/loader.c` + `entry.S` + `thread.c`：多模块映射、线程槽、键页、跨模块重定位、按名解析 import | 改写器产物 |
| 3 | **svc + SDK 层 HLE** | `sdk` 有 106 处 svc（线程/内存/同步/时钟）+ 29 处 `cntpct`。nn::os 本身可以原样跑，只要内核层被替换 | #2 |
| 4 | **服务层 HLE（工作量最大）** | 按 `main` 实际调用的服务函数逐族实现：fs / hid / oe / account / vi / **audio(Audren 92 项)** / nifm / nfp / settings / socket / ssl / crypto / diag / prepo / web / image / pl / lmem / fontll | #3 |
| 5 | **NVN → Metal** | 469 个名字的宿主函数表 + 命令记录/重放（参考项目 `gfx/nvn/` 的 `hle_nvn.c` + `nvn_mtl.m`，203 个 NVN 函数已实现，可大量复用） | #1 #2 |
| 6 | **触屏/手柄输入** | 参考项目的触屏方案是重建的；SMO 是 3D 平台跳跃，摇杆+按键映射要重新设计 | #4 |
| 7 | **iOS App + IPA** | 需要 WSL2 + Swift 工具链 + **Xcode.xip（你的 Apple ID）** 供 xtool 生成 iOS SDK | 全部 |

**已知的外部依赖（需要你出面）**：WSL2 安装（管理员+重启）、Xcode.xip（8–10 GB，Apple ID 登录）、
Apple 账号类型（免费个人号签不了内存上限/扩展虚拟寻址两个 entitlement）。

---

## 四、本仓目录

```
Super Mario Odyssey [0100000000010000][US][v0].nsp   你提供的游戏包
ProdKeys.NET-v22.5.0/{prod.keys,title.keys}          你提供的密钥
smo/tools/nsp_extract.py     NSP/NCA 解密与提取（等价于 hactool）
smo/tools/nso_info.py        NSO 解压 + 动态段/符号表/import/export
smo/tools/import_graph.py    模块解析图（谁导出、谁必须宿主 HLE）
smo/tools/xref.py            import ← PLT 桩 ← bl 调用点
smo/tools/patch_nso.py       SMO 版 NSO 改写器（通用机制 + SMO 跳转表形状）
smo/tools/port_rewriter.py   从参考项目生成 patch_nso.py 的装配脚本
smo/verify/regress.sh        回归总入口（对应参考项目 dm/verify/regress.sh）
smo/verify/nvn_opaque_check.py     核验「客体不裸读 NVN 对象字段」这条设计前提
smo/verify/nvn_opaque_selftest.py  上面那个检查器自己的自检（16 条断言，进 CI）
work/game/ExeFS/             解出的 4 个 NSO + npdm
work/game/RomFS/             解出的 5.2 GB 游戏资源
work/game/*.bin              摊平的模块映像（分析用）
work/rewrite/                改写产物（*.patched.bin / *.sites.tsv / *.gates.tsv …）
work/logs/                   运行日志
```

## 五、复现命令

```bash
PY=%LOCALAPPDATA%/Programs/Python/Python312/python.exe
NSP="Super Mario Odyssey [0100000000010000][US][v0].nsp"
K=ProdKeys.NET-v22.5.0/prod.keys

$PY smo/tools/nsp_extract.py info  "$NSP" "$K"                    # 看 NCA 结构与密钥来源
$PY smo/tools/nsp_extract.py exefs "$NSP" "$K" work/game/ExeFS    # 解出 4 个 NSO
$PY smo/tools/nsp_extract.py romfs "$NSP" "$K" work/game/RomFS    # 解出 5.2 GB 资源
$PY smo/tools/nso_info.py work/game/ExeFS/main --dump work/game/main.bin --group
$PY smo/tools/import_graph.py work/game/ExeFS work/game/import_graph.tsv
$PY smo/tools/xref.py main --who nvnBootstrapLoader glslc
$PY smo/tools/patch_nso.py work/game/ExeFS/main work/rewrite main
```

---

# 第二轮：着色器链起步 + 云端出包 + 仓库骨架

## 2.5 着色器解包（Yaz0 → SARC → sharc）

`smo/tools/nintendo_archives.py` 实现了 Nintendo 归档格式的读写。这三样**离线与宿主都要用**
（宿主运行时要解 romfs 里的 `.szs`，所以这份实现之后要照抄成 C）。

实测：`RomFS/ShaderData/` 27 个 `.szs` **全部解开**，每个里面是 `*.sharc` / `*.sharcb` / `*.bfsha`
—— 即 **agl 的 ShaderArchive**（`sharc` = shader archive），着色器程序的容器。

| 例子 | 压缩 → 解压 | 内含 |
|---|---|---|
| `alReducedShader.szs` | 4,993 → 49,152 | `alReducedShader.sharc` |
| `alDeferredShading.szs` | 944,193 → 2,859,008 | `alDeferredShading.sharc` |
| `alRenderMaterial.szs` | 22,466,853 → 81,172,560 | `alRenderMaterialUber.bfsha` |
| 合计 27 个 | 29.6 MB → 约 128 MB | — |

**两次踩坑都留下了证据（都在文件注释里）：**

1. **Yaz0 的位域语义**：按「标准文字描述」手推的实现自相矛盾 —— 第一个 code 字节 `0xFF` 解出的
   8 个字面量恰好是 SARC 头 `SARC\x14\x00\xff\xfe`，紧接着的回引用却越界。于是拿公开实现
   `Cuyler36/Yaz0Decoder` 对照，改正为：**code 字节只提供标志位；长度高 4 位与距离的高 4 位
   都在回引用的第一个字节里**（`b1>>4` 是长度减 2，`b1&0xF` 与 `b2` 组成距离-1）。
2. **SARC 头字段偏移**：`file_size`/`data_offset` 我原先从 `0x0C` 起读，实际应从 `0x08` 起
   （`0x04` 头长 / `0x06` BOM / `0x08` file_size / `0x0C` data_offset）。这个 bug 让所有归档的
   数据偏移整体错 4 字节 —— **是自检（`selftest.py`）抓出来的**，正好说明自检值得写。

## 2.6 自检（不需要游戏文件）

`smo/tools/selftest.py`，CI 每次都会跑：

| 组 | 覆盖 |
|---|---|
| 1. Yaz0 | 全字面量流、回引用流（自造压缩流，不依赖游戏文件） |
| 2. SARC | 自造两文件归档，校验名字/偏移/数据 |
| 3. NSO 头 | 自造 NSO0，校验段布局与构建号 |
| 4. **改写器端到端** | 自造合成 NSO（含 `svc` / `mrs tpidr_el0` / `x18` 读写 / **SMO 形状跳转表** + MOD0 + eh_frame_hdr），跑 `patch_nso.py`，再跑 `rewrite_check.py` 校验产物结构 |

第 4 组把「改写器没坏」变成 CI 每次都能证明的事，而且不需要游戏文件。造合成 NSO 的过程中又暴露了两个
小坑（都记在 selftest 注释里）：`adrp` 的立即数相对**指令所在页**；`sub` 的立即数形式是 `0x51xxxxxx`
而不是寄存器形式的 `0x4Bxxxxxx`。

## 2.7 云端出包（不需要 Mac）

`.github/workflows/build-shell-ipa.yml`：GitHub 的 **macOS runner 自带 Xcode**，正好补上本项目
缺的那台 Mac。两个 job：

- `selftest`（ubuntu）：`pip install -r requirements.txt` + `selftest.py`
- `shell-ipa`（macos）：`brew install xcodegen` → `smo/ios/shell_build.sh` → 产出**未签名 IPA**
  作为 artifact；打 `v*` tag 时自动挂到 Release

签名与装机交给使用者（Sideloadly / AltStore + 自己的 Apple ID），与参考项目 `docs/NO_XCODE.md` 一致。
壳自己也会做内容检查：一旦包内出现游戏内容文件名就中止出包。

**注意**：这一版出的是**空壳**（没有宿主、没有图形层），装上去只会看到一个状态页 —— 页面上会列出移植
进度并检查游戏文件在不在。这是故意这样做的：先把出包链路跑通并稳定下来，避免「装上去什么都不显示、
你以为坏了」。

## 2.8 仓库骨架

对齐参考项目的口径：MIT、双语 README、`docs/GAME_FILES.md`（游戏文件怎么准备）、
`docs/DERIVED.md`（仓库里有哪些与游戏有关的事实、没有哪些内容）、`CONTRIBUTING.md`。
`.gitignore` 主动排除游戏包、密钥、解包产物、`*.sharc` / `*.szs` / `*.patched.bin` 等，
提交前核对过：**26 个文件、全部是本项目自己的代码与文档，无任何游戏内容。**

## 2.9 下一步（按依赖顺序）

| # | 任务 | 具体做什么 |
|---|---|---|
| 1 | **解析 `sharc`（agl ShaderArchive）** | 从 `*.sharc` 里取出着色器程序与反射信息；这一步是接翻译链的入口 |
| 2 | **接上翻译链** | 参考项目 `gfx/tools/`：Ryujinx 解码器（C#，用本机 .NET 8 编）→ SPIR-V → 本机编好的 spirv-cross 1.4.357.0 → MSL |
| 3 | 宿主加载器 | 移植 `loader.c` / `entry.S` / `thread.c`：多模块映射、线程槽、键页、跨模块重定位、按名解析 import |
| 4 | svc + SDK 层 HLE | `sdk` 有 106 处 svc、29 处 cntpct；nn::os 可原样跑，只要内核层被换掉 |
| 5 | 服务层 HLE | 按 `main` 实际调用逐族实现（含 Audren 92 项） |
| 6 | NVN → Metal | 469 个名字的函数表 + 命令记录/重放 |
| 7 | 触屏 | SMO 是 3D 平台跳跃，摇杆与按键映射要重新设计 |

---

# 第三轮：着色器翻译链打通（SMO 着色器 → Maxwell → SPIR-V → MSL）

## 2.10 `.sharc` / `.sharcb` 是什么（实测）

`.szs` 解开后是两个文件（名字共享后缀，SARC 允许）：

| 文件 | magic | 内容 |
|---|---|---|
| `X.sharc` | `AAHS`（"SHAA" 反写） | **定义**：着色器名、变量名、UBO 名、`#define` 名（`SAMPLING_TYPE` / `IS_OUT_LINEAR`），以及 **GLSL 源码**（`alDefineVarying.glsl`、作者注释 "Matsuda Hirokazu (C)Nintendo"） |
| `X.sharcb` | `BAHS`（"SHAB" 反写） | **二进制**：编译好的 Maxwell 机器码 |

`.sharcb` 内部：每个着色器变体是一个槽位，以 `0x12345678` 标记开头；
`+0x30..+0x80` 是 **SPH（着色器程序头）**，`+0x80` 起是 Maxwell 指令。

## 2.11 翻译链已经在**本机**跑通

| 环节 | 状态 |
|---|---|
| 翻译器（Ryujinx 着色器库 + `dmsh_xlate`，C#） | ✅ 本机 .NET 10 编译成功（0 警告 0 错误） |
| SPIR-V → MSL | ✅ 本机编译的 spirv-cross 1.4.357.0 |
| SMO 着色器 → SPIR-V | ✅ **顶点着色器已译出**：blob0/blob5 译出 `attr=2`，正好对上 `.sharc` 里的 `aPosition` + `aTexCoord1` |

**怎么确认 SPH 在那里的（判据，不是猜）**：Ryujinx 的 `ShaderHeader`
（它解的就是真实 Switch 着色器）规定 `word0` bit[10:13] 是 stage、`+0x18` 是 imap、`+0x48/+0x4C` 是 omap。
把 `+0x30` 当 SPH 解，imap 得到 `0x0a`（X/Y 都是 Perspective 插值）、omap 得到 `0x0f`（写深度），
位置与语义全部吻合；而按 Ryujinx 排法解 word0 得到 stage=5（非法），说明 **Nintendo 的 NVN 头里
word0 的位排法与 GPU SPH 不同** —— 这一项还没定下来，是下一步第一件事。

绕开它的办法（已验证有效）：**`+0x30..+0x80` 的 imap/omap 段原样抄，只把 word0 的 stage 位按
Ryujinx 排法写**，再把 `word3` 的 OutputTopology 填成 `TriangleStrip`（不填会抛
`Invalid output topology "0"` —— 这个报错也是判据的一部分）。这样做顶点侧就能译出正确的
顶点属性数量。

## 2.12 还没通的

- **片元着色器**：能译完（不再抛异常、不再是空循环），但译出的反射里还没有贴图/颜色输出。
  可能原因（按可能性排序）：片元侧还需要 `c1` 常数段（`BRX` 间接跳转的跳转表，参考项目
  `dmsh_xlate` 的注释里写过：不给 c1，粒子着色器的控制流会错）；或者变体与 stage 的配对还不对。
- **facts（贴图类型/格式、顶点属性类型、片元输出类型、计算线程组大小）**：参考项目从 PC 版的反射
  里取，SMO 没有 PC 版 —— 这些要从 `.sharc` 的定义（`SAMPLING_TYPE` 等 `#define`、UBO 成员）
  自己推。这是这条链剩下的主要工作。

---

# 第四轮：着色器全量翻译通过（8281 → 8269，0 失败）

## 2.13 blob 布局定下来了

```
+0x00  u32 0x12345678        槽位标记
+0x04  0x2C 字节              （实测全零）
+0x30  SPH 0x50 字节          标准 Maxwell 着色器程序头
+0x80  Maxwell 机器码          到下一个标记为止
```

**SPH 原样喂给翻译器即可**（`dmsh_xlate` 要的就是「SPH + 指令」）：不需要合成 SPH，也不需要 `c1`。
对应工具：`smo/tools/sharcb.py`。

## 2.14 一次栽跟头：Ryujinx 的 ShaderStage 枚举从 0 起

我按「Vertex=0」去解 SPH 的 stage 位，得到一堆非法值，白折腾了两轮。实测映射（逐个取值试出来的）：

| SPH bit[10:13] | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Ryujinx 解出 | Vertex | TessCtrl | TessEval | Geometry | Fragment |

原因是 Ryujinx 的枚举是 `Compute=0, Vertex=1, TessellationControl=2, TessellationEvaluation=3,
Geometry=4, Fragment=5`（`Compute` 在最前面）。所以 **Nintendo 的 SPH 本来就是标准格式**，
blob0/5 的 stage=1（顶点）、其余 stage=5（片元）。

## 2.15 全量结果

`sharcb.py` 从 21 个 `*.sharcb` 里取出 **8281 个着色器**（181 顶点 / 8097 片元 / 3 几何），
去重后 **8269 个唯一键**（12 个是内容完全相同的变体），全部经 `dmsh_xlate` 译成 SPIR-V：

```
8 片并行，每片 1036 个作业：全部「1036 成功，0 失败」
```

**语义逐条对上了**（拿 `.sharc` 里内嵌的 GLSL 源码当判据）：

| 译出的 MSL | 对应 GLSL |
|---|---|
| 顶点：`out.m_21.xy = in.m_18.xy;`（vTexCoord = aTexCoord1）<br>`gl_Position.xy = aPosition.xy * 2.0` | `alHalfResBuffer.glsl` 的 `VERTEX_SHADER_QUAD_TRIANGLE__CALC_POS_TEX` 宏 |
| 片元：`fp_t_tcb_8.sample(...)` → `out.m_26 = _36`<br>采样坐标前一串 `1/gl_FragCoord.w × (v × w)` 的透视插值 | `oColor = texture(uSrcTex, vTexCoord)`，且 SPH 的 imap X/Y = 2 = Perspective ✓ |
| 片元：`gather(` + `[[depth]]` | `GATHER_DEPTH_MAX / MIN / AVG`（`textureGather`）✓ |
| 片元：`[[color]]` + `[[depth]]` | `IS_OUT_LINEAR == 1` 时输出 `oLinearDepth` ✓ |

`.szs` 里还有 7 个 `.bfsha`（单文件，没有 `.sharc`/`.sharcb` 对）—— 还没处理，是同类归档的另一种打包。

## 2.16 还没做的两件事

1. **facts（贴图维度类型 / 格式、顶点属性类型、片元输出类型、计算线程组大小）**：
   参考项目从 **PC 版**的反射里取，SMO 没有 PC 版。现在的翻译按缺省值走（`Texture2D` +
   `R8G8B8A8Unorm`），所以**语义对、细节待定**。取法有两条，都要做：
   - 从 `.sharc` 定义里推：`SAMPLING_TYPE` 等 `#define`、UBO 成员类型、着色器名
   - 真机跑一遍，把宿主实际看到的管线状态（贴图格式、属性布局）dump 出来，回头重出着色器库
2. **metallib**：Windows 上没有 Apple 的 Metal 编译器。按参考项目的 NO_XCODE 路线：
   MSL 源码进包，首次启动在手机上编译一次（系统会缓存）。

---

# 第五轮：GitHub 云端出包打通（CI 全绿，IPA 产出）

仓库：https://github.com/hyc1743/super-mario-odyseey-ios（名字里多打了一个 e，见文末）

## 2.17 两个 job

| job | runner | 做什么 | 状态 |
|---|---|---|---|
| 工具链自检（不需要游戏文件） | ubuntu | `pip install -r requirements.txt` + `selftest.py`（Yaz0 / SARC / NSO 头 / 改写器端到端） | ✅ |
| 构建 App 壳 → 未签名 IPA | macos | `brew install xcodegen` → `shell_build.sh` → 产物 `SMOMobile-shell.ipa`（28 KB）作为 artifact | ✅ |

**为什么云端 macOS runner 就够**：参考项目是在 Apple 芯片的 Mac 上用 `xcodebuild` 出包的；
GitHub 的 macOS runner 正好提供这台机器（含 Xcode）。于是「本机没有 Mac」不再是障碍。

## 2.18 打通这条链路时踩的 6 个坑（每个都真实挂过 CI）

| # | 现象 | 根因 | 修法 |
|---|---|---|---|
| 1 | `CFBundleShortVersionString` 非法 | CI 把 **40 位 git SHA** 塞进 `MARKETING_VERSION`；该键只允许「数字 + 点」 | 版本号归化：非 `v1.2.3`/`1.2.3` 形状一律回落 `0.1.0` |
| 2 | Xcode 直接拒绝 | `project.yml` 写死 `iOS 16.0`，新版 Xcode 不支持这么低的部署目标 | 从 SDK 的 `SDKSettings.plist` 读 `MinimumDeploymentTarget`，取与工程值的较大者 |
| 3 | 脚本静默中止 | **BSD `sort` 不支持 `-V`**（那是 GNU coreutils），而脚本带 `set -o pipefail` | 用 awk 比版本号 |
| 4 | 同上（隐患） | `sed … \| head -1` 在 `pipefail` 下可能被 **SIGPIPE** 判失败 | 改用 awk「打印后立即 exit」 |
| 5 | `VERSION: unbound variable`（本地怎么都复现不了） | **macOS 自带的 bash 3.2 是多字节不安全的**：`"$VERSION，来源"` 里紧跟变量的全角逗号被**吞进变量名**，于是去查 `VERSION，` 这个不存在的变量；`set -u` 当场中止。本地 bash 5.3 正确处理多字节，所以本地永远好的 | 变量**一律加花括号** `${VERSION}`；并加了扫描脚本查同类问题 |
| 6 | `Build input file cannot be found: …/Gen/Gen/Info.plist` | `xcodegen --project Gen` 会把 `project.yml` 里所有相对路径都拼到 `Gen/` 下面 | 改为在当前目录生成工程（`--project .`） |

## 2.19 一个可复用的诊断手法：check-run annotations

GitHub 的**运行日志要仓库管理员权限**才能下载（`.../actions/jobs/<id>/logs` 返回 403），
但 **check-run 的 annotations 是公开可读的**。所以 workflow 里加了：

- 构建步骤整段输出落盘（`tee smo/ios/out_step.log`）
- 失败时把日志尾部与 `error:` 行用 `::error::` 发成注解
- 同时把日志传成 artifact（管理员可直接下载）

这样在拿不到管理员权限的情况下，也能读到真实报错 —— 上面第 5、6 个坑就是这么定位的。

---

# 第六轮：facts 推导（并证明「缺省值本来就对」）

## 2.20 facts 从哪来：游戏自己的 GLSL

参考项目的 facts 来自 **PC 版**的反射；SMO 没有 PC 版，但这些事实就写在 `.sharc` 内嵌的 GLSL 里，
而且**同源**（编译成 Maxwell 的就是它）。`smo/tools/glsl_facts.py` 把它们读出来：

| facts | GLSL 出处 | 全量实测 |
|---|---|---|
| 贴图维度类型 | `uniform sampler2D/3D/Cube/…` | 2d ×172 · cube ×28 · 3d ×14 · 1d ×2 · 2darray ×2 |
| 顶点属性分量类型 | `layout(location=N) in vec4/…` | **全部 float（71 处）** |
| 片元输出分量类型 | `layout(location=N) out vec4/…` | **全部 float（41 处）** |
| 计算线程组 / 共享内存 | `layout(local_size_…)` | 1 个程序带 local_size；无 image 声明 |
| 变体轴 | `// @@ id="cSamplingType" choice="0,1,2,3"` | 85 种（cRenderType、cFogBlendType…） |

**两个实现要点（都踩过）**：
1. **必须先展开宏**：binding 写在宏里（`#define BINDING_SAMPLER_SRC_TEX layout(binding = 0)`），
   不展开一个贴图都读不出来；
2. **`#if`/`#endif` 必须按嵌套配对**：按「到第一个 #endif 为止」切会把声明切掉一半
   （顶点属性就是这么丢的）。

## 2.21 一个反直觉的结论：贴图维度不需要推

把 `alCubeMapShader`（GLSL 里是两个 `samplerCube`）**带 facts 与不带 facts 各译一遍**，
两边 MSL 里都是 7 个 `texturecube<`：

| 运行 | MSL 里的贴图类型 |
|---|---|
| 不带 facts | `texturecube<` ×7 |
| 带 facts | `texturecube<` ×7 |

原因：**Maxwell 的 TEX 指令本身编码了贴图维度**（TEX/3D/CUBE 是不同操作码），
所以翻译器从机器码就能知道。GLSL facts 在这里的作用是**交叉校验**，而不是提供信息。

真正**代码里没有、必须从管线状态拿**的只有：顶点属性的分量类型、片元输出的分量类型
（由顶点格式与 MRT 状态决定，不在着色器指令里）—— 而 SMO 的这两项**全是 float**，
恰好等于翻译器的缺省值。

**所以结论是**：之前「不带 facts」的那一遍（8269 个）对 SMO 的着色器本来就是对的；
这一轮的价值在于**证明**它是对的（而不是假设）。以后接入整数属性/MRT 的游戏版本时，
`--facts` 开关已经把这条路留好了。

## 2.22 `.bfsha` 是另一种容器（还没处理）

7 个 `.bfsha` 文件（magic `FSHA`）**不是 SARC**，里面也没有 GLSL（`@file`、`AGL_*_SHADER` 都搜不到），
只有 uniform 名（`cTextureDisplacement0`、`cTextureCubeMapGem0`、`_stcol0`…）。
它和 `.sharc`/`.sharcb` 是两个不同的东西，需要单独解析 —— 目前全量翻译覆盖的是 21 个 `.sharcb`
（8281 → 8269 个唯一着色器），这 7 个是剩下的口子。

---

# 第七轮：着色器全覆盖（18470 个）+ 宿主 HLE 工作清单

## 2.23 `.bfsha` 补完：着色器覆盖到 28 个归档

`.bfsha`（magic `FSHA`）**不是 SARC**、也没有 GLSL，但**着色器槽位布局与 `.sharcb` 完全一样**
（`+0x00` 标记 `0x12345678` / `+0x30` SPH 0x50 / `+0x80` 机器码），所以同一套切分就能覆盖。

| | 归档数 | 着色器 | 唯一键 |
|---|---|---|---|
| 只有 `.sharcb` 时 | 21 | 8281 | 8269 |
| **加上 7 个 `.bfsha`** | **28** | **18487** | **18470** |

贡献最大的是 `alRenderMaterial.bfsha`（9811 个 —— 那个 Uber 材质着色器的全部排列组合）。
全量翻译：8 片并行，每片 2311 个作业，**全部「成功、0 失败」**，产出 468 MB SPIR-V + 反射。

## 2.24 宿主 HLE 工作清单（`smo/tools/hle_inventory.py`）

参考项目的 `hle_inventory.py` 是从**自己的源码**里抽 HLE 条目（事后审计）；
本工具做**反过来**的事：从事先的游戏文件里算出**必须实现什么**（事前规划）。输出
`smo/data/hle_imports.tsv`（1341 条，逐条给出「哪个模块、家族、谁导出、宿主要做什么」）。

**按处置方式统计（4 个模块的 1341 条 import）：**

| 条数 | 处置 |
|---|---|
| **412** | **服务客户端 —— 宿主必须接管（HLE_FORCE）** |
| 398 | C 库/运行时（模块内或宿主 libc 直通） |
| 274 | 媒体框架（模块内，原样跑） |
| 156 | 模块内（本地库） |
| 60 | C++ 标准库（模块内） |
| 19 + 19 | 网络 socket / ssl（宿主：离线桩或 BSD socket） |
| 3 | 图形 NVN（`nv::InitializeGraphics` 等，宿主接管） |

**412 条服务客户端按家族**（这就是宿主服务层的工作面）：

```
nn::audio 106   nn::hid 53   nn::socket 28   nn::fs 25   nn::fontll 24
nn::sf 23       nn::oe 20    nn::account 19  nn::nfp 13  nn::web 10
nn::nifm 9      nn::friends 9   nn::time 8   nn::image 7  nn::crypto 7
nn::vi 6        nn::lmem 6   nn::fgm 6       nn::prepo 5  nn::ssl 4 …
```

**内核层**（改写器在各模块里数出来的宿主门）：`sdk` **106 处 svc + 29 处 cntpct**，
`rtld` 4 处 svc；`main` 与 `subsdk0` 没有裸 svc（全走 sdk 的 nn::os 包装）。

## 2.25 三个意外发现

1. **SMO 的过场视频用的是 Android 媒体框架**：`subsdk0` 从 `sdk` 引入 174 个
   `android::` 符号（`android::HeapObject`、`android::IInterface`…）以及 55 个
   `NvOs*/NvRm*`（NVIDIA 驱动层）。也就是说 Nintendo 把 libstagefright/binder 一系移植进了 SDK。
   对宿主的影响：`movie::`（11 条）与 `android::`（174 条）都是**跨模块、原样跑**；
   真正要 HLE 的是它底下依赖的解码/输出服务。
2. **图形初始化走的不止 `nvnBootstrapLoader`**：还有 `nv::InitializeGraphics` /
   `nv::SetGraphicsAllocator` / `nv::SetGraphicsDevtoolsAllocator`（3 条，`main → sdk`），
   宿主同样要接管。
3. **`NvRmChannel*/NvRmStream*/NvRmSurface*`**（NVIDIA Resource Manager，驱动层）
   也被 `main` 直接引入 —— 它们通常由 NVN 内部调用（而 NVN 被宿主绕过了），
   但这条要在真机上确认，不能想当然。

## 2.26 分类器踩的坑（都写进代码注释了）

- 家族提取不能用 `startswith("_ZN2nn")`：常量成员函数是 `_ZNK2nn…`、虚表是 `_ZTVN2nn…`，
  这样会漏 **774 条**（其中就有 `nv`（NVN）与 `android`（媒体框架））。
- 不先把 **C 风格符号**（`__cxa_*`、`acos`、`__errno_location`、`__nnmusl_*`）拦下来，
  它们会因为「被别的模块导出且不在本地库白名单里」被错归成服务客户端（实测错 **275 条**）。
- `St` 是 Itanium ABI 里 `std::` 的替代码（`_ZNSt3__112basic_string…`），不是普通命名空间。

---

# 第八轮：宿主装载器（核心跑通，并在真实产物上验证）

## 2.27 装载器做了什么（对应参考项目 `loader.c`）

`smo/host/loader_core.c` 是**平台无关**的那部分，逐条对应参考项目：

| 步骤 | 对应参考项目 | 本仓文件 |
|---|---|---|
| 读改写器表头（段边界、键页、8 个槽号） | `read_layout` | `loader_core.c` |
| 装键页：把「**实际**键号 × 8」写进产物键页，再设只读 | `install_key_page` | 同上 |
| 登记宿主门（`gates.tsv` 逐行） | `register_gates` | 同上 |
| 解析 MOD0 与动态段（SYMTAB/STRTAB/INIT/INIT_ARRAY） | `parse_dynamic` | 同上 |
| 符号名哈希表 + **线性扫描逐条对照**（参考项目 DM_SYMCHECK 的做法） | `module_sym` | 同上 |
| 四类重定位：RELATIVE / ABS64 / GLOB_DAT / JUMP_SLOT | `relocate` | 同上 |
| 解析顺序：**HLE_FORCE → 本模块 → 别的模块 → 宿主 import** | `resolve_sym` + `force_lookup` | `dm_hle_force()` 钩子 |

平台相关的只有三件事（`dm_image_alloc` / `dm_code_protect` / `dm_ro_protect` / `dm_slot_key`），
声明在 `dm.h` 里 —— 于是**同一份代码既能编进 iOS App，也能在本机当自检跑**（Windows/Linux 上
用 malloc + 空保护 + 假槽号）。这是在拿不到 Mac 的情况下能对装载器做的最强验证。

## 2.28 在真实产物上的实测结果

```
  rtld     映像   0x1013c  text_end   0x17a0  patch  0x10000  符号     22  键页 OK
  sdk      映像  0xa608bc  text_end 0x3de8b8  patch 0xa20000  符号  19866  键页 OK
  subsdk0  映像  0x7043bc  text_end 0x2f45b4  patch 0x6c0000  符号  11388  键页 OK
  main     映像 0x25c5350  text_end 0xbf1838  patch 0x25b0000  符号  91231  键页 OK

  重定位：RELATIVE 174723+8564+1751+13   ABS/GLOB 14850+14262+16416+17   JUMP_SLOT 639+6264+3527+2
  宿主门合计 139（sdk 135 = 106 svc + 29 cntpct，rtld 4）
  交宿主 import：调用 38 次，不同名字 25 个
  符号查询 48127 次，哈希表与线性扫描不一致 0 次
```

**两条交叉验证（两个完全独立的工具给出同一个数）：**

| 事实 | 装载器 | 独立工具 |
|---|---|---|
| `main` 的 JUMP_SLOT = **639** | 从重定位表逐条数 | `xref.py` 从指令里数 PLT 桩 = 639 ✓ |
| `main` 交宿主 import = **12**、`subsdk0` = **4** | 装载器解析结果 | `import_graph.py` 独立算的 12 / 4 ✓ |

## 2.29 一个重要的架构点（关系到最后的工作量估计）

装载器报「交宿主 import」只有 25 个名字，**远小于**第 2.24 节列出的 412 个服务客户端。
原因：**服务层那 412 个函数是被 `sdk` 模块导出的**，走的是跨模块解析，根本到不了
「交宿主」这一步 —— 它们必须靠 `dm_hle_force()`（对应参考项目的 `HLE_FORCE`）**强制接管**。

所以宿主的工作面是**两块相加**：
1. **412 个服务函数** → 需要 `HLE_FORCE` 表逐条登记 + 实现
2. **25 个无人提供的 import**（含 NVN 的 `nv::*`、`glslc*` 等）→ 需要 `resolve_import` 兜底

## 2.30 移植时自己踩的两个坑

1. **漏了跨模块解析**：第一版 `relocate` 里未定义符号直接交宿主，于是 `subsdk0` 报「交宿主 8482 次」
   （真值 4）。补上 `guest_sym()` 后数字立刻与 `import_graph.py` 对上。
2. **合成产物的 MOD0 被覆盖**：自检用的合成模块把 `MOD0` 摆在偏移 0，前 4 字节又写成了 ELF 头，
   加载器报「找不到 MOD0」。合成器现在前 0x10 字节留给头部。

## 2.31 CI 也有了装载器覆盖

CI 里没有游戏文件，所以加了 `smo/tools/make_synthetic_artifacts.py`：按**同一个格式**造一份最小产物
（MOD0 + 动态段 + 符号表 + 四类重定位 + fixups/gates），CI 上 `gcc -Werror` 编出装载器再跑它：

```
gcc -O2 -Wall -Wextra -Werror -o /tmp/loader_selftest smo/host/loader_core.c smo/host/tests/loader_selftest.c
/tmp/loader_selftest work/synthetic sdk main
```

真实产物四个模块的强断言（门 139、交宿主 20–60 个名字）只在跑真实集合时才生效。

---

# 第九轮：内核层清单 + HLE 接管表 + 宿主骨架（Apple 侧）

## 2.32 内核层的确切清单：106 个 svc 号

从改写产物 `work/rewrite/*.gates.tsv` 里直接读出 SMO 用到的 svc 号（这是**权威**的，不是估的）：

```
sdk：106 个不同的 svc 号，覆盖 #0x01–#0x7f，每个恰好 1 个调用点
     （即 SDK 给每个裸系统调用包了一个包装函数）
rtld：4 个（#0x06 / #0x26 / #0x27 / #0x28）—— 装载器自己用的
cntpct：29 处，目标寄存器 x0 ×12、x8 ×6、x20 ×8、x21 ×2、x23 ×1
     （⇒ 门必须回读任意通用寄存器，entry.S 里 x0..x29 全回读不是保守，是必需）
```

**注意**：106 个 svc **都被改写**（改写器不看可达性），但不都被**执行**。所以宿主的做法与参考项目一致：
核心的几个（内存、线程、同步、计时、调试输出）认真实现，其余接到**会响的桩**上，
真机日志里出现哪一行就是下一批要补的。这比"照单全写 106 个"现实得多。

## 2.33 服务进程清单（游戏自己声明的）

`main.npdm`（magic `META`，类型 `Application`）里列着 SMO 请求的服务名，共 33 个：

```
acc:u0  aoc:u  appletOE  audin:u  audout:u  audren:u  banana  bcat:u  bsd:u  bsdcfg
caps:su  csrng  friend:u  fsp-srv  htc:tenv  htcs  hwopus  ldn:u  ldr:ro  mii:u  mm:u
nfc:mf:u  nfc:user  nfp:user  nifm:u  nsd:u  nvdrv  pctl  pl:u  prepo:u  sfdnsres
time:u  vi:u
```

几个值得记下来的：
- **`nvdrv`**：游戏直接要 NVIDIA 驱动服务 —— 与 §2.25 里 `NvRmChannel*/NvRmStream*` 被 main 直接引入相互印证
- **`audren:u`**：音频渲染器（对应 nn::audio 那 106 个 import）
- **`hwopus`**：Opus 解码（过场/语音）
- **`fsp-srv` / `vi:u` / `acc:u0` / `friend:u` / `nfp:user` / `bsd:u`**：文件系统、显示、账号、好友、amiibo、socket
- **`banana`**：Nintendo 内部服务名（保留观察）

入口符号：**`nnMain`@0x536f90**（`_init`@0x24 是模块初始化，与参考项目的 DT_INIT 处理一致）。

## 2.34 HLE 强制接管表：446 条（自动生成）

`smo/tools/gen_hle_force.py` 从 `smo/data/hle_imports.tsv` 生成 `smo/host/hle_force_gen.c`：

| 家族 | 条数 | | 家族 | 条数 |
|---|---|---|---|---|
| nn::audio | 212 | | nn::sf | 46 |
| nn::hid | 106 | | nn::fs | 42 |
| nn::socket | 94 | | nn::oe | 40 |
| nn::fontll | 48 | | nn::account | 38 |
| nn::ssl | 46 | | nn::nfp | 26 |

**为什么这 446 条必须"强制"接管**（即使 sdk 模块里有定义）：SDK 的客户端实现要走 IPC
（cmif/hipc）到真实的服务进程，而宿主里没有那些进程。这就是 §2.29 那个数字差的来源：
装载器报"交宿主 import"只有 25 个，而这 446 个是被 sdk 导出的、走跨模块解析的那一批。

生成器踩的两个坑（都已写进注释）：
1. 头部模板里 `LOG("…%s…")` 的 `%s` 被 Python 的 `%` 格式化吃了 ⇒ 改用字符串替换；
2. 筛选口径写错（只筛了「宿主接管」前缀）⇒ 只生成出 3 条（nv::*），漏掉了 443 条
   「模块内(服务客户端，仍需接管)」。现在按「含"服务客户端" or 宿主接管/网络前缀 or 家族是 nv」筛。

## 2.35 宿主骨架（Apple 侧）

| 文件 | 内容 | 验证状态 |
|---|---|---|
| `loader_core.c` | 装载核心（上一轮） | ✅ 真实产物上通过 |
| `hle.c` + `hle_force_gen.c` | 接管表查询 + 记名桩（`UNIMPL <名字>`） | ✅ 本机 `-Werror` 编过 |
| `entry.S` | 门公共入口（存 x0..x29/q0..q31/NZCV/FPSR/FPCR → `gate_dispatch` → 全回读，x18 不回读）+ 4096 个静态记名桩 + 客体线程起点 | ⏳ CI 编（macOS） |
| `thread.c` | 四个线程槽（K18/KTLS/KTLR/KGATE）+ **TSD 布局自证**（`tpidrro_el0 + 8×键号`，不符就中止） | ⏳ CI 编 |
| `loader_apple.c` | 映像分配与段权限。macOS 走 `mmap(MAP_JIT)` + `mprotect(RX)`；**iOS 那条（三段内嵌签名段 + `mach_vm_remap`）只留了接口与命名约定** | ⏳ CI 编 |
| `main.c` | bootstrap：建线程键 → 装载 → 跑各模块 DT_INIT → 跳 `nnMain`（或 `--entry` 指定符号、`--list` 只装载） | ⏳ CI 编 |

`Makefile` 提供 `make -C smo/host`（编宿主）、`test`（合成产物跑装载器自检）、`run`（真实产物只装载）。

**明确没说到的**（下一步）：SDK 运行时的初始化顺序、iOS 的三段内嵌出包脚本、446 条服务的真实实现、
NVN → Metal 图形层、前端。现在这些位置都是会响的桩，真机日志会告诉我们先卡在哪。

## 2.36 CI 新增三项

```
① 编宿主里平台无关的那部分（hle.c / hle_force_gen.c），-Werror
② 装载器自检（合成产物）——上一轮已加
③ macOS 上 `make -C smo/host smo_host` —— 对 entry.S / thread.c / loader_apple.c / main.c 的真实检查
④ gen_hle_force.py --check —— 生成的接管表必须与 import 清单一致（改了清单忘了重跑就红）
```

---

# 第十轮：内核内存族 svc（实现 + 单测 20 条断言）

## 2.37 内存族做了什么（对应参考项目 `hle_svc.c`）

`smo/host/hle_svc.c` 实现 Horizo n 内存族的 6 个系统调用，做法与参考项目一致：

| svc | 名字 | 宿主做法 |
|---|---|---|
| 0x01 | SetHeapSize | 在预留块里按游戏要的大小放开/收回堆区读写；返回 `x1` = 堆基址 |
| 0x02/0x03 | SetMemoryPermission / SetMemoryAttribute | 直接成功 |
| 0x04 | MapMemory | **内容拷贝**模拟地址别名（SDK 建线程时把堆上的栈搬进栈区） |
| 0x05 | UnmapMemory | 内容搬回源区 + 消登记 |
| 0x06 | QueryMemory | 按分区/登记表回报区间（基址、大小、状态、权限） |

地址空间模型：预留**一整块**（5 GB，只占地址不占内存）→ alias 512 MB / stack 256 MB /
heap 从 +1 GB 处起 4 GB。状态码沿用参考项目的实测值：堆 = 5、栈/映射 = 0xB、空闲 = 0、代码 = 3。

**两条从参考项目抄来的实测经验**（都写进注释了）：

1. **应用内存池要报大一点**：游戏会把宿主报的总量**整块**设成自己的堆，再交给自己的分配器。
   参考项目报 3 GB 时主堆只剩约 18 MB，出现「128 KB 请求返回空而原版代码不检查空指针就写」的崩；
   他们改成 3285 MB + 512 MB。**SMO 的这个数还没在真机上量过** —— 代码里先沿用同一个数，
   并用 `dm_app_pool()` 单独放一处，等真机日志再定。
2. **QueryMemory 对宿主栈要回报整段栈**，不能回报「它所在的一页」：SDK 初始化主线程记录时拿
   当时的 sp 查这里，之后 `nn::os::GetCurrentStackInfo` 会断言 sp 仍在那个区间内，不在就中止。
   参考项目踩过（原因是宿主栈顶位置随环境变量长度移动），本项目照改。

## 2.38 单测：20 条断言全过（本机 + CI，不需要游戏文件）

`smo/host/tests/svc_selftest.c`，把平台页操作换成朴素实现（calloc + 空保护 + 假栈），
于是同一份 `hle_svc.c` 能在 Windows/Linux 上跑：

| 组 | 断言 |
|---|---|
| 分区 | 堆基址非 0、正好在预留块 +1 GB 处 |
| SetHeapSize | 成功返回 0 且账本跟着走 |
| **超池重试** | 超池返回 `0x10801`，**按 2 MB 递减重试后成功**（游戏启动就是这么重试的） |
| MapMemory/Unmap | 内容往返一致、登记表进出正确、重复解除映射被拒（`0xD401`） |
| 目标非法 | 不在 stack 区 → `0xDC01` |
| QueryMemory | 堆=5、映射=0xB、空闲=0、**宿主栈回报整段**（大小 = 整段栈，不是一页） |

```
$ ./svc_selftest
== 1. 地址空间分区 ==    ✅ ✅
== 2. SetHeapSize ==     ✅ ✅
== 3. 超出应用内存池… ==  ✅ ✅ ✅
== 4. MapMemory/Unmap == ✅ ✅ ✅ ✅ ✅
== 5. 目标非法 ==        ✅
== 6. QueryMemory ==     ✅ ✅ ✅ ✅ ✅ ✅
全部通过
```

## 2.39 还没做的（线程族与后面）

- **线程族 svc**（`hle_thread.c` 的对应物）：`CreateThread`/`StartThread`/`WaitSynchronization`/
  `ArbitrateLock`/事件与 `ProcessWideKey`… —— 参考项目那份 671 行，是下一块。
  这一轮已经给它留好接口（`svc_thread()`，内存族不认识就转给它）。
- SDK 初始化顺序、iOS 三段内嵌出包、446 条服务实现、NVN → Metal。

---

# 第十一轮：内核线程族 svc（实现 + 真并发单测 15 条断言）

## 2.40 线程族做了什么（对应参考项目 `hle_thread.c`）

`smo/host/hle_thread.c`：**每个客体线程 = 一个宿主 pthread**，跑在 SDK 给的客体栈上。
SDK 的 `nn::os` 原样执行，只把它底下的内核换成宿主。

| 类 | svc |
|---|---|
| 线程 | 0x08 CreateThread · 0x09 StartThread · 0x0A ExitThread · 0x0B SleepThread · 0x0C/0x0D 优先级 · 0x0E/0x0F 核掩码 · 0x10 当前核号 · 0x25 线程号 · 0x19 CancelSynchronization |
| 锁 | 0x1A ArbitrateLock · 0x1B ArbitrateUnlock（标签字 = 持有者句柄 \| 0x40000000 有等待者） |
| 条件 | 0x1C WaitProcessWideKeyAtomic · 0x1D SignalProcessWideKey |
| 地址 | 0x34 WaitForAddress · 0x35 SignalToAddress |
| 事件 | 0x45 CreateEvent · 0x11 SignalEvent · 0x12 ClearEvent · 0x17 ResetSignal · 0x18 WaitSynchronization · 0x16 CloseHandle |

**调度顺序按公开内核行为**：优先级数值小者优先，同优先级**先登记者**优先（不是随意先到先得）。
所有等待挂在一把全局锁 + 每线程一个条件变量上 —— 先求正确，性能后量（这是参考项目的取舍，也是本项目的）。

**一条顺序上的关键点**（参考项目拿它当单测的负对照，我照抄并写明理由）：
`WaitProcessWideKeyAtomic` 必须**先把手上的锁交出去、再置条件键**。反过来会出现
「有人已经 Signal 过、而这里才登记等待」的窗口 ⇒ **唤醒丢失**。

## 2.41 单测：15 条断言全过（真并发）

`smo/host/tests/thread_selftest.c` 自己扮演客体代码，直接按 ABI 调 svc：

| 组 | 断言 |
|---|---|
| 主线程登记 | 句柄非 0 |
| 线程 | CreateThread + StartThread 真的跑起来；事件等待被唤醒并返回下标 0 |
| **争锁互斥** | 两线程各 2000 次加锁/解锁 → **临界区零重叠**、计数 4000、解锁后锁字回 0 |
| 条件变量 | 等者被 `SignalProcessWideKey` 唤醒，且**唤醒时锁已在手**（内核交回） |
| 地址仲裁 | 有线程确实在 `WaitForAddress` 上等之后，`SignalToAddress` 能把它唤醒 |
| 超时 | 无人触发时 `WaitSynchronization` 返回 `0xEA01` |
| CloseHandle | 事件两端都关才释放 |

顺手加了一个诊断口 `dm_thread_waiting(kind)`（当前各类等待的线程数）—— 真机上"卡住时谁在等什么"
就靠它；单测也用它把时序变成确定的（否则测的是竞态，不是语义）。

**自己踩的两个坑**（都写进注释了）：
1. 等待链登记写错（`if (!t->next) t->next = g_wait; g_wait = t;`）会重复挂链/丢链；
2. `thread_exit` 里重复加全局锁会死锁，而且 `pthread_exit` 前**必须放锁**，否则全局锁永远锁死。
   另外单测一开始写成了「先 yield 一会儿再 signal」——那是竞态；改成用 `dm_thread_waiting` 固定时序。

## 2.42 现在单测矩阵（全部不需要游戏文件）

```
loader_selftest   装载器：真实产物上的强断言（本机）+ 合成产物（CI）
svc_selftest      内核内存族：20 条
thread_selftest   内核线程族：15 条（真并发）
```

---

# 第十二轮：fs 服务（26 个函数，单测 30 条断言）

## 2.43 做了什么

`smo/host/hle_fs.c`：真机上这些走 `fsp-srv` 服务进程，宿主直接接宿主文件系统。

| 组 | 函数 |
|---|---|
| 挂载 | QueryMountRomCacheSize · MountRom · MountTemporaryStorage · EnsureSaveData · MountSaveData · Commit/CommitSaveData · Unmount |
| 文件 | OpenFile · ReadFile（两种签名）· WriteFile · GetFileSize · SetFileSize · FlushFile · CloseFile · GetFileOpenMode |
| 目录 | OpenDirectory · ReadDirectory · CloseDirectory · GetEntryType |
| 改动 | CreateFile · DeleteFile · CreateDirectory · DeleteDirectoryRecursively · RenameFile |

挂载名 → 宿主目录：`rom` → `$SMO_ROMFS`（只读）、`save` → `$SMO_SAVE`（事务式）、`temp` → `$SMO_TEMP`。
路径形如 `rom:/System/Version.txt`；`DirectoryEntry` 布局按 Horizon ABI 逐字段对齐（0x310 字节，
`_Static_assert` 钉住）；错误码按模块语义（`0x202` = PathNotFound、`0x402` = PathExists）。

**存档做成事务式**（抄参考项目的设计）：挂载时把已提交版整树拷成工作目录，游戏的读写都落在工作目录；
`Commit` 时把工作目录换成已提交版（Apple 上 `clonefile` + `renamex_np(RENAME_SWAP)` 原子换名；
其它平台退化为「挪开旧版再换上新版」，代码里写明这是有窗口的退化）。

## 2.44 单测 30 条断言（不需要游戏文件：自己造 romfs 与存档目录）

除了常规读写，专门钉住了几件容易错的事：
- **只读挂载上写入必须被拒**（拿写方式打开、建文件两条路径）
- 不存在的文件返回 **0x202**（不是通用失败 —— 游戏会按它分支）
- **DirectoryEntry 布局**：type 在 0x304、size 在 0x308，逐项校验
- 存档事务：**提交之前已提交目录里看不到新文件**、提交之后能看到且内容一致

## 2.45 一个把测试坑到自己的 bug：断言宏求值两次

我的 `CHK(cond, msg)` 第一版写成 `printf(...(cond)...); if (!(cond)) ...` —— 条件**求值两次**，
于是每个带副作用的断言都跑了两遍：日志成对出现、`ReadDirectory` 第二遍时游标已到底、
`cnt` 被写成 0（我一度以为是目录读取实现坏了）。四个测试文件的宏都改成单次求值，
并在注释里写明这个坑。

**另外**：这个环境的 bash heredoc 会吃掉反斜杠（`\n` 变成真换行），写含 `\n` 的代码要用 edit 工具而不是 heredoc。

---

# 第十三轮：NVN 图形接口层（469 个名字的接管骨架）

## 2.46 做了什么

| 位置 | 内容 |
|---|---|
| `smo/gfx/nvn/names.txt` | 游戏向 `nvnBootstrapLoader` 索取的 **469 个名字**（从 main.bin 抽出的字符串，事实记录） |
| `smo/gfx/nvn/hle_nvn.c` | 接管 `nvnBootstrapLoader`；命令记录（Metal 重放的接缝）；未实现入口 |
| `smo/gfx/nvn/nvn_table.c` | 【生成】名字 → 宿主实现（469 项，248 已接核心家族，221 接未实现入口） |
| `smo/gfx/nvn/nvn_record_names.inc` | 【生成】记录桩（统一签名下一条宏展开 248 个） |
| `smo/gfx/README.md` | 这一层到哪一步、下一步要什么 |

**统一签名**：所有 NVN 函数都按 `(a0..a7) → u64` 收。理由与参考项目一致：苹果 AAPCS64 与 Switch
的差异主要在 <32 位参数的扩展与可变参数，统一收 8 个寄存器参数把差异挡在接口层。

## 2.47 生成器的名字一致性检查抓到了我两次手写错误

我按记忆手写了「要实现哪些 NVN 函数」，生成器的检查报出 **21 个名字游戏根本没要**：
- 游戏**不调用任何 `*BuilderCreate`** —— 它直接在对象上 `nvnXxxInitialize`
- `BeginRecord` / `EndRecord` 的真名是 **`BeginRecording` / `EndRecording`**
- `nvnSyncIncrement/GetValue/Reset` 不存在（游戏用的是别的名字）

所以现在**不手写名字**：按家族前缀（Device/MemoryPool/Buffer/Sync/Window/Program/Texture/Sampler/
Queue/Event）从真实名字表里选，生成器带 `--check` 保证生成物与名字表一致（CI 会跑）。

## 2.48 单测（不需要游戏文件、不需要 Metal）

```
✅ 表里名字数 > 400（469）
✅ 每个名字都能按名取到函数地址
✅ 已实现数与生成时登记的一致（248）
✅ 不在表里的名字返回 0（NVN 的真实行为：取不到就是 0，游戏自己处理）
✅ 空名字返回 0
✅ 调用进命令记录；可以清空（每帧重放前清）
✅ 未实现入口累计调用次数
```

## 2.49 图形层下一步（明确要什么）

1. **NVN 的真实结构布局**（各 `NVNxxx` 对象的大小与字段偏移）：公开的 `nvn.h` 里有声明，
   参考项目收录在 `gfx/nvn/include/nvn.h`（89 KB，MIT）。**本仓还没有这份头** —— 没有它，
   记录桩就只能记录、不能正确读写对象字段。这是下一批的第一件事。
2. **Metal 重放**（参考项目 `nvn_mtl.m` 626 KB，这一层最大的工作量）。
3. **着色器取用**：18470 个着色器已离线翻译完；`nvnProgramSetShaders` 收到控制段后算键查表即可。

---

# 第十四轮：NVN 接口层的真实机制（挖清了，并更正一条错误结论）

## 2.50 先更正错误：我上一轮的「只有 2 个名字被装载」是工具 bug

adrp 的掩码我写成了 `0x9F00001F`（**把 Rd 字段也算进固定位**），于是只有 `rd=x0` 的 adrp 能匹配 ——
"3 个装载点"全是 x0 就是线索。改成 `0x9F000000` 后，469 处名字装载全部找到。

教训写在这里，因为它值得记：**指令解码的掩码写错，会静默丢掉 99% 的匹配，而结果看起来"像"一个结论**
（"游戏只按名字要了 2 个函数"听起来完全合理）。所以现在只要出现"数量少得可疑"，都要用另一种方法交叉验一遍。

顺手做出来的工具（后面全程要用）：

| 工具 | 作用 |
|---|---|
| `smo/tools/rawdis.py` | 把摊平映像包成最小 ELF → 用 **LLVM 真反汇编器**读代码（手写反汇编只适合模式匹配） |
| `smo/gfx/tools/nvn_getproc.py` | 全 `.text` 找「装名字字符串」的位置 → 名字 ↔ 解析点 |
| `smo/gfx/tools/nvn_slots.py` | 名字 ↔ GOT 槽 ↔ 调用点（完整链条） |

## 2.51 机制（每一步都有反汇编证据）

1. `main` 静态链入了 NVN 的 **C 过程蹦床库**，并**导出** `nvnLoadCProcs`（0x720414，12936 字节，见符号表）。
2. `nvnLoadCProcs(x0=device, x1=getProc)` 是**展开的序列**：对 **461 个名字**各做
   `adrp/add 名字 → blr getProc → str 结果到 GOT 槽`。461 × 28 字节 ≈ 12936，与符号大小吻合。
3. 游戏（AGL）在 0x7312a8 附近调它：先用 `nvnBootstrapLoader` 取 **`nvnDeviceInitialize`**（0x731270）
   与 **`nvnDeviceGetProcAddress`**（0x731290）—— 这就是 `.text` 里仅有的两处名字装载；
   再把后者当 `getProc` 传给 `nvnLoadCProcs`。
4. 之后调用 NVN 的形状：`adrp x8,0x1e59000 ; ldr x8,[x8,#off] ; ldr x8,[x8] ; blr x8`。
   实测 **461 个槽全部被代码引用**（名字↔槽配对正确的独立证据），共 **173 处直接调用点、28 个名字**。
   其余调用走 AGL 自己缓存的表（真机 `UNIMPL` 日志补全）。
5. `pfnc_` 前缀的名字池（0x164dc47，451 个）就是 NVN C 过程表的**字段名**。

**对设计的验证**：需要接管的入口只有 `nvnBootstrapLoader`（唯一 import）与 `nvnDeviceGetProcAddress`
（按名字返回）—— 两个都由同一张 469 项名字表伺候 ✓✓。`nvnLoadCProcs` **不用接管**（它是客体代码，
会来调**我们**的 GetProcAddress 461 次）。→ 第十三轮建好的接口层形状是对的。

产物：`smo/gfx/nvn/slots.tsv`（名字/槽/解析点/调用点数/调用点，466 行；只有 NVN 公开 API 名，无游戏内容）。

## 2.52 顺手验证一条全局前提：x18

宿主 C 代码要在客体代码中间运行，前提是**客体不再写苹果的平台寄存器 x18**（门的出口保存 x18 但不回读）。
用 capstone 的读写集合精确检查（能区分 `x18` 与 SIMD 的 `s18/d18` —— 自己抠位会误判）：

```
smo/tools/check_x18.py  →  main / sdk / subsdk0 / rtld：0 条指令写通用 x18   ✅
```

这条不变量成立，"宿主与客体共用 x18" 的设计站得住 —— 这是整个「宿主函数插在客体中间」方案的前提之一。

## 2.53 下一步

1. NVN 状态层：把 248 个记录桩按家族换成真实现（宿主侧按对象指针索引的状态表，不写客体对象内存，
   因此不依赖 NVN 结构的版本细节）。
2. 枚举值：`smo/gfx/nvn/include/nvn.h`（h1k421 的 MIT 重建版，从 Darksiders II 的 DWARF 重建）
   提供 enums，用于后面的 Metal 翻译；结构布局只作交叉参考。
3. Metal 重放层。

---

# 第十五轮：NVN 核心家族的真实现（38 个函数）

## 2.54 状态层的设计选择：宿主侧表，不写客体对象内存

`nvn_state.c` 用「客体对象指针 → 宿主侧状态」的开放寻址表。**宿主一个字节都不写客体对象**，
理由：客体对象的大小/字段布局取决于**游戏编译时的 NVN 版本**，我们手上只有第三方重建的 nvn.h
（从别的游戏的 DWARF 重建），版本未必一致 —— 往客体对象里写字段就有踩出分配范围的风险。
不写它，就完全不依赖布局。代价是要一张表 + 类型检查（同址异类由 `type` 挡住）。
删除用「整表重排」而不是后移/墓碑：对象几百个、删除很少，简单且不容易写错。

**例外**：出参指针（如 `nvnDeviceGetInteger` 的 out）必须写客体内存，宽度只能靠调用点定 ——
所以这一条现在只写 0 并打日志（写错宽度比不写更糟）。

## 2.55 本轮实现的 38 个（都是游戏真实索取的名字）

| 家族 | 函数 |
|---|---|
| Device | BuilderSetDefaults/SetFlags、Initialize/Finalize/GetInteger、**GetProcAddress** |
| MemoryPool | BuilderSetDefaults/SetDevice/SetStorage/SetFlags、Initialize/Finalize、**Map**、GetFlags、Flush/InvalidateMappedRange |
| Buffer | BuilderSetDefaults/SetDevice/SetStorage、Initialize/Finalize、GetAddress |
| Sync | Initialize/Finalize/Wait（+ 宿主侧 `nvn_sync_signal`） |
| Sampler | BuilderSetDefaults/SetDevice/SetMinMagFilter/SetWrapMode/SetLodBias/SetMaxAnisotropy/SetCompare/SetReductionFilter、Initialize/Finalize |
| Program | Initialize/Finalize/SetShaders |

几个关键判断：

- **`nvnDeviceGetProcAddress` 是整个图形层最关键的一个函数**：AGL 先用 `nvnBootstrapLoader` 取到它，
  再交给 main 里的 `nvnLoadCProcs` 去解析 461 个 NVN 函数。我们返回什么，游戏的每一次 NVN 调用就打到哪里。
- **`nvnMemoryPoolMap` 直接返回客体给的存储地址**（不需要拷贝、也不需要"映射"）：
  客体代码在本机原生执行，客体地址就是宿主地址 —— 这是"原生执行"路线相对模拟器的一处实打实的便宜
  （实测它是调用点最多的一个：122 处）。
- `Flush/InvalidateMappedRange` 是**空操作而不是"没实现"**：主机与 GPU 看到同一块内存。
- `nvnProgramSetShaders` 把控制段（Maxwell 着色器 blob）记下来并打印头 16 字节 —— Metal 重放层
  接上后按它去查那 18470 个已译好的着色器。

## 2.56 两条新学到的坑（都写进了代码注释）

1. **float 参数不在 x1 里，在 s0**：统一 8×u64 签名对 `nvnSamplerBuilderSetLodBias(builder, float)` 不成立。
   这类函数必须用真正的 `float` 形参写实现（表里仍旧按统一函数指针存，因为调用方是客体、按自己的约定传参）。
   自检里专门验了这条：`SetLodBias(1.5f)` 存进去的位模式必须是 `0x3FC00000`。
2. **sdk 自己导出 `nvnBootstrapLoader`**（0x2f05ec，184 字节）—— 它的实现要去和真 NVN 驱动
   （nvdrv 的 ioctl）说话，在 iOS 上那条路不通。装载器的解析顺序是「① 强制接管表 → ② 本模块 →
   ③ 别模块导出 → ④ 桩」，所以必须把名字放进接管清单（`gen_hle_force.py` 的 `EXPLICIT`）才能先接管。
   这一条已经写进 CI 检查（清单里没有它就红）。

## 2.57 自检（38 条断言，不需要游戏文件、不需要 Metal）

```
nvn_core_selftest：builder → Initialize → Map/GetAddress → Sync 超时/信号/自动复位
                   → 采样器 float 走 s0 → 类型检查 → ProgramSetShaders → 名字表整体  全部通过 ✅
nvn_selftest（接口层）：469 个名字都能按名取到、取不到返回 0、命令记录可用          全部通过 ✅
```

Makefile（`make -C smo/host test`）与 CI 都已接上；图形源文件也已进宿主构建
（`SRC` 增加 4 个 gfx 源 + `hle_nvn_reg.c`），macOS job 会编它。

---

# 第十六轮：着色器桥（运行时控制段 → 已译好的 18470 个着色器）

## 2.58 键的算法与索引

离线那轮（第七轮）用 `sha256(SPH+机器码) 前 16 位` 当**目录名**。运行时另外要一个能在 ~2 万条目里
不撞的 64 位键：**FNV-1a 64**，覆盖整个 blob（SPH 头 0x50 + 机器码）。宿主侧不需要加密码库。

- `smo/gfx/shader_index.py`：递归扫离线产物（`work/shaders_all/*/code_full.bin`）→ `work/shaders.idx`
  文本索引（`<fnv64>\t<stage>\t<sha256前16位>.metal`），带 `--check` 与 `--stats`。
  实测 **18470 条**：vs 2662 / ps 15805 / gs 3（与第七轮"18487 → 18470 去重"一致）。
- `smo/gfx/nvn/nvn_shader.c`：载入索引、精确查找、控制段查找。
- `smo/host/hle_nvn_reg.c`：宿主启动时载入（路径取 `SMO_SHADER_IDX`，否则工作目录 `shaders.idx`）。

## 2.59 控制段布局：先按归档槽试，再滑动扫描（并留证据）

已确认的是游戏归档里每个着色器槽的布局（`+0x00` marker `0x12345678` / `+0x30` SPH 0x50 /
`+0x80` 机器码，第七轮实测）。AGL 是把归档字节拷进控制段的，所以先按同一布局取；
取不到再按 8 字节对齐滑动扫描（控制段 ≤ 64 KiB 时）。**控制段的确切布局仍然没有真机证据**，
所以 `nvnProgramSetShaders` 会打印实际头 16 字节与大小 —— 真机日志一到就能把布局钉死，
然后把滑动扫描换成"按控制段给出的每段长度精确取"。

## 2.60 验证

```
shader_selftest（合成）：精确查找 / 长度不对查不到 / 归档槽布局 / 滑动扫描 / 太短的控制段   全部通过 ✅
shader_selftest work/shaders.idx <400 个真实 blob>：
    载入 18470 条；命中 400，未命中 0  → 「运行时算的键 == 离线算的键」被直接验证 ✅
```

最后一条是这一轮的关键：**它说明离线译出来的东西在运行时能被准确认回来**，
Metal 重放层接上后就是「SetShaders → 查键 → 取 MSL → 编 Metal 管线」这条直线。

---

# 第十七轮：iOS 三段内嵌出包（生成 + 本机可验证的校验）

## 2.61 契约（移植参考项目 dm/ios/tools/gen_embed.py，MIT）

iOS 真机不许运行时生成/改代码，所以客体映像在出包时就要拆三段编进签名段：

| 段/节 | 内容 | 权限 |
|---|---|---|
| `__TEXT,__dm<模块>x0` | 原代码 `[0, 圆整16K(TEXT_END))` | RX |
| `__DM<模块>W,__img` | ro 余部 + data + bss `[圆整16K(TEXT_END), PATCH_OFF)` | RW |
| `__TEXT,__dm<模块>x1` | 补丁区 `[PATCH_OFF, 圆整16K(文件尾))` | RX |

两条硬约束一起满足：苹果只允许**一个**执行段（ITMS-90999，所以两段代码都得进 `__TEXT`），
而 data/bss 必须可写（所以中间那段单独放可写段）。运行时装载器保留一段连续地址，
把三段按原相对位置重映射回去 → 运行时布局与原映像逐字节相同，PC 相对寻址、补丁区相对跳转、
宿主「基址 + 原偏移」的引用全都不用改。

## 2.62 本机可验证：把三段拼回原映像

`check_embed.py` 解析生成的 `.S`（`.section`/`.incbin`/`.space`），把每段字节拼出来，然后检查：

1. 每段的 sha256 与 manifest 一致（**拼回来的字节 == 原映像 + 补零**）
2. 同一模块三段首尾相接、无空洞、每段 16K 整数倍
3. 段名/节名 ≤ 16 字节（Mach-O 上限）、`PATCH_OFF`/键页 16K 对齐、键页落在 ro/data 段内

实测（真实产物）：

```
rtld 3 段 0x14000 / sdk 3 段 0xa64000 / subsdk0 3 段 0x708000 / main 3 段 0x25c8000   ✅
合成产物（CI）：sdk/main 各 3 段，同样通过 ✅
```

**检查器抓到我一次查错对象**：我最初检查 `.space` 的长度是不是页整数倍 —— 错的，
真正把节大小凑成页整数倍的是**节尾的 `.p2align 14`**。这条已写进注释。

## 2.63 接线与还差的一步

- `smo/ios/tools/gen_embed.py`：生成 `.S` + `<.S>.manifest.tsv`，打印链接参数（可写段的 `-segprot`）
- `smo/ios/shell_build.sh`：**本机有改写产物时**自动生成并校验（CI 没有游戏数据，会跳过并说明）
- CI：合成产物上跑生成 + 校验

还差的一步（明确写在这里）：把打印出来的 `-Wl,-segprot,__DM<模块>W,rw,rw` 接进 Xcode 链接，
以及 `loader_apple.c` 的 iOS 分支（`vm_allocate` 保留 + 三段 `mach_vm_remap` 回同一基址）。
两者都要在 macOS 上才算验完。

---

# 第十八轮：Metal 重放层的第一层（记账，本机可测）

## 2.64 这一层做什么

`nvn_replay.c` 把记录下来的 NVN 调用**重建**成「绘制计划」，**刻意不含任何 Metal 调用** ——
所以它能在本机测。做的是记账：

- 按调用名分类：绑定 / 设置 / 绘制 / 分派 / 清屏 / 拷贝 / 呈现 / 同步
- 每次绑定 program 都在宿主侧状态表里查对象；**查不到就报红**（说明游戏绑了没 Initialize 的对象，
  或我们的状态层漏了某个 Initialize —— 两种都必须当场暴露，不能拖到 Metal 层去猜）
- 每次绘制/分派记一条计划项：当时的 program、绘制类型与参数，以及**从控制段查出的着色器阶段**
  （`0xFFFF` = 查过索引但没命中；`0xFFFE` = 当时还没 SetShaders。两者必须分开，否则真机上看不出
   是"索引没载入"还是"顺序不对"）
- 记录与重放已接线：`nvn_record_call` 里直接喂给 `nvn_replay_call`

## 2.65 自检（13 条断言，不需要 Metal / 游戏文件）

```
replay_selftest：造出设备+程序+控制段 → 喂「绑定/设置/两次绘制/清屏/分派」
  ✅ 计划项 3 条、绘制 2 次、未解析 0
  ✅ 计划项带着当时的 program 与绘制参数
  ✅ 着色器未载入索引 → 阶段提示 0xFFFF（与 0xFFFE 区分开）
  ✅ 绑了没初始化过的 program → 计数抓 1 次 + 记下是哪个调用
```

## 2.66 下一步（Metal 那一半）

把计划项翻成 Metal：内存池 → `MTLBuffer`（注意 iOS 上 GPU 可见内存必须来自 IOKit/MTLBuffer，
客体地址不能直接给 GPU，所以这一步要拷贝或改用共享堆 —— 这是真机上最需要实测的地方）、
纹理块线性解交错、管线状态按（program, 着色器键）缓存、出图 → `CAMetalLayer`。
这部分的**逻辑**（资源映射表、管线键）仍然可以在本机用空后端测，只有真正调 Metal 的部分要 macOS。

---

# 第十九轮：收录 nvn.h 取枚举；重放层加管线键

## 2.67 nvn.h（h1k421，MIT）与枚举表

- `smo/gfx/nvn/include/nvn.h`：1756 行，从 Darksiders II 的 DWARF 重建的 NVN 类型，
  版权与许可声明原样保留；`include/README.md` 写明来源与**「只用枚举、不用它的结构体布局」**的理由
  （它是别的游戏重建的，版本未必与 SMO 一致；宿主状态全在宿主侧，客体对象是不透明句柄，不受影响）。
- `smo/gfx/nvn_enum.py` → `enums.tsv` + `enums.h`：抽出 **660 条**枚举值
  （`NVNformat` 158 / `NVNdeviceInfo` 99 / `blendAdvancedMode` 48 / `blendFunc` 20 / `logicOp` 17 /
  `drawPrimitive` 16 …），带 `--check`，CI 已接。

## 2.68 管线键（Metal 层要按它缓存管线状态）

`nvn_replay.c` 里加了「状态哈希」：绑定/设置类调用按顺序混进一个 FNV 哈希；
绘制时的**管线键 = 状态哈希 + 当前 program 的着色器键**。

为什么用混哈希而不是逐字段解析状态：字段语义要靠真机日志逐个确认，而**键只需要"状态变了键就变"**
这一个性质。混哈希现在就能用，且不会因为某个字段解析错而把两条不同状态的绘制悄悄合成一条管线
（那种 bug 在真机上表现为"偶尔画错"，极难定位）。

自检断言：两次绘制之间没改状态 → 键相同（可复用管线）；改一次深度模式再画 → 键变了。

**测试里我自己取错了索引**（拿第 2 项当"刚画的那次"，实际是之前的分派项）—— 已改成取最后一项。

---

# 第二十轮：按参考项目的致谢补齐我们的致谢，并记下三条可用线索

参考项目最近加了致谢（README 的 Acknowledgements）。照它的口径把我们**实际用到**的东西列进
`README.md` / `README.en.md`：参考项目本体（派生关系写在每个派生文件的文件头）、Ryujinx（原样收录）、
nvn.h（h1k421，只用枚举）、SPIRV-Cross、hactool（解包算法来源）、LLVM（反汇编）、Capstone、XcodeGen、.NET。

**透明起见照抄一条口径**：`port_rewriter.py` 里那批「让游戏离线可跑」的改写规则，参考项目注明来自社区的
**LFS Mod Offline Fix** 补丁，且没有可靠的原始出处记录 —— 我们沿用同一说明（原始出处同样不可考）。

## 2.69 从致谢里拿到的三条可用线索（已记进 STATUS 与 README）

1. **deko3d（devkitPro, zlib）**：参考项目的 `dm/gfx/nvn/nvn_tex.c` 的**纹理布局尺寸算法**移植自它。
   我们的纹理层还是记录桩，将来算块线性布局尺寸时照这条走（zlib 许可，可用）。
2. **bcdec（iOrange, MIT/Unlicense）**：参考项目用它**在设备不支持 BC 格式时解码 BC 贴图** ——
   苹果 GPU 不支持 BC（用 ASTC），所以 iOS 上这条是必需的，不是可选优化。
   这与我们 README 里「A16 及更早机型参考项目需要额外 ASTC 贴图包」那一档直接相关。
3. **Unicorn 做「改写前后等价性校验」**：参考项目在致谢里提到用 Unicorn 做改写的等价性检查。
   这条对我们的「每个结论都要有可复现证据」很有价值 —— 现在的改写验证是「断言原字节 + 逐条规则自检」，
   而等价性校验能进一步做到「同一输入下改写前后寄存器/内存效果一致」。**打算纳入**（见 2.70）。

## 2.70 下一步（把 Unicorn 等价性校验排进来）

用 Unicorn 跑 aarch64 的桩环境：给同一组寄存器/内存初值，分别执行「原指令序列」与「改写后的序列」，
比较末态。优先覆盖三类改写（它们的语义等价最难靠肉眼断定）：
- `svc #n` → 门调用（出参在 x0..x8，要按各 svc 的约定比）
- `mrs xN, cntpct_el0` → 计时器门（比较"是否只影响目标寄存器"）
- x18 跳转表 → 比较链分发（比较"是否到达同一目标地址"）

---

# 第二十一轮：动态等价性校验（Unicorn）—— 起了个头，标明半成品

参考项目的致谢里提到用 Unicorn 做改写的等价性检查。这条路对我们的"每个结论都要有可复现证据"很有价值：
改写器现在的自检是**静态**的（断言原字节、逐条规则的形式检查），静态检查证明不了"同一输入下效果一致"。

## 2.71 方法已定，工具半成品

`smo/tools/equiv_check.py`：用 Unicorn 把两侧都跑一遍，比较末态。

- **已经能跑**：原始一侧 —— 在站点执行原指令（`svc #n`），用**同一个效果模型**代替真正的 svc，
  快照 x0..x29（跳过 x18）与 SP，并确认续点是"原指令的下一条"。
- **还没跑通**：改写后一侧。站点是 `b <门块>`，门块在补丁区，最后通过字面量池里的地址 `blr` 到
  `dm_gate`；那个字段在**未重定位**的 patched.bin 里是 0，所以模型里要把"PC 跑到映像外"当成宿主边界。
  现在报 `UC_ERR_READ_UNMAPPED`，还没定位到是哪一条、哪个地址 —— 这是下次接着做的第一件事。
- 因此：**目前不引用这个工具的任何结论**，也**没有接进 CI / make test**（不让它假称已验证）。

比较项（已经想清楚，写进了文件头）：① 续点一致 ② x0..x29 一致（跳过 x18）③ SP 一致
（门块压栈/出栈不配平，在真机上就是返回时 SP 错位）。

## 2.72 这一轮试到哪儿（连带把"别重复走"记下来）

Unicorn 那条路在**改写后一侧**没跑通。已试三步、均无效：多映射 4 MB 空位；在地址 0 映射一页 `ret`；
注册 `UC_HOOK_MEM_FETCH_UNMAPPED` 现场补页让它重试（钩子确实注册上了，仍抛 FETCH_UNMAPPED）。

下一步按信息量排序（写进了 `equiv_check.py` 的文件头，下次不必重新摸索）：

- **a. 先定位而不是先建模**：把站点 0xa9c10 那条 `b` 的目标算出来 → 门块在哪 → 把门块反汇编出来 →
  找到那条 `blr`/`br` 及其操作数来源（字面量池地址与内容），确认"跳到哪里、为什么未映射"。
  这一步**纯反汇编**，`smo/tools/rawdis.py` 就够，不需要 Unicorn。
- **b. 再决定建模方式**：要么在钩子里接管（设置 PC，不依赖重试），要么把 `dm_gate` 的桩地址直接写进映像 ——
  后者更接近装载后的真实情况，也更能验门块本身。

工具仍标半成品，不接 CI、不引用其结论。

## 2.73 动态等价性校验跑通了（这一轮的实打实成果）

定位到的原因（**先反汇编定位、再建模**，这一步做对了）：站点是 `b <门块>`，门块长这样——

```
stp x29, x30, [sp, #-0x10]!
mrs x30, tpidrro_el0            ; 线程指针
adrp x29, #<键页> ; ldr x29, [x29, #0x18]
add x30, x30, x29 ; ldr x30, [x30]     ; 取宿主门入口指针
ldr x29, [sp] ; blr x30
ldp x29, x30, [sp], #0x10 ; b <原指令的下一条>
```

**为什么之前一直失败**：仿真里 `TPIDRRO_EL0 = 0`、键页槽里是 0 ⇒ `ldr` 把地址 0 的内容（我写的 `ret` 字节
`0xD65F03C0`）当成了函数指针 ⇒ 跳到 `0xD65F03C0`。建模方式改为：**在键页槽里填 Q，在 SENT 处放 `ret`、
Q 处放指向 SENT 的指针** —— 这正是真实装载时"宿主把 `dm_gate` 的地址填进线程槽"那一步。
另外还踩了一个：**映像映射在 BASE 上，写键页槽必须写 `BASE + vaddr`**（裸 vaddr 白折腾一轮）。

还有一个必须做对的地方：**svc 号两边要取自同一张「站点 → svc 号」表**（对应真实 `dm_gate` 用返回点当门标识
去查表）。第一版我原侧传真实 svc 号、新侧传 0，于是 5 个站点"不等价"—— 那是在比较我的模型，不是改写。

结果：

```
sdk  106/106 个 svc 站点：续点一致、x0..x29（除 x18）一致、SP 一致   ✅
rtld   4/4                                                          ✅
main / subsdk0：没有裸 svc（都经 sdk 的 nn::os 包装），故无站点
```

这条把 svc 改写的验证从"静态断言"提升到"**同一输入下效果一致**"。当时未覆盖的 `kind=cntpct`
需要先解析原 `mrs` 的目标寄存器（x20/x21/x23 等，不在 x0..x8 里）—— 在下面 2.74 做掉了。
工具不进 CI（需要真实产物），`make -C smo/host equiv` 跑。

## 2.74 cntpct（计时器）那一类也进了等价性校验

`gates.tsv` 的格式现在确认了：`门块地址 \t 类型 \t 目标寄存器 \t 站点`，且第 4 列与 `sites.tsv` 逐条对得上
（交叉核对过）。所以 cntpct 站点的目标寄存器可以直接取，不需要猜。

要补的两点：

1. **原侧的 `mrs xN, cntpct_el0` 也必须走模型** —— 否则比的是 Unicorn 自己的计数器，两次运行之间不确定，
   等于拿噪声在比。模型两边一致：把确定值写进目标寄存器。
2. **顺手交叉核对改写器的表**：`gates.tsv` 记的目标寄存器必须与指令里的 `Rd` 一致（断言）

踩的坑（第三次被同一类事绊到，所以写在这里）：**capstone 的 arm64 寄存器枚举不是从 X0 连续编号**，
`operands[0].reg - UC_ARM64_REG_X0` 会算出 `x40` 这种胡说 —— 要用 `reg_name()` 解析名字。

结果：

```
sdk  29/29 个 cntpct 站点等价 ✅（续点一致、x0..x29 除 x18 一致、SP 一致）
```

至此改写器两类站点都有动态等价证据：**svc 106/106**、**cntpct 29/29**（+ rtld svc 4/4）。
剩下 x18 跳转表那一类比较方式不同（要比"是否到达同一目标地址"而不是比寄存器），下次做。

---

# 第十八轮：补上 `verify/` 这一层 + 验证一条我们独有的设计前提

## 2.75 为什么这一轮做验证层而不是继续堆功能

对照参考项目时发现一处**结构性缺口**：它把验证独立成 `dm/verify/`（等价性 + 逐拍对拍 +
FLIP 截图闸门 + `regress.sh` 总入口），本仓只有散落在 `smo/tools/` 里的等价性那一项。

剩下最大的一块是 Metal 重放（参考项目 `nvn_mtl.m` 有 626 KB）。在**没有回归闸门**的情况下
往里堆代码，出了图像错误会无从二分 —— 所以先把入口立起来，Metal 的两项先占位。

## 2.76 `smo/verify/regress.sh`：一条命令跑完所有能跑的

分两档：不需要游戏文件的（CI 每次跑）、需要改写产物的（本机有产物才跑，缺了自动 SKIP）。
失败不提前退出 —— 一次看清所有坏掉的地方；退出码 = 失败项数。

本机实测：

```
通过 12 · 失败 0 · 跳过 2
  跳过：逐拍对拍、截图闸门（两项都等 Metal）
```

（本机要先 `source smo/env.sh`，否则找不到 `/c/toolchain` 里的 gcc 与 mingw32-make，
C 单测会 SKIP —— 下面 2.81 记了这条探测本身踩的坑。）

（顺手验证过失败路径确实会报错并返回非 0 —— 一个不会失败的回归脚本等于没有。）

## 2.77 验证「NVN 对象不透明」这条前提（2.54 的设计选择，一直没有证据）

2.54 定下的设计：宿主状态全放在宿主侧，**客体的 NVN 对象当不透明句柄、一字节不写**。
这比参考项目（直接用 h1k421 的 nvn.h 布局）更稳。但它隐含一条前提一直没验：

> **客体（AGL）自己也不直接读 NVN 对象里的字段。**

如果 AGL 某处绕过 getter 直接 `ldr w9,[x0,#0x18]` 读对象成员，宿主侧状态表就填不到它，
游戏会读到未初始化的客体内存。这条前提此前只是推理。

`smo/verify/nvn_opaque_check.py` 在 `main.bin` 上找这种裸访问。实测：

```
NVN 调用点 1706 处，涉及 460 个名字
已检查 1012/1706（59%）= 寄存器直传 755 + 内嵌子对象 257
  跳过 320 处栈上临时对象（AGL 自己的 builder，与本前提无关）
  跳过 374 处指针从内存取出、基址表达式追不动的   ← 盲区，如实计入
带偏移访问 733 条：fetch 14 · before 663 · outside 56 · INSIDE 0
```

**0 条反例。** 其中 663 条 `before` 是最有说服力的那部分：NVN 对象大量以**内嵌子对象**
形式待在 AGL 的大对象里（`add x0, x19, #0x48` 这种形状，257 处），AGL 读的是它自己在
NVN 对象**之前**的字段 —— 这正是「把 NVN 对象当不透明块、自己的状态放旁边」的样子。

对象大小取自 `nvn.h` 的 `char reserved[N]`。**只**拿它当分流尺度（判断偏移是否落在对象外），
没有用它的字段布局 —— 2.54 那条红线仍在。

## 2.78 这一轮的方法教训：先怀疑自己的工具，再怀疑结论

第一版报出 35 条候选、3 条判定为"读对象内部"。**全是假阳性**，三个不同的原因：

1. **偏移 0 算成读字段** —— 那是解引用指针本身，不是读成员。
2. **`add x0, x22, #0x48` 之前的 `x0` 是另一个值**。第一版遇到这种就整个跳过，
   覆盖率只有 42%，还把噪声算进了结论。改成识别成"内嵌子对象 + 基准偏移"，
   覆盖率升到 59%，同时 663 条访问得到了正确解释（`before` 而不是误报）。
3. **基址寄存器在窗口里被重新定义**（`ldr x23,[x8]`），之前的访问针对旧值 ——
   实测 `0xa0b9b4` 那处，是最后一个消掉的 INSIDE。

每一条都写进了代码注释与自检用例。**报 0 之前先确认工具能报非 0** ——
`nvn_opaque_selftest.py` 用手工编码的 aarch64 指令序列喂进去，12 个用例 / 16 条断言，
其中第一条就是"真正读 NVN 对象内部必须判成 INSIDE"。这一项进了 CI（不需要游戏文件）。

## 2.79 结论的边界（写清楚，免得下次自己过度解读）

这是**局部窗口分析**，不是全程数据流。所以结论只能是「**在已检查的 1012 处没有发现反例**」，
不是「证明不存在」。两个明确盲区：那 374 处追不动的调用点；以及对象指针被存进 AGL 成员、
过很久在别的函数里再解引用的情况。

**终局判据是真机**：`nvn_state.c` 查不到就记一行 miss 日志，跑一遍就知道有没有漏。

## 2.80 回归入口立起来当场抓到的问题：CI 从 10-14 起就是红的，只是没人看

把 `make -C smo/host test` 接进 `regress.sh` 之后第一次在本机跑完整 C 单测，9 个目标里
有 2 个**链不上**：

```
hle_nvn.c: undefined reference to `nvn_replay_call'
```

原因：`nvn_iface_selftest` / `nvn_selftest` / `shader_selftest` / `replay_selftest` 四个目标
**各抄了一份源文件清单**。第十六轮加重放层时，`hle_nvn.c` 里多了一处 `nvn_replay_call`，
只有 `replay_selftest` 的清单跟着加了 `nvn_replay.c` —— 另外三个从那天起就坏了。

**CI 为什么也没发现**：CI 没走 Makefile，它在 workflow 里**又手写了一遍** gcc 命令行，
同样漏了 `nvn_replay.c`。所以 `.github/workflows` 和 `Makefile` 各有一份会漂移的清单,
两份都不准 —— 而进度表上写着"CI 双绿"。（实测复现了 CI 那条命令，确实同样挂。）

两处都改掉：

- `Makefile` 把共同依赖收进 `GFX_COMMON`，四个目标共用，配方用 `$^` —— 清单只有一份。
- workflow 里 9 个手写 gcc 步骤换成一条 `make -C smo/host test`，本机与 CI 跑同一条命令。
- 顺带修了 `make test` 里 `work/synthetic` 的路径（make 在 `smo/host` 里跑，要 `../..`），
  并加了合成产物的生成规则 —— 以前这个目标只能在 CI 的目录布局下跑。

本机现在：**通过 12 · 失败 0 · 跳过 2**（C 单测 172 条断言全过）。

这一条正好说明为什么要先立回归入口再写 Metal：一个没人跑的检查等于不存在，
而"各处抄一份清单"在加新文件时必然漂移。

## 2.81 一个探测写法上的坑：别用 `-o /dev/null` 判断编译器可用

`regress.sh` 要决定"本机有没有能用的编译器"。第一版用 `command -v clang`，
结果 `smo/env.sh` 把 LLVM 的 bin 放在 mingw64 之前，于是先找到的 `clang` 没有 C 运行时头
（`#include <stdio.h>` 直接 fatal error），C 单测被判成 FAIL 而不是 SKIP。

改成"真的编一个最小程序试试"。但 `-o /dev/null` 在 mingw 下会

```
ld.exe: final link failed: file truncated
```

—— 把一个好编译器误判成不可用。必须写到真实临时文件。两个坑都写进了脚本注释。

## 2.82 下一步

| # | 任务 | 为什么是它 |
|---|---|---|
| 1 | **macOS 目标**（`front_mac.m` + `mac_app.sh`） | 参考项目用它迭代图形层：开调试器跑 Metal 比每次往 iPhone 签包快一个数量级，**而且不需要开发者账号**。Metal 那一半本来就卡在"需要 macOS"，这是解锁它的最短路径，不是额外工作 |
| 2 | 收第三方：**deko3d**（zlib，纹理块线性布局尺寸算法）、**bcdec**（MIT，苹果 GPU 不支持 BC，必需不是优化） | Metal 纹理上传的前置 |
| 3 | Metal 重放 | 剩下最大的一块 |
| 4 | x18 跳转表那一类的动态等价 | 比较方式不同（比"是否到达同一目标地址"而非比寄存器） |

---

# 第十九轮：纹理块线性布局（Metal 的硬前置，本机就能验到底）

## 2.83 先量清楚：游戏到底用了哪些贴图格式

纹理层要做多少工作，取决于游戏**实际**用了什么。NVN 声明了 158 个 `NVNformat`，
一个游戏只会用其中一小撮 —— 不能靠猜。

贴图在哪（实测挖出来的链路）：

```
RomFS/**/*.szs → Yaz0 → SARC → *.bfres（magic FRES，v8）→ 内嵌 BNTX → BRTI（每张贴图）
```

并非每个 `.bfres` 都有 BNTX（只带模型/骨骼的就没有）。`smo/gfx/tools/bntx_survey.py`
抽样 200 个 `.szs`（87 个带 BNTX，967 张贴图）：

```
BC4/UNORM   343  35.5%        block height（log2，GOB 为单位）
BC1/SRGB    289  29.9%          2^0= 1 GOB:  20
BC5/SNORM   245  25.3%          2^1= 2 GOB:  28
BC3/SRGB     39   4.0%          2^2= 4 GOB: 143
BC3/UNORM    24   2.5%          2^3= 8 GOB: 293
ASTC_4x4     19   2.0%          2^4=16 GOB: 483
RGBA8/SRGB    6   0.6%
BC5/UNORM     2   0.2%        tile mode: 全部 0（块线性）；维度：全部 2D
```

**两条结论直接决定了工作量**：

1. **BC 占 97.4%**。苹果 GPU 不支持 BC（它用 ASTC），所以 **bcdec 是必需项，不是优化** ——
   这一条以前只是从参考项目抄来的说法，现在有了自己的实测数字。
2. **block height 五档全都出现**（1/2/4/8/16 GOB）。所以尺寸算法里 `adjustTileSize`
   那套「mip 变小时档位跟着降」的逻辑必须照搬，不能简化成固定档位。

## 2.84 `nvn_tex.c`：尺寸算法移植自 deko3d，GOB 公式另有出处

尺寸部分逐函数对位 deko3d 的 `source/dk_image.cpp`（zlib，只移植算法、不收录源码，
出处与 zlib 义务写在文件头与 `smo/third_party/README.md`）：

| deko3d | 本仓 |
|---|---|
| `pickTileSize` / `adjustTileSize` | `tex_pick_tile_size` / `tex_adjust_tile_size` |
| `adjustMipSize` / `adjustBlockSize` | `tex_mip_size` / `tex_div_ceil` |
| `alignLayerSize` | `tex_align_layer_size` |
| `DkImageLayout::calcLevelOffset` | `nvn_tex_level_offset` |

**deko3d 里没有的那一块**：GOB 内部 512 字节的重排公式。deko3d 不需要它 ——
它把解交错交给 GPU（走 2D 引擎的 `dkCmdBufCopyImage`）。我们要在 CPU 侧解
（Metal 只认行优先），所以公式取自 BNTX-Extractor 的 `swizzle.py`。

GOB 的几何：**64 字节宽 × 8 行 = 512 字节**，内部位域是

```
+256 ← x 的 bit5    +64×(0..3) ← y 的 bit1..2    +32 ← x 的 bit4
+16  ← y 的 bit0    +0..15     ← x 的 bit0..3
```

## 2.85 单测：不拿实现验自己

36 条断言（`smo/gfx/nvn/tests/tex_selftest.c`，纯算术、不需要游戏文件与 Metal）。
判据刻意选的是**独立性质**，而不是「和实现一致」那种同义反复：

1. **GOB 内偏移必须是 0..511 的双射** —— 512 个 `(x,y)` 一一映射到 512 个字节，不重不漏。
   这一条能抓住任何位域写错：漏一位必然碰撞，多一位必然越界。再配几个手算定点
   （`(32,0)→256`、`(63,7)→511`）防住"整体平移"这种能保持双射的错误。
2. **块线性地址与独立实现逐点一致** —— 测试里**另写一遍** `getAddrBlockLinear`
   作对照（不复用被测函数），10560 个坐标全对。
3. **解交错可逆** —— 按公式填入、再解出来，必须等于行优先原图；带 stride 的也测。
4. **边界：宁可不解，也不越界读客体内存** —— 源不够/目标不够/空指针一律返回 0，不写半张。

抓到一个真 bug：`tex_mip_size(128, 99)` 返回 16 而不是 1。C 里对 u32 右移 >= 32 位是
**未定义行为**（x86 实际按 `level % 32` 移）。deko3d 不会遇到是因为它的 mip 数受
`DkImageMaker` 校验，而我们的 mip 数来自客体 —— 一个坏值不该变成未定义行为。加了护栏。

## 2.86 最硬的判据：拿游戏自己的贴图核对

单测只能证明算法**自洽**，证明不了「算出来的大小和 Nintendo 工具链算的一样」。
后者需要真实数据，而 BNTX 正好记着答案：每个 BRTI 块里有这张贴图**实际占用的字节数**
（打包工具按真实布局算出来写进去的）。

`smo/gfx/tools/tex_layout_check.py` 把 `nvn_tex.c` 编成动态库、用 ctypes 直接调
（测的就是会进包的那份 C 代码，不是在 Python 里重写一遍），逐张比。抽样 40 个归档：

```
对上 123/123（100.0%），不一致 0
```

**找对字段的过程值得记**：一开始取 `+0x20`，结果所有样本都"差 +177120"这种离谱的量 ——
这种全体偏差反而是好信号，说明不是算法错而是**取错字段**（真算法错会散落在特定形状上）。
逐字段 dump 一遍，`+0x50` 处是 `0x3400` = 13312，正是我们算的 128×128 BC1/mips=8 的大小。
改过来之后 123/123 全中。

这是本机能做到的最强验证：**不需要 Metal、不需要真机**，却证明了尺寸算法与真机一致。
已接进 `regress.sh`（抽样 150 个归档；`--all` 可跑全量）。

## 2.87 下一步（纹理层）

| # | 任务 | 依赖 |
|---|---|---|
| 1 | 收 bcdec，把 BC 块解成 RGBA | 本机可做可测（有 BC 测试向量） |
| 2 | `nvnTexture*` / `nvnTextureBuilder*` 家族从记录桩换成真实现 | 本轮的布局算法 |
| 3 | Metal 上传（零拷贝 MTLBuffer / 块线性解交错后上传） | 需要 macOS |

---

# 第二十二轮：没有 Mac 怎么办 —— CI runner 上有可用 Metal（关键分岔已闭合）

## 2.84 探测结果

`smo/ios/tools/metal_probe.m`（装进 macOS job，编译宿主前跑）：

```
[notice] 设备可用：Apple Paravirtual device
[notice] 回读像素 = (255,0,0,255)，期望 (255,0,0,255)
[notice] 离屏渲染 + 回读在 CI runner 上可用 —— Metal 层可以在 CI 上验
```

三条结论：① runner 有虚拟 GPU；② 离屏渲染 + 回读真实可用（不是碰巧）；③ runner 是 arm64 macOS。

**这对"只有 iPhone、没有 Mac"意味着什么**：Metal 重放层的开发验证完全可以在 CI 上做
（编译靠 runner 的 Xcode SDK，正确性靠离屏渲染回读断言，结果走公开可读的注解通道）。
iPhone 只负责最后的两件事：`CAMetalLayer` 呈现与触屏 —— 那是收尾，不是开发路径。

## 2.85 更新后的路线（按顺序）

1. BC 解码链路（bcdec 移植 + 接上 nvn_tex.c 的块线性解交错，真实贴图逐张验证）—— 本机可验
2. Metal 层骨架：资源映射 + 上传 + 管线缓存 —— 逻辑本机验、Metal 调用 CI 验（离屏回读）
3. 第一个 CI 离屏像素测试：拿真实游戏贴图 → 解交错 → 解 BC → 上传 MTLTexture → 画全屏四边形
   → 回读 → 与本机 CPU 路径的 RGBA 逐像素一致 —— 这一条打通，"纹理路径正确"就有了
   跨实现（CPU vs GPU）的独立证据
4. iOS 内嵌装载分支（vm_allocate + mach_vm_remap）—— macOS 上可跑，CI 可验
5. App 加「真机自检模式」（启动跑 arm64 单测、结果显示在屏幕上、可存 Files）
6. 真机首跑 → UNIMPL 日志驱动补服务

---

# 第二十三轮：A3 —— 纹理**内容**核对（1235 张真实贴图 vs 两个独立实现）

## 2.86 判据的选择过程（每一步都是实测逼出来的）

1. texture2ddecoder（pip）看似独立 —— 实测发现它的 BC 内核**就是 bcdec 的另一修订版**
   （常量不同，输出与我们差 ±1）→ 不能当独立判据，弃用。
2. 决定按 **D3D BC 规范**自己写参考解码器（`smo/gfx/tools/bc_spec_ref.py`，自带 7 条自检，
   期望值全部手算）。过程中**我两次读错规范**，都是自检抓出来的：
   - 565→888 扩展是**位复制**（v<<3|v>>2），不是除法取整；
   - BC1 插值在**扩展后的 8 位空间**做整数平均（(2·c0exp+c1exp+1)//3），不是先插值后扩展
     （后者把 r0=31,r1=0 的 2/3 色错算成 173，规范是 170）。
3. bcdec 与规范参考的差异实测校准：**全部 ≤1/255**，只出现在插值产生的字节
   （bcdec 的插值权重表是 65536 截断近似、565→888 用魔数近似位复制）。
   早先以为"BC4/BC5 应逐字节一致"是抽样没撞上不一致的组合，不是事实 —— 已更正。

## 2.87 结果（每张贴图 mip0 逐字节比）

```
抽样 300 个 .szs（种子 7）→ 1235 张贴图，不一致 0 张 ✅
  解交错级：与 BNTX-Extractor 的 deswizzle **逐字节一致**（全 1235 张）
  解码级：  BC4 413 张逐字节、BC5 338 张逐字节、BC1 16 张逐字节
            BC1 421 张 / BC3 47 张：端点逐字节，插值字节全部 ≤1（计数 5663 万字节）
```

BRTI 解析时踩的坑（写进代码注释）：0x10 字节是 **tileMode**（1=块线性，判据口径 0=线性）；
数据指针表在 +0x70（q @ ptrsAddr + i*8）、大小在 +0x50；判据输出按 surfSize 对齐、只比有效前缀；
Git Bash 的 /tmp 与 Windows 版 Python 看到的不是同一目录（判据路径用 tempfile.gettempdir()）。

CI 新增：bc_spec_ref 自检（判据必须先证明自己对）。

## 2.88 A4 完成：格式矩阵收口（1294 张、0 不一致）

实测这个游戏只有 6 种贴图格式（`bntx_survey.py` 400 归档/1785 张的分布）：BC4 32.4%、
BC1 30.1%、BC5 25.5%、BC3 9.8%、ASTC_4x4 1.1%、RGBA8 0.9% —— **BC2 / BC6H / BC7 一张都没有**，
所以不需要为它们写参考解码器（这是实测结论，不是省略）。

新增「只解交错不解码」路径（`nvn_texread.c`）：块 > 1×1 的非 BC 格式（ASTC 等）只做块线性 → 行优先，
苹果 GPU 原生支持 ASTC，Metal 层直接上传线性块；未压缩（块 = 1×1）走原路径。

```
300 个 .szs → 1294 张贴图，不一致 0 张 ✅
  BC1 16 逐字节 + 421 插值 ≤1 ；BC3 47 ≤1 ；BC4 413 逐字节 ；BC5 338 逐字节
  ASTC_4x4 53 逐字节 ；RGBA8 6 逐字节
```

**那 6 张 RGBA8 的"不一致"最后证明是我工具里的参数错，不是我们的 C 错**：判据调用里把压缩块尺寸
硬编码成 4×4（对 BC/ASTC 正确），而 RGBA8 是 1×1 → 判据拿它当 4×4 块解。
指纹很清楚：只有 RGBA8 失败、BC/ASTC 全过。定位过程（记录一下，省下次再踩）：
先把 TRM 的 `getAddrBlockLinear` 与我们的映射**全量 4096 个 texel 逐一对**（0 不一致）
→ 说明映射没问题 → 再看判据自己 `swizzle(deswizzle(x)) != 源`（判据自身不自洽也是线索）
→ 检查调用参数 → 发现块尺寸写死。

---

# 第二十四轮：M1 内嵌装载分支落地（CI 可验），顺手挖出两个真机必崩的宿主 bug

## 2.89 内嵌装载路径在 macOS 上全链路验证

`embed_selftest`（分段执行 step 1..6，CI 逐段跑、逐段注解）：

```
step 1 内嵌表查找            ✅（按名查到、查不到返回 NULL）
step 2 三段映射              ✅（mach_vm_remap：两段代码共享签名页 + 一段写时复制）
step 3 映像与三段逐字节相同   ✅
step 4 可写段真能写（COW）    ✅
step 5 装载器不读任何文件装起来 ✅（目录故意不存在 —— 这就是 iOS 能工作的关键）
step 6 键页 8 槽非 0          ✅
```

`loader_core` 优先查内嵌表：命中则**完全不读文件与 tsv**（布局、门、键页槽都来自生成的内嵌表）。

## 2.90 过程中挖出的两个真机必崩 bug（都是这条新路径第一次真跑才暴露的）

1. **tsd_check 空指针**：`host_thread_keys_create()` 在 `load_modules()` 之前调，而 tsd_check 去读
   `g_mod[0]` 的键页 —— 那时 base 是 NULL。改成用键号本身算偏移（等价），不再依赖装载顺序。
   这条路从来没被执行过（smo_host 只编不跑），所以一直没暴露。
2. **可写区被误设成 RX + 边界页问题**：
   - 老代码 `dm_code_protect(base, patch_off)` 把整个 ro+data 设成 RX —— 重定位一写就 SIGBUS；
   - `TEXT_END` 不页对齐时，**代码尾与「TEXT_END 到页边界的缝隙」同页**，而缝隙里可能有重定位槽
     （实测 **rtld 的 30 条重定位全在缝隙里**；sdk/main/subsdk0 都是 0）。
     正确设计：x0 尾**向下**取整（缝隙进 W），边界页 RWX（代码尾要执行、缝隙要写）。
     文件路径与内嵌路径都按这个改。

排障方法论的产出（写进代码注释与 CI）：分段执行（一次 CI 定位到节）、退出码注解
（138=SIGBUS 直接指向"写只读页"）、CHK 里 flush（缓冲会吞掉崩溃前的输出）、
Mach-O 弱符号不可靠（数据与函数的 weak/weak_import 都被 ld64 拒绝 → 用显式宏开关 SMO_EMBED）。

## 2.91 M1 剩余

- 内嵌 .S/.c 接进 iOS App 构建 + `-segprot` 接 Xcode 链接（shell_build.sh 已留可选路径）
- App 内日志上屏 + RomFS 从「文件」App 导入
- 初始化路径所需服务（settings / applet / am 等）

## 2.92 M2 第一片：Metal 重放层的最小闭环（CI 离屏可验）

`nvn_mtl.h/.m`：`nvn_mtl_init`（默认设备+队列）、`nvn_mtl_offscreen_clear`（离屏清色 → 回读）。
这一片把「编译（macOS SDK）→ 离屏渲染 → 回读像素 → 断言」的循环打通 —— 之后每个计划项翻译
（绑定/绘制/呈现）都按同一形状验证。自检：红/绿/蓝/半红（0.5 → 128 量化）逐字节 + 参数防御。

排障记：ARC 下写显式 `release` 会编译错（"release is unavailable in ARC mode"）—— 第一次 CI 就是它；
编译错误也要进注解（原步骤只有运行错误进注解）。

本轮结束时 CI 全绿：ubuntu（13 项）+ macOS（Metal 第一片、embed 自检 1-6、逐个 C 单测 11 项、
smo_host 编译链接、出未签名 IPA）。

## 2.93 M2 第二片：着色器管线路径（内置 MSL → 管线状态 → draw → uniform → 回读）

`nvn_mtl_offscreen_draw`：`newLibraryWithSource`（Metal 编译器）→ vs/fs 入口函数 → 管线状态 →
全屏三角形（vertex_id 法，无需顶点缓冲）→ 片段 uniform 传色 → 回读。自检红/绿/蓝/半红逐字节 +
参数防御。

**关键结论**：CI runner（Apple Paravirtual）上**着色器编译可用** —— 这意味着 18470 个已译 MSL
都能走「CI 离屏渲染 + 回读 + 断言」的验证循环，M2/M3 的验证方式已经打通。

坑（又踩一次）：heredoc 把 `\n` 吃成真换行，MSL 字符串散架 —— 用 edit 工具重写转义序列。

## 2.94 M2 合龙点：合成命令流 → 真实状态层 → 记录层 → Metal 帧 → 回读

`nvn_mtl_replay_frame`（清屏 + 每个绘制项按**管线键**着色全屏三角形）+ `mtl_replay_selftest`：
用真实状态层造设备/程序/控制段，用记录层录「BindProgram → ClearColor → Draw → SetDepthMode → Draw」，
两个绘制项的管线键不同（状态变了）→ Metal 帧 → 回读 == 第二个键色（覆盖语义正确）→ 单绘制项帧
回读 == 第一个键色（清屏被盖）。CI 全绿。

**这条链绿了，「记录 → 计划 → Metal」的管道成立**；真实参数的翻译（ClearColor 参数解析、真实
顶点/索引缓冲、纹理绑定）在之后逐块接入，每块都用同一条验证循环。

排障/教训（本轮）：
- `nvn_replay_item/_key` 只定义没声明 → 合龙点测试隐式声明 → clang -Werror 失败。已移进 nvn_host.h，
  旧 replay_selftest 的镜像结构改用公共 nvn_draw_item
- **工作流重复键**：一次替换只锚定了步骤名，旧 `run:` 块残留在后 → GitHub 拒绝整个工作流
  （run 显示 failure 且 jobs=0，pyyaml 却静默通过 —— 这种"解析器不一致"最坑）。
  以后工作流改动后必须跑重复键检查（python yaml 构造器钩子）
- CI 的分段循环曾只打注解不设 fail —— job 绿了但段挂了。已修：失败计入 fail
- `-DSMO_EMBED` 在 Makefile 链接行里丢失过一次（字符串替换没命中）→ 表查找变 NULL。已修

## 2.95 M2 继续：纹理上传往返 + 管线缓存

- `nvn_mtl_offscreen_texture`：上传 RGBA → 最近邻采样画全屏 → 回读与输入**逐字节相同**（含 alpha=0 像素）。
  CPU 纹理链 → GPU 的交接验证成立。
- `nvn_mtl_replay_frame_multi` + 管线缓存（ctx 里按 prog id 缓存）：
  同 prog 复用（缓存数不增）、异 prog 新建（0=纯色 / 1=纹理采样）、prog1 输出与纹理输入逐字节一致。
  验证的是真机上「按管线键缓存」的核心性质（iPhone 上编管线很贵，复用必须可证）。
- CI 全绿（macOS：Metal 各片 + 合龙点 + embed 1-6 + 11 个 C 单测 + 宿主 + IPA）。

## 2.96 M1 App 侧完成（日志上屏 + RomFS 解析接入，与宿主同一份代码）

- logbuf.c/h：LOG 走环形缓冲（512 行）+ stderr；romfs_resolve.c/h：Documents 下找 RomFS/ExeFS
  （直接放或一层包装目录）。applogic_selftest 12 条断言（CI 双平台）。
- main.m：进度表更新为真实状态；RecentLog 显示日志缓冲；ScanDocuments 增补宿主同款解析的路径行。
- **接入 App 的坑（二分定位）**：两个 C 源一次加进 xcodegen 目标 + main.m 用 `../host/` 相对 include
  → ScanDependencies 失败且无 error: 行。二分：逐个加 C 源都过 → 真凶是相对 include；
  改用 `HEADER_SEARCH_PATHS: $(SRCROOT)/../host` + 裸头名。
- 至此 M1 只剩「初始化路径所需服务」（settings/applet/am 等）—— 它们的真实语义要真机日志定，
  本地写死没有依据；继续按计划进入 M2 主体。

## 2.97 宿主 bootstrap 接进 App（CI 编译验证）；vm_* 修复 iOS 构建

- main.m：RunHost（后台线程）＝ host_thread_keys_create → load_modules(rtld/sdk/subsdk0/main)
  → run_module_inits → svc_thread_main_init → guest_thread_init → dm_jump_guest(nnMain)；
  状态页加「宿主日志」区 + 每秒定时刷新
- project.yml：宿主全部源（除 main.c）+ 图形层 C 源 + entry.S 编进 App；头路径补 gfx/nvn
- **iOS SDK 没有 mach_vm_\***（mach/mach_vm.h 直接标 unsupported）→ dm_embed_map 换成
  vm_allocate/vm_remap（旧 API，macOS/iOS 都有；macOS CI 继续验同一路径）
- 第一跑的真机路径还差最后一块：**guest dylib**（参考项目的 DM_SHELL 机制 —— CI 壳不含游戏内容，
  使用者在本机用脚本把改写产物打包成只装段的 dylib 放进 App，装载器 dlopen 后 vm_remap）

## 2.98 首跑最后一块：guest dylib（壳模式）+ 日志导出按钮

- `smo/ios/tools/guest_dylib.py`（移植参考项目，MIT）：在本机把 work/rewrite 打包成
  `Guest.framework/Guest`（只装三段的 arm64 动态库，纯 Python 写 Mach-O，Windows 也能跑）。
  生成物已验证：magic 0xfeedfacf、段/节名齐全。x0 尾向下取整（与 gen_embed 同口径，rtld 缝隙不落 RX）
- loader_apple.c：`dm_image_from_dylib`（iOS 壳模式）：dlopen Guest.framework → getsectiondata 三段 →
  vm_remap 回连续地址（代码共享签名页 RX、W 写时复制 RW、边界页 RWX）。macOS 返回 NULL（走文件路径）
- loader_core.c：文件路径先试 dylib（tsv 仍由用户随包提供 —— 布局与门表不在 dylib 里）
- main.m：**导出日志按钮** —— 一键把「状态+游戏文件+宿主日志」存成 SMO-log-<时间>.txt +
  固定名 SMO-log-latest.txt，并拉起系统分享（AirDrop/邮件/存文件）
- 用户首跑流程（全链条）：本机跑 guest_dylib.py → 解压 IPA 放入 Frameworks/Guest.framework →
  重打包 → Sideloadly 签名 → 文件 App 放 RomFS + 各 .tsv → 打开 App → 日志滚动 → 导出日志发回

## 2.99 首跑链路完整（代码层面）+ 日志导出按钮

- 日志导出按钮：一键存 SMO-log-<时间>.txt + SMO-log-latest.txt（Documents，文件 App 可见）并拉起系统分享
- guest dylib 壳模式 + 宿主 bootstrap 全部就绪，App 构建绿（CI）
- 首跑全链条（用户侧）：guest_dylib.py → 放 Frameworks + RomFS + tsv → Sideloadly 签名 → 打开 → 日志滚 → 导出日志发回
- 发 v0.2.0 release（含导出按钮）


---

# 第二十五轮：M1 收尾（App 接入 + 首跑链路）与资源容器

## 2.100 宿主接入 App（CI 编译验证）

`main.m` 的 `RunHost`（后台线程）：`host_thread_keys_create` → `load_modules(rtld/sdk/subsdk0/main)`
→ `run_module_inits` → `svc_thread_main_init` → `guest_thread_init` → `dm_jump_guest(nnMain)`。
App 目标编进：宿主全部源（除 main.c）+ 图形层 C 源 + `entry.S`；头路径补 `gfx/nvn`。

**接入 App 踩的坑（按 CI 错误逐个修）**：
- iPhoneOS SDK **没有 `mach_vm_*`**（`mach/mach_vm.h` 标 unsupported）→ 换 `vm_allocate`/`vm_remap`（旧 API，macOS/iOS 都有，CI 继续验同一路径）
- Mach-O 弱符号（数据与函数的 weak/weak_import）ld64 都拒 → 改显式宏开关 `SMO_EMBED`
- ARC 下不能显式 `release`
- `getsectiondata` 声明在 `mach-o/getsect.h`；`TargetConditionals.h` 要在 `#if` 之前
- **文件 App 里看不到 App 目录**的真因：缺 `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace`
  （v0.3.0 起可见）

## 2.101 壳模式（Guest.framework）：CI 壳 + 本机游戏程序

- `smo/ios/tools/guest_dylib.py`（移植参考项目，MIT）：本机（Windows 可用，纯 Python 写 Mach-O）
  把改写产物打包成只装三段的 `Guest.framework/Guest`；加了**空 `LC_CODE_SIGNATURE` 槽**
  （没有它，自签工具在「签前 Mach-O 准备」阶段会拒签 —— 全能签实测报「Guest 单独签名失败」）
- `dm_image_from_dylib`（loader_apple.c）：iOS 上 `dlopen` 安装包里的 Guest.framework →
  `getsectiondata` 三段 → `vm_remap` 回连续地址（代码共享签名页 RX、W 写时复制 RW、边界页 RWX）
- 出包/更新：`make_installable.py` 一条命令（下载公共 release 的壳 → 注入本机 Guest.framework
  → 出 `SMOMobile-<版本>-可安装.ipa`）；已发 v0.1.0–v0.4.1
- 备选：私有 fork + `GUEST_URL`/`GUEST_SHA256` 变量让 CI 注入（d2r-mobile-build 同款，未启用）

## 2.102 资源容器：几千个小文件 → 两卷（参考项目 .data 同款思路）

- `smoarc.c/h`：自制容器（`SMOA` 卷头 + 条目 + `END!` 标记 + CRC32，无压缩 —— .szs 本身已 Yaz0 压缩）
- `smoarc_selftest`：6 条断言（两卷、子目录、逐字节、CRC 破坏报错）
- `prepare_phone_package.py --pack-romfs`：4636 个文件 → `RomFS.smoa.0/.1`（3.2 GB + 2.3 GB，每卷 ≤3GB）
- App 首次运行自动展开（含一层包装目录 —— 用户把整个 `SMO Resource` 文件夹拷进手机也认），
  进度进日志缓冲、屏上可见
- 手机侧要拷的：`SMO Resource/{ExeFS(9 个小文件), RomFS(2 个大文件)}` —— 从 4645 个文件降到 11 个

## 2.103 日志导出（用户需求）

`main.m`：右下角「导出日志」→ 把「状态 + 游戏文件检测 + 宿主日志」写成
`SMO-log-<时间>.txt` 与 `SMO-log-latest.txt`（Documents，文件 App 可见）→ 拉起系统分享
（AirDrop / 邮件 / 存文件）。宿主日志走 `logbuf.c` 的 512 行环形缓冲（`LOG` 宏全量写 stderr + 缓冲）。

**能不能玩：还差两步** —— ① 真机首跑（拿 UNIMPL 日志，按它补初始化服务）② Metal 重放的真实呈现
（`CAMetalLayer` + GPU 可见内存）。出包与资源链路已经通到「一条命令 + 覆盖安装」。

---

# 第二十六轮：公开 runner 出内嵌版（私有仓 Actions 被计费挡住后的替代路线）

## 2.104 先说结论

私有仓（`hyc1743/super-mario-odyssey-ios-build`）的 Actions **任何 job 都启动不了**：
两个 job 都是 `The job was not started because recent account payments have failed or your
spending limit needs to be increased` —— 不是代码问题，是账户计费。改用**公开仓**的 Actions
（公共仓库免费）：游戏内容一步都不落公开侧，成品只进私有仓 release。

## 2.105 链路（谁在哪）

| 环节 | 在哪 | 说明 |
|---|---|---|
| 输入包（改写产物 15.6 MB） | 私有仓 **`embed-input` 分支** `input/embed-input.zip` | 单开分支的原因：私有仓 `main` 与公开仓**逐字节一致**，输入包不随 main 走 |
| 拉输入包 | 公开仓 runner（`SMO_PRIVATE_TOKEN` secret） | `GET /repos/<私有仓>/contents/input/embed-input.zip?ref=embed-input` + `Accept: application/vnd.github.raw+json` |
| 内嵌构建 | 公开仓 macOS runner（免费） | `embed_inject.py` → `Embedded.S` + `project.yml`（`SMO_EMBED=1` + 三条 `-segprot`） |
| 成品 IPA | 私有仓 tag `build-latest` 的 release 资产 | 名字 `SMOMobile-embed-r<run号>-<短sha>.ipa` |
| 公开侧闸门 | 公开仓 | artifact 上传与 tag release 都带 `SMO_INJECTED != '1'`，含游戏程序的包传不出去 |

- 一次配置：`smo/ios/tools/set_ci_secret.py`（取仓库公钥 → libsodium sealed box → PUT；令牌只从环境变量读，不落文件）
- 私有仓 Actions 已关闭（`PUT /actions/permissions {"enabled": false}`）—— 免得每次推送产生一批计费失败记录

## 2.106 证据

- 公开仓 run **38881008376**（提交 `53e0a5b`）：两个 job 全绿；
  「注入游戏程序」= success、「公开 artifact 上传」= **skipped**、「内嵌版 → 私有仓 release」= success
- 私有仓 release `build-latest` 资产 `SMOMobile-embed-r132-53e0a5b.ipa`（15,772,315 字节）
- 把该 IPA 拉回逐条核对（本机）：主二进制 58,261,576 字节；
  `__TEXT` 内含 6 个 RX 节（0x3e0000 / 0x44000、0x2f8000 / 0x48000、0xbf4000 / 0x18000），
  `__DMsdkW` / `__DMsubsdk0W` / `__DMmainW` 三个 RW 段（0x640000 / 0x3c8000 / 0x19bc000）
  —— 与包内 `Embedded.S.manifest.tsv` 九行**逐条一致**
- 私有仓 API 拉取链路本机实测：15,623,872 字节、sha256 与 `out/embed-input.zip` 完全一致

## 2.107 顺带修掉的三处

1. `embed_inject.py` / `gen_embed.py` / `check_embed.py`：Windows 控制台是 GBK，
   emoji/中文直接 `print` 会抛 `UnicodeEncodeError` —— **成功被当成失败**（`check_embed` 本机实测过）。
   统一加 `sys.stdout.reconfigure(errors="replace")`，并给子进程强制 `PYTHONIOENCODING=utf-8`
2. 工作流：`$（stat -f%z …）` 是全角括号，bash 只打出字面量 → 改 `wc -c`（跨平台）
3. 防误推：`.git/hooks/pre-push` 拦「含 `input/` 的提交推到公开仓」（本机生效，不随仓库分发）

## 2.108 下一步

- 你这边：私有仓 release 下载 IPA → 全能签自签 → **覆盖安装** → 打开 → 导出日志回传（M1 首跑）
- 我这边：按 UNIMPL 日志补初始化服务；Metal 呈现（M2 的第一块真机代码）

## 2.109 令牌说明（要写清楚，免得以后看不懂）

CI secret `SMO_PRIVATE_TOKEN` 目前用的是本机 **Git Credential Manager 里的 OAuth 令牌**
（scopes: gist / repo / workflow）。能用，但权限偏大，且 GCM 重新登录时可能被轮换 ——
那天构建会突然 401。换法：建一个 classic PAT（只勾 `repo`），
`SMO_CI_TOKEN=<PAT> python smo/ios/tools/set_ci_secret.py hyc1743/super-mario-odyssey-ios SMO_PRIVATE_TOKEN`。

## 2.110 真机首跑的第一批问题（都已修，都补了断言）

用户实测：**不放资源能启动；放上资源一打开就闪退**，而且崩后拿不到任何日志。
两个根因都是「工具悄悄失效」——上真机之前，本机所有测试都是绿的：

1. **日志落盘是假的**：`logbuf.c` 里 `g_file` 只被 `fopen` 打开，`dm_log_emit` 从来没写过它 ——
   崩溃后 `SMO-log-live.txt` 是 0 字节。现在每行写盘并 `fflush`；`applogic_selftest` 新增断言
   「`dm_log_set_file` 之后文件里必须有内容」（上一版会 0 字节，能抓住）。
2. **容器在手机上从没展开**：`prepare_phone_package.py` 打的包是
   `SMO Resource/RomFS/RomFS.smoa.0|.1`（卷在 `RomFS` 目录里），而展开逻辑只在
   「目录里没有 `RomFS` 子目录」时才动手 —— 我们自己的包正好被跳过：`RomFS/` 里只有两个卷、
   一个游戏文件都没有，游戏一读文件就崩。
   判断挪进 C 的 `smoarc_plan()`（三种布局都认），`smoarc_selftest` 覆盖三种形状 +
   「只有目录树没有卷 → 不重复展开」。这段以前是**没测试的 ObjC 代码**，正是它出错。

顺带：`smoarc_extract_cb()` 进度回调（5.5 GB 展开每 100 个文件一行）；展开完写 `.smoa-done`
标记；进游戏前先确认 RomFS 里真有内容（没有就停在明确报错上，而不是崩得莫名其妙）。

## 2.111 版本号与发版口径（v0.5.0）

- **分支推送**：版本号 `0.1.<run 号>`。分支没有版本来源 —— 写死 `0.1.0` 时真机上分不清装的是哪一版，
  而 git SHA 又不能进 `CFBundleShortVersionString`（只允许数字与点）
- **tag 推送**：版本号就是 tag。公开仓仍然建 release 记下版本（但内嵌版的成品里含游戏程序，
  所以**不附产物**）；成品进**私有仓同名 release**，资产名 `SMOMobile-<版本>.ipa`
- 非 tag 的分支构建：都进私有仓 `build-latest`，资产名带 run 号 + 短 sha（对照哪次提交）
- **v0.5.0** = 第一条能真机跑的出包链路：公开 runner 免费构建 + 内嵌 + 容器修复 + 真机日志落盘

## 2.112 真机第二崩：引导顺序写了两份，App 那份是错的（v0.5.1）

2.110 的日志落盘修好后，第一次拿到真机证据。日志停在：

```
sdk: DT_INIT +0x24（init_array 103 项）
```

即：三个模块**全部装载成功**（内嵌三段映射、重定位、447 条接管表、11775 次符号查询 0 不一致），
崩在**第一次执行客体代码**（sdk 的构造函数）时。

根因：App 的引导顺序与宿主 CLI 不一致 —— `main.c` 是
`keys → load → svc_thread_main_init → run_module_inits`，
而 `ios/Sources/main.m` 把 `run_module_inits` 写在了 `svc_thread_main_init` **前面**。
客体构造函数（改写后的代码）第一时间就要读线程/TLS 环境，主线程没登记就是空指针。

修法（不让它再漂移）：

- 引导顺序收进 `smo/host/host_boot.c` 的 `host_boot()` —— CLI 与 App 都只调它，顺序只有一份
  （同一类教训第三次：CI 单测文件清单、CI 注入清单、现在是引导顺序）
- `run_module_inits()` 加不变量检查（`dm_boot_mark_main_thread`），谁再写错顺序，日志会直接指出来
- **新增崩溃信号处理**（`main.m`）：SIGSEGV/SIGBUS/SIGILL/SIGTRAP/SIGABRT/SIGFPE 时把信号、
  地址、PC/LR/FP 与帧链用 `dm_log_raw()`（只调 `write(2)`，异步信号安全）写进 `SMO-log-live.txt`
  —— 真机上「崩了就什么都没有」的时代结束
- `logbuf` 加 `dm_log_raw()`（O_APPEND 裸 fd）；单测补「裸写也进同一文件」断言

## 2.113 真机第三崩：客体线程环境（TLS/TLR）没建就跑模块构造函数（v0.5.4）

v0.5.2 的崩溃现场（PC/LR/帧链）把范围收到 sdk 代码段内，坏地址是 **0x1f8**。
反汇编对不上 PC —— 说明现场还缺东西；于是 v0.5.3 又补了 ESR/FAR + 寄存器 + PC 附近指令字。

但 0x1f8 这个数字本身就是答案：`guest_thread_init()` 里有一行

```c
*(void **)(tlr + 0x1f8) = tlr + TLR_SIZE;      // 当前线程对象（Horizon: tpidrro_el0 + 0x1f8）
```

客体构造函数第一时间要读「当前线程对象」，而 `guest_thread_init()`（建 x18 / TLS / TLR / 门）
在 `host_boot()` 里排在 `run_module_inits()` 后面 —— TLR 为空，读 +0x1f8 就是访问地址 0x1f8。

修法：
- `host_boot()` 顺序改为 keys → load → 主线程登记 → **客体线程环境** → 模块构造函数 → 入口
  （真实 rtld 也是这个次序：先建线程/TLS，再跑 init_array）
- `dm_boot_mark(stage)`：1 = 主线程已登记，2 = 客体线程环境已就绪；`run_module_inits()`
  在 stage < 2 时直接红字说明白（前两轮事故都是它没被满足）
- v0.5.3 的崩溃现场增强保留（ESR/FAR + 寄存器 + 指令字），下一次任何崩溃都能一次定位

## 2.114 容器展开失败要说清楚原因（v0.5.3）

真机上只看到 `展开结果：-2`，分不清是空间不够还是卷不完整。`smoarc_error()` 现在给出：
卷打不开 / 卷头不是 SMOA / 读卷中断 / 输出文件打不开（空间？）/ 写文件失败（空间不够）/
写盘没落稳 / 条目 CRC 不符（卷不完整或拷贝被截断）。同时检查 `fwrite` 与 `fflush/ferror` ——
磁盘写满不再静默产出半截文件。`smoarc_selftest` 补断言「原因里必须写清楚是 CRC」。

## 2.115 真机第四/第五崩：rtld 的两件活（v0.5.5 / v0.5.6）

v0.5.4 加的崩溃现场（ESR/FAR + 寄存器 + PC 附近指令字）让这两次都在一轮内定位：
PC 的指令字与本地映像**逐字节一致**，于是能直接读出崩溃代码在哪个函数、哪条指令、哪个寄存器是坏值。

### 第四崩（v0.5.5）：rtld 链接器符号被绑成宿主桩地址

`_init` 第一步调 `__nnmusl_init_dso`，其中四个参数是 rtld 提供的链接器符号
`__rel_dyn_start/end`、`__rel_plt_start/end`（模块自己的 .rela.dyn / .rela.plt 边界）。
sdk/subsdk0/main 各导入这四个，而我们没实现 → 被登记成宿主桩地址。
修：装载器按模块解析这 8 个名字（`__rel_*` 与 `__rela_*`），指向该模块的 DT_RELA / DT_JMPREL 及末尾；
`loader_selftest` 加回归断言（合成产物也带上这四个符号）。

### 第五崩（v0.5.6，真凶）：TLS 分配器没接上，SDK 的 DSO 初始化整段被跳过

现场一致：崩在 `ThreadManager::SetZeroToAllThreadsTlsSafe`（遍历线程链表，头是 0），
`g_OsResourceManagerStorage`（bss）从没被构造。顺着 init_array 看清了次序：
崩溃的是**数组第 1 项**（`0x45ba4`，要 `nn::os` 的 TLS 槽），而第 0 项没起这个作用。

再往下挖 `__nnmusl_init_dso` 的**第一句**：

```c
if (!nn::os::MemoryAllocatorForThreadLocalInitialized()) return;    // 标志位在 0x92c7f8
```

而标志位由 `nn::os::SetMemoryAllocatorForThreadLocal(alloc, free)` 设置，两个分配器函数是
**main 模块导出的** `nn::init::detail::DefaultAllocatorForThreadLocal` /
`DefaultDeallocatorForThreadLocal`。**真实 rtld 的职责**：装载完模块、跑模块初始化之前，
把它们接给 `nn::os`。我们扮演 rtld 却漏了这一步 → 检查为假 → DSO 初始化直接返回 →
TLS 不建、`nn::os` 运行时等于没初始化 → 构造函数一用 TLS 就崩。

修：`host_boot()` 在装载之后、模块初始化之前调
`dm_find_tls_allocator_wiring()`（loader_core.c）找齐三件套并调用 setter；
找不到就红字写明缺哪个符号。`loader_selftest` 加回归断言（合成产物也带这三个符号），
真实产物上已验证三个符号都能找到。

## 2.116 分卷改成每卷 ≤1 GB（v0.5.8）+ 分卷工具与它的一个教训

用户反馈：卷「直接拷到手机」后第 1 条 CRC 就不符。PC 上的源做了全量校验（卷 0 = 3108 条、
卷 1 = 1528 条，CRC 全对），所以差异出在拷贝那一段 —— 而 3.2 GB 的单文件在很多拷贝路径上
本来就不稳（截断、被工具改写、或重名没覆盖）。改成分小卷：

- `prepare_phone_package.py --vol-mb <MB>`（默认 **1024**）：从源 RomFS 打卷时按上限切
- 新工具 `smo/ios/tools/smoarc_split.py`：对**已有卷**重新分卷（条目顺序与 CRC 原样保留，
  `--verify` 逐条校验），不依赖源 RomFS 目录
- App 侧卷上限 8 → **24**（小卷如 512 MB 也够用）；`smoarc_selftest` 补「12 个卷全认出来」断言
- 展开前打印每个卷的字节数与头 8 字节（v0.5.7 起）：大小不对 = 截断；大小对但头不对 = 内容不同

**教训（写进工具注释）**：`smoarc_split.py` 第一版在写完之前就 `os.remove` 输出目录里的
`RomFS.smoa.*` —— 而输出目录常常就是输入卷所在目录，于是把 5.5 GB 的输入卷一起删了，只能从源
`work/game/RomFS` 重打一遍。现在改成**先写 `.part` 临时名、全部成功后再删旧卷改名**。

实测新产物：6 卷（1,073,770,015 / 1,073,340,665 / 1,071,803,782 / 1,044,068,449 /
1,072,084,835 / 170,236,956 字节），4636 条、CRC 全对。

## 2.117 真机第六崩：整套 SDK 运行时初始化（nn::init::Start 六步）都缺（v0.5.9）

v0.5.6 的 rtld 接线（TLS 分配器）生效后，`__nnmusl_init_dso` 真的跑起来了，
崩点从「sdk: DT_INIT 之后」推进到 `__nnmusl_init_dso` 内部：

```
3c5144: bl nnosGetModuleCountMax()                 → 128
3c5160: bl nnosAllocateMemoryForThreadLocal(1032)  → 返回 NULL
3c5178: bl memset(NULL, 0, 1032)                   → SIGSEGV（写 0x407）
```

顺着 NULL 追到 `main` 里的 `nn::init::detail::DefaultAllocatorForThreadLocal`：它读
`main+0x2473670`，为 0 就返回 NULL；而这个全局由 `nn::init::InitializeAllocator(void*, size_t)`
设置，唯一的调用者是 **`nninitStartup`**（main+0x536f34），
而 `nninitStartup` 又是被 **`nn::init::Start(size_t, size_t, void(*)(void), void(*)(void))`**
（sdk+0x68668）调用的 —— 也就是 Nintendo 的「SDK 启动流程」。

我们的人一直没调这套，只在 `loader_core.c` 里留过一句 TODO：
「时机由 SDK 的启动流程决定（nn::init::Start 之后、nnMain 之前）——参考项目如此，
本项目目前的 bootstrap 是『装载完就调』，等接上 SDK 初始化顺序后再对齐」。

这一轮把这套顺序补齐了。参考项目（`dm/host/main.c` 的 `guest_main`）是逐条照抄的：

```
_init_libc0 → nnosInitialize(主线程句柄, 0) → _init_libc1（musl 锁/SSP）
  → nninitInitializeSdkModule → nninitStartup（游戏分配器）→ _init_libc2
  → run_module_inits（各模块 DT_INIT，rtld 回调 B）
  → SetHostArgc/SetHostArgv → nnMain
```

关键一环：**`nnosInitialize` 正是构造 `g_OsResourceManagerStorage` 的地方**
（sdk+0x8f89c：`ldr x0,[0x91ffb8]; bl …`）—— 这正是第五/第六崩里那个「线程链表头是 0」的
bss 对象。所以前几轮「构造函数用 TLS 就崩」的根因是：**SDK 运行时初始化整段没跑**，
而不是单个服务缺实现。

`host_boot()` 现在按上表逐步调用（每一步都打 `>>> 符号名` 日志，缺符号会红字点名），
`SetHostArgc/Argv` 也给上（argv[0] = "SMO"）。

## 2.118 真机第七崩：SDK 初始化真的跑起来了，崩在系统库的 abort（v0.6.0）

v0.5.9 的六步 SDK 初始化生效后，日志第一次出现：

```
>>> _init_libc0
>>> nnosInitialize(0x1001, 0)
客体地址空间 0x7000000000 …（mem_init 打印：第一条 svc 进来）
【崩溃】SIGABRT 地址 0x24cac31fc … ESR 0x56000080（BRK）
PC 附近指令字 … 0xd4001001[0xd2802910] …（mov x16,#0x148; brk）
```

即：`nnosInitialize` 跑到了第一条 svc，然后**在系统库里 abort**（PC 在 dyld 共享缓存，不是任何客体映像）。

关键判断依据：`die()` 是 `LOG("FATAL …"); abort();` —— **会写日志**，而日志里没有 FATAL 行，
所以不是我们自己的 die；系统库的 abort 消息默认只走 stderr，真机上没有终端就丢了。

v0.6.0 补三样诊断：
- `svc_dispatch` 把前 120 条 svc 调用（号 + 前 5 个参数）写进日志 —— 崩在某条 svc 上时能指出是哪一条
- `main.m` 启动时把 **stderr 重定向到 `Documents/SMO-stderr.txt`**：libsystem / malloc / musl 的
  断言消息从此留得下（这是系统库 abort 唯一可得的文本证据）
- 卷读不了时 `HexHead` 打印具体原因（而不是空字符串）

顺带：卷那件事仍未解决 —— 日志显示 6 个卷**字节数完全正确**但「头」读不出来且展开时第 1 条 CRC 不符，
说明打开 App 那一刻文件还读不到内容（拷贝/下载没真正落盘）。等拷贝彻底结束再开 App。

## 2.119 真机第七崩的真相：不是游戏，是我们自己的 UI（v0.6.1）

v0.6.0 把 stderr 落盘后，`SMO-stderr.txt` 一眼给出答案：

```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException',
    reason: '*** -[__NSArrayM insertObject:atIndex:]: object cannot be nil'
```

**是 App 自己的界面代码抛异常**（调用栈里 0x102… 全是我们的主二进制）。原因：

- 环形缓冲每行上限 200 字节，日志里出现中文/emoji 时**会被切在半个字上**；
- `RecentLog()` 里 `[NSString stringWithUTF8String:buf]` 遇到非法 UTF-8 **返回 nil**；
- 界面把 nil 插进 `NSMutableArray` → `NSInvalidArgumentException` → 进程终止。
- 「运行久一点才退出」正是因为它要等日志长到把某个多字节字符切开。

修两处（各自带断言）：
- `logbuf.c`：存行与 dump 时都把行尾修到合法 UTF-8 边界（最多回退 3 字节）；
  `applogic_selftest` 新增「长中文行被截断后 dump 仍是合法 UTF-8」断言
- `main.m`：`RecentLog()` 两层兜底（UTF-8 不行退 Latin-1，永不返回 nil）

也就是说 SDK 初始化其实在正常推进（崩前已经走到 `nnosInitialize` 里连发了 6 条 svc），
这一崩与客体无关。

## 2.120 卷「大小对但读不出来」的诊断（v6.6.1 一并）

用户反馈：卷的字节数完全正确、但 App 里「头」读不出来 —— 这不是「拷贝没完成」能解释的。
所以让证据说话：
- `smoarc.c`：CRC 不符时把**实际读到的前 16 字节**与「实算 CRC / 表里 CRC」都写进日志
  （全 0 = 读到空洞或占位符；别的值 = 内容不是同一份）
- `main.m`：`HexHead` 明确报「读到 0 字节 —— 文件像是占位符/还没落盘」，并打印每个卷的修改时间

## 2.119 真机第七崩的答案是**我们自己的 UI**（v0.6.1）：日志里的非法 UTF-8

v0.6.0 把 stderr 落盘后，SMO-stderr.txt 第一次给出系统库的消息：

```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException',
    reason: '*** -[__NSArrayM insertObject:atIndex:]: object cannot be nil'
```

帧全落在**我们 App 自己**的二进制里（0x102…）。真因：

- `logbuf.c` 每行上限 200 字节。中文/emoji 一多，**截断点会落在多字节字符中间**；
- `main.m` 的 `RecentLog()` 用 `[NSString stringWithUTF8String:]` 转换 —— 遇到非法 UTF-8 **返回 nil**；
- App 把 nil 插进 `NSMutableArray` → 抛 `NSInvalidArgumentException` → 进程直接终止。

这就解释了「运行久一点才退出」：要等日志长到某一行被截在半个汉字上。

修法（两边都堵）：
- `logbuf.c`：`utf8_trim()` —— 存行与 dump 时都把尾部修到合法 UTF-8 边界；
  `applogic_selftest` 补断言：「长中文行被截断后 dump 仍是合法 UTF-8」（改成逐字节校验）
- `main.m`：`RecentLog()` 的转换做两层兜底（UTF-8 不行就退 Latin-1，永不返回 nil）

## 2.120 同一轮里的另外三个真机陷阱（v0.6.1）

1. **`LOG(...)` 里不能用 `%@`**：LOG 走 C 的 `vsnprintf`，`%@` 它不认识 —— 真机上
   「卷 … 字节，头 %@」那一栏一直是**空的**（我们因此白追了一轮「卷读不出来」）。
   改成 `%s` + `.UTF8String`。
2. **HexHead 换 POSIX 版**：`open/read` + errno + 失败重试三次，并明确区分
   「打不开（errno …）」与「读不到内容（read=0 … 文件还没落盘？）」。真机上「大小对但读不到」
   多半是拷贝/下载还没落盘。
3. **未捕获的 ObjC 异常进日志**：`NSSetUncaughtExceptionHandler` 把 `name/reason/callStackSymbols`
   写进环形缓冲 —— 下一轮这类问题不用再靠 stderr 文件绕一圈。

另外：展开失败后自动做一次**只读**全卷体检（`smoarc_verify_cb`，不写盘，空间不足也能跑），
一次给出「几千条里坏几条 + 第一条坏的叫什么」。

## 2.121 用户侧的两轮修复（v0.6.3 / v0.6.4）：卷「全坏」原来是宿主自己的 bug

用户（借助另一个 agent）在真机上继续推，先修掉了我留的两个 bug，再补了整套首屏体验：

1. **`smoarc_extract_cb` / `smoarc_verify_cb` 直接用 `crc_table` 却没调 `crc_init()`** ——
   真机上表全 0，于是 4636 条**全部**报「CRC 不符」。我此前据此判断「手机上的卷坏了/拷贝被截断」，
   是**被自己的 bug 误导**：卷一直是好的（PC 侧 Python 校验与手机侧展开互证）。
   自检之所以没抓到，是因为它用 `crc_buf()` 造卷时顺手把表建好了 —— 修法是把自检改成**独立的逐位 CRC**
   （不共享被测实现），这比我原来那版测试更可靠。
2. 进度与首屏：`logbuf` 增加运行进度状态（第几步/本步百分比/红色告警数/最后一行日志时刻），
   宿主引导分 6 步上报、展开按字节算百分比；App 首屏改为「步骤 + 进度条 + 剩余时间 + 该不该导出日志的
   彩色提示 + 最近 12 行」，上一轮崩溃时顶部红条提示；导出改为「进度摘要 + 状态页 + 全量带时间戳日志
   （不受 512 行限制）+ stderr + 上一轮日志」。锁屏自动关闭（展开中不让熄屏）。

**证据**：v0.6.4 的日志里 `展开结果：0`、4636 个文件、顶层 10 个目录 —— 资源链路终于通了；
之后卡在第 5/6 步（SDK 初始化），日志停在 `svc #38(0, 0, 0, 0, …)`。

## 2.122 真机第八轮：卡住的真因是「未实现的 svc 留下垃圾返回值」（v0.6.5）

`svc #38 = 0x26 = Break`（Horizon 里 SDK 的致命中止调用），而我们的 `svc_dispatch` 对未实现的 svc
**既不写 `regs[0]` 也不报错** —— SDK 读到的 `GetInfo`（`svc #41 = 0x29`）返回值是**栈上的垃圾**，
于是 SDK 自行 `svcBreak(Panic)`，然后进程就停在那里（不崩、不再动）。

照参考项目 `dm/host/hle_svc.c` 补齐四个 svc（它已在真机跑通）：

| svc | 做什么 |
|---|---|
| `0x29 GetInfo` | 按 id 返回内存布局：alias/heap/stack/ASLR 的地址与大小、TotalMem/UsedMem、RandomEntropy（每次新值）、ProgramId（SMO 的 `010000000000`+…）、IsApplication=1… |
| `0x26 Break` | 打印 reason / Result / **调用点（模块+偏移，用门保存的 x30）**；高位为 1 只通知，否则明确停下并写红字（不再静默卡住） |
| `0x27 OutputDebugString` | 把客体字符串打进日志（以后 panic 的原因能直接看到） |
| `0x1E GetSystemTick` | 19.2 MHz 计数器 |

并把默认分支改成：**每个未实现的 svc 号记录一次**并占位返回成功（不再留垃圾寄存器）。
`svc_selftest` 补了 `module_of` 空实现（该自检不链装载器）。本机 `make test` 14/14。

## 2.123 v0.6.6 真机闪退：lmem 本地堆函数被误接管

2026-10-16 上传的 `SMO-log-2026-10-16, 23.19.05.txt` 与 `SMO-log-latest.txt`
内容相同。导出时本次运行还在第 3/6 步；实际崩溃现场保存在「上一次运行」部分：

- SDK 已经过 `nnosInitialize`，在 `nninitInitializeSdkModule` 内调用了
  `nn::lmem::CreateExpHeap` 和 `nn::lmem::AllocateFromExpHeap` 的 HLE 占位桩。
- 紧接着 `SIGSEGV`，FAR=0、x0=0，PC 指令 `0xf9400008`（从 x0 指向的地址读取）。
  该次 sdk 基址 `0x11a0dc000`，PC `0x11a205ccc`，偏移 `+0x129ccc`。
- `hle_inventory.py` 错把 `lmem` 列为服务家族；6 个 SDK 提供的 ExpHeap / FrameHeap
  函数因此进了强制接管表，覆盖掉 SDK 原有实现。占位桩返回 0 无法提供有效堆或分配结果。

修复：把 `lmem` 归入本地库，同步修正库存的 6 行，重新生成接管表（447 → 441 条）。
装载器原有解析顺序会回到本模块或跨模块的 SDK 定义；保留其原生堆管理实现。
服务型 `sf::hipc` 接管策略本轮保持现有行为，后续若阻塞需按新日志补真实现。

回归：工具链自检增加 6 个 lmem 符号的策略、库存、生成表检查，以及 fs / NVN
接管仍保留的检查；修复前 6 项失败。Windows 快速回归通过 7 项（含 14 个 C 自检）。
尚未在 macOS 构建修复后的 IPA，也未在真机验证能否继续完成 SDK 初始化。

## 2.124 v0.6.7 真机闪退：HIPC 消息缓冲区 getter 被接到空桩（v0.6.8 修复）

用户上传的 `SMO-log-previous.txt`：接管表 441 条，`nninitInitializeSdkModule`
内部经过日志服务连接，调用 `GetMessageBufferOnTls` 占位桩后立刻 SIGSEGV。
sdk 基址 `0x11d400000`，PC `0x11d52a2a8`，即 sdk+`0x12a2a8`；
x20=0，故障指令 `stp w8,w9,[x20]`，FAR=0。上轮 lmem 空桩调用已经消失。

用本地 LLVM/Capstone 核对 SDK（非 REA 反编译结论）：

- `GetMessageBufferOnTls` 位于 sdk+`0x98db0`，原指令为读取 `tpidrro_el0`；
  `work/rewrite/sdk.sites.tsv` 已有该处 `tpidrro_r` 改写，会返回线程自己的 TLR。
- sdk+`0x12a268` 的 OpenLogger 组包：type=4、special header 含 PID、SFCI cmd=0，
  消息从 +0x20 对齐。发送后要求 SFCO、成功 Result，以及一个 move handle。
- `nn::lm::Initialize` 使用 CreateLogServiceByHipc 创建的代理打开 ILogger。
  只给 getter 一个非空指针仍不够：连接必须写出句柄，发送必须提供真实可解析的响应。

修复：3 个本地函数（TLS getter、SetupHeader、SetTag）恢复使用 SDK 实现；接管表
441 → 438。新增 `hle_hipc.c` 实现服务解析、lm 连接、OpenLogger/日志/目的地请求、
关闭及克隆会话。支持的请求回 HIPC/CMIF 响应，未知服务/命令回错误；当前接收并丢弃
游戏的日志包，宿主 logbuf 不受影响。新文件同时接入 Makefile CORE 和 iOS 工程。

验证：快速回归 7 项全部通过（含 15 个 C 自检）；新增 `hipc_selftest` 覆盖 PID/描述符
偏移、move handle、SFCO/Result/token、会话耗尽、关闭与并发，并纳入 macOS CI。
另在本机把实际宿主 C 实现编为 DLL，用 Unicorn 执行 SDK 自己的
`HipcMessageReader::Initialize`（sdk+`0x42de4`），核对 OpenLogger 和 ILogger cmd0/1
响应：move handle、原始数据长度、SFCO、Result 均正确。这是局部响应兼容性验证，
尚不代表完整 SDK 启动或真机已通过。REA 打开 ELF 成功，但深度分析后端未配置，
本轮未使用其反编译结果。

## 2.125 v0.6.8 真机 SIGBUS：物理内存映射缺失（v0.6.9）

2026-10-16 新上传日志显示：HIPC OpenLogger 已返回有效句柄；随后
`svc 0x2c MapPhysicalMemory(0x7000000000, 0x1000)` 被默认分支伪装为成功。
SDK 向该地址写入时触发 SIGBUS；PC sdk+`0x6a658`，FAR/x20=`0x7000000000`，
故障指令 `0xf900028a`。这不是上一轮的空 TLS 指针问题。

重新对照参考项目 d2r-mobile commit `17845634d71341cca1debf43ad79ac25c6a3a97a`：

- `dm/host/hle_svc.c` 实现了 alias 区物理映射/解除映射。本项目补齐这两个 SVC，
  校验大小、4 KiB 对齐、地址溢出、边界、重复映射与未映射区解除；失败不修改映射。
- 本实现额外维护 4 KiB 客体页账本，按实际宿主页大小开放权限；解除其中一页时保留
  同一 16 KiB 宿主页里的其他映射。重新映射的页清零；QueryMemory 报告连续区间与空洞，
  GetInfo 的已用内存计入物理映射。宿主仍不能隔离同一宿主页内的未映射 4 KiB 子页。
- `dm/host/hle_sdkinit.c` 在高层接管系统服务初始化。核对本地 SDK 的
  `nninitInitializeSdkModule`（sdk+`0x68624`）全部 8 个调用的 PLT/GOT 后，
  对当前 SDK 实际存在的 nndiagStartup、aoc、pctl、diag abort observer 增加明确实现；
  oe 已有宿主实现。保留原生 os::InitializeVirtualAddressMemory 和两个 fs 本地开关。
  初始化入口属于 SDK 内部重定位，不在跨模块 import TSV 里，生成器显式追加，避免漏接。
- 恢复 sf::impl 的本地 AddReferenceImpl / ReleaseImpl，避免引用计数被通用成功桩覆盖。
  保留上一版 HIPC lm 实现，供其他调用路径使用。接管表 438 → 440，真实现 84 → 88。
- 参考代码 MIT 许可保存在 `third_party/d2r-mobile.LICENSE`。

验证：新增物理映射回归在修复前 6 项失败；修复后通过，包括部分解除、空洞查询、
邻页保留、清零、非法参数与边界。非 Windows 的自检使用真实 PROT_NONE/mprotect 映射，
Windows 检查页权限调用与账本；全部平台强制模拟 16 KiB 宿主页粒度。
HIPC 自检增加 4 个初始化入口确实解析为真实现的检查，工具自检覆盖本地引用计数、fs 开关
与 SDK 内部初始化入口。Windows 快速回归 7/7 通过（含 15 个 C 自检）。
IPA 和真机结果另按云端构建及用户测试记录。

## 2.126 v0.6.9 进入 nnMain 后 SIGSEGV：NVN 成功值及设备属性错误（v0.6.10）

2026-10-17 用户上传日志：上轮物理映射及 SDK 初始化已通过，全部模块构造函数已执行，
进入 `nnMain` 后崩在 main+`0x775c00`（`agl::driver::NVNMgr` 构造函数），
指令 `ldr x9,[x8,#0x30]`，x8=0、FAR=`0x30`。GOT 回溯到
`sead::Graphics::sInstance`（main+`0x24741f8`），说明图形对象尚未建立。

用本地 LLVM 读取调用链和 PLT/GOT（不是 REA 反编译结果）：
`GameFrameworkNx::initializeGraphicsSystem` 在 main+`0x731314` 检查
`nvnDeviceInitialize` 返回值低字节，0 表示失败；随后 main+`0x731358` 要求
DeviceGetInteger 的 API major=53、minor>=13。宿主此前恰好成功返回 0、所有属性填 0，
使该函数提前退出；之后 AGL 仍然创建 NVNMgr 并解引用空单例。旧 C 自检也把成功值写反。

修复：

- 将已有 Device / MemoryPool / Buffer / Sync / Sampler / Program 的 Initialize，
  以及 ProgramSetShaders 的 NVNboolean 改为成功 1、失败 0；void/枚举接口不混用此约定。
- DeviceGetInteger 输出 int32，提供 API 53.13 及参考项目的设备限制表；支持不带设备的查询。
  表来源 d2r-mobile `dm/gfx/nvn/hle_nvn.c`（MIT，已有许可）；这些是兼容值，不是 iPhone 硬件报告。
- 参照 `dm/gfx/hle_vi.c` 实现全部 6 个被导入的显示接口，输出有效的 display/layer/native
  标识；Vsync 使用 SDK CreateSystemEvent 和宿主 60 Hz 节拍，可被客体 WaitSynchronization 等待。
  尚未与平台呈现节拍关联，宿主窗口标识也尚不是 CAMetalLayer。
- App 检查资源目录后，实际设置 SMO_ROMFS/SMO_SAVE/SMO_TEMP 并建立可写目录。
  旧日志已经找到 `Documents/SMO Resource/RomFS`，但文件服务仍报环境变量未设置，
  `content` 挂载因此失败；现将发现的同一条路径传给文件服务。
- NVN 日志接到 App 环形日志与持久日志中，避免关键初始化记录仅出现在被截断的 stderr。

验证：新增 vi_selftest 覆盖输出参数、错误输入、重复绑定、多事件与后续节拍真实等待。
SDK 的事件布局由测试替身提供，内核句柄/等待使用实际 hle_thread.c；fs 自检增加 content 挂载读取。
修正旧 NVN 单测并增加实际 API 版本条件、4 字节输出边界、全局查询、无效初始化失败检查。
另新增可选 `smo/verify/nvn_boot_replay.py`，用 Unicorn 执行本地 main+`0x731270..0x7313c4`
和原生 nvnLoadCProcs，对接实际宿主 C 动态库，仅替代设备内存分配：旧版本进入 rejected，
修复后进入 passed。回放仍记录 3 个当前未注册的扩展函数；这段验证不覆盖后续初始化或渲染，
不能据此宣称完整游戏或真机启动成功。

Windows 快速回归 7/7 通过（含新增 vi_selftest，共 16 个 C 自检）。

## 2.123 真机第九轮：按 Start 后闪退 = 渲染附件缺失把整帧提交搞失败（v0.6.6）

用户推进到 r258（渲染、音频、触屏、帧节奏都接上了），日志 2657 行，最后停在：

```
[nvn] NVN_RESOURCE_MISS type=12 object=0x70f5197ce8（render command skipped）× 多次
[nvn] NVN_METAL_RESOURCE_UNSUPPORTED texture=0x16b2f4370 format=52 target=1 samples=0 render=1
[nvn] NVN_GPU_RENDER_ENCODING_FAILED op=105 size=16
[nvn] NVN_GPU_ENCODING_FAILED handle_index=0
[nvn] FATAL NVN_GPU_SUBMIT_FAILED count=1     → SIGABRT
```

即：场景切换时游戏重建了纹理（录下的命令仍引用旧对象，注册表里查不到）→ 某个深度附件
（`format=52 = NVN_FORMAT_DEPTH32F`）解析不出来 → 这一帧编码失败 → 整单提交失败 →
`nvn_QueueSubmitCommands` 里的 `NVN_DIE` → 闪退。

**真机上 NVN 按地址访问、不校验生命周期**；我们却因为「注册表里没有」把进程杀了。改成降级：

- `nvn_metal_render.c`：附件解析不出来时**放弃这一遍渲染**（`skipPass`），后续绘制命令丢掉，
  直到下一次 `SetRenderTargets` —— 缺一帧画面，不再杀进程
- `nvn_metal_runtime.m`：单条命令缓冲编码失败 → 记日志后**继续提交**（以前 return 0 → 上层 NVN_DIE）
- `nvn_gpu.c`：提交前的「有未实现命令」不再拒整单（`NVN_SUBMIT_DEGRADED`）
- `nvn_metal_resources.m`：纹理创建失败把**具体判据**写出来
  （pixel format / texture type / layout / pool 未注册 / 超出池 / 压缩当渲染目标 / depth 用途 / 采样数 …）
- `queue_selftest` 的契约随之改为降级语义（未实现命令仍提交）

## 2.124 音频：DSP 处理后的输出是 0（v0.6.6 加诊断）

`AUDIO_DEVICE_PCM … audible=0 peak=0 input_peak=0`：渲染器被正常驱动
（`AUDIO_RENDERER_MIX_FRAMES` 每秒 200 次），但取出来的 PCM 全是 0。
`input_peak` 是在 DSP 处理**前**读的（本来就该是 0），所以「游戏没出声」与「我们读错位置/时机」
两种可能长得一样。v0.6.6 增加：

- `AUDIO_SINK_LAYOUT`（地址/声道/缓冲数/帧数/声道映射/命令长度，只打一次）
- `AUDIO_SINK_POST_PROCESS peak=…`（DSP 处理**后**再读同一个缓冲区，最多 64 行）

有这两条，下一轮就能判定是「客体 DSP 真没混音」（→ 查 guest 侧音频命令/音量/是否还没开始播）
还是「宿主读错了缓冲区或读得太早」（→ 查 sink 命令字段与转换）。

## 2.125 真机第十轮：不闪退了，但黑屏 —— 用日志摘要定位（v0.6.12）

用户把两份 2.3 MB 的日志放到本机 `work/logs/`。先用新写的 `dm_log_summarize()`
（`smo/host/logsum.c`，同类消息归一计数 + 错误行 + 尾部原文）压到 67 KB 再读 —— 27038 行里：

```
×24443  NVN_RESOURCE_MISS type=12 object=0x16df40068（render command skipped）   29.7~35.0 s 场景切换
×129    NVN_METAL_RESOURCE_UNSUPPORTED texture=… format=52 … render=1           深度附件仍解析不出来
×294    NVN_GPU_RENDER_ENCODING_FAILED op=105 → 每遍渲染被跳过 → 黑屏
×165    NVN_COMMAND_UNSUPPORTED nvnCommandBufferDispatchCompute                计算着色器未实现
×165    NVN_SHADER_EXEC_MATCH_FAILED program=23481 … matches=0                  对应程序也没匹配上
×32     AUDIO_DEVICE_PCM peak=0 input_peak=0                                    仍然无声
```

**黑屏链条**：场景切换 → 纹理/内存池重建（`MemoryPoolInitialize` ×578）→ 录下的命令仍引用旧对象 →
`nvn_Metal` 解析附件时查不到 → 整遍渲染跳过 → 全黑。而 `NVN_METAL_TEXTURE_REJECT` 一次都没出现，
说明失败发生在**纹理视图**（`texture_view` 返回 nil，那条路原来不记原因）：深度格式上带
「模板面」视图被直接判失败。

修法（三层）：
1. `nvn_state` 增加**退休表**：`Finalize` 先抄一份再删 —— 公开 API 仍按「已删除」处理
   （`nvn_selftest` 的两条断言继续盯着），渲染路径查不到时回落退休表（NVN 按地址访问的语义）
2. `nvn_metal_resources`：深度格式上的模板面视图不再直接失败；渲染目标的视图建不出来时**退回基础纹理**
3. 音频诊断：`AUDIO_SINK_POST_PROCESS` 的过滤条件（`bufs<=16`）写错了，日志里 `buffers=48` 永远不满足
   → 放宽到 64，并打进处理后前 4 个采样值

另外 `dm_log_summarize()` 已接进 App 的「导出日志」：以后导出会同时产出 `SMO-log-summary-*.txt`
（几十 KB，直接发聊天窗口即可）。`logsum_selftest` 覆盖：比原日志小一个量级、同类合并计数正确、
错误行与最后一行保留、空日志/缺失源文件的错误路径。

## 2.127 真机第十一轮：游戏世界里黑屏后闪退 = RG11B10F 被当深度附件（v0.6.19 → v0.6.20）

v0.6.19 声音正常、标题画面可见。按 Start 进入游戏世界后黑屏，几秒后闪退。两份日志的尾部：

```
[smo] [nvn] NVN_METAL_RENDER_UNSUPPORTED render pipeline            ×235（53.2~56.6 s）
[smo] [nvn] NVN_METAL_BINDING_UNRESOLVED stage=0 name=vp_c1          多次
validateWithDevice:5101: failed assertion `Render Pipeline Descriptor Validation
depthAttachmentPixelFormat MTLPixelFormatRG11B10Float is not depth renderable.'
【崩溃】SIGABRT …
```

**闪退链条**：游戏世界里有条绘制把「RG11B10F」格式的贴图绑成了深度目标（`pass_for` 里以前
任何非 Stencil8 格式都进 `depthAttachment`）→ `pipeline_for` 把它的 pixelFormat 抄进
`depthAttachmentPixelFormat` → Metal 校验断言直接 abort。v0.6.19 之前的日志里
`NVN_METAL_RESOURCE_UNSUPPORTED`/`TEXTURE_REJECT` 一次都没有，说明这张贴图**解析成功**，
不是附件解析失败，而是格式本身不是深度格式。

修法（守卫 + 证据，不猜）：
1. `pass_for`：深度附件格式必须可深度渲染（Depth16Unorm/Depth32Float/D32S8/D24S8），
   否则**丢这个深度附件继续画颜色**（不再 abort）。同时记一条 `NVN_METAL_DEPTH_TARGET_BAD`：
   完整 16 个描述字 + 视图状态（flags/levels/layers/format/target/swizzle/depth_stencil）+
   生效纹理格式/类型/层数/采样数 —— 下一轮日志直接给出「游戏到底绑了什么」的真相
2. `pipeline_for` / `clear_pipeline`：depthAttachmentPixelFormat / stencilAttachmentPixelFormat
   同样只接受合法格式（其余按 Invalid 处理），管线键同步
3. `set_depth_state`：深度附件被守卫丢弃时不再开深度写（避免「depth write enabled without
   depth attachment」校验告警）
4. 模板附件由「只有 Stencil8/D32S8」放宽到全部可模板渲染格式（X24/X32_Stencil8 等）

**黑屏取证**：之前 235 条「render pipeline」全部静默早退（管线键里某个状态不支持），日志里
没有原因。`pipeline_for` 每条早退路径现在各记一次 `NVN_METAL_PIPELINE_SKIP`（混合方程/混合因子/
采样数不匹配/多重采样状态/顶点布局），下一轮日志直接给出黑屏出处。同时修了一个真 bug：
**混合关闭时方程与因子不再参与硬件**，以前混合关闭但绑了不支持因子的绘制也会被丢
（NVN 语义里混合关闭时因子无意义）。

回归测试（macOS CI 可验）：`metal_render_selftest` 新增深度附件守卫用例 ——
RG11B10F 当深度目标 + 画颜色 → 不崩溃、颜色照画；DEPTH32F + ClearDepthStencil → 正常。
