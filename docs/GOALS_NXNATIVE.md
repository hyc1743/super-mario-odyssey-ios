# nxnative 技术路径迁移目标草案

本文定义当前项目参考 `nxnative` 技术路径后的交付目标。游戏资源继续复用当前项目已有的 ExeFS、RomFS、RomFS 分卷和相关运行时资源，IPA 只包含运行时和必要的应用资源，以控制包体积。

## 总目标

交付一个可侧载安装的 iOS IPA，并满足以下条件：

- IPA 不重复打包大型游戏资源；
- 安装后复用用户当前 Documents 目录中的游戏资源；
- 保持当前项目已有资源目录和 `RomFS.smoa.N` 分卷格式兼容；
- 沿用 native execution、Horizon 服务宿主、NVN 到 Metal 的技术路线；
- 从标题界面启动逐步推进到完整关卡运行；
- 每个阶段都有可复现的日志、测试和验收条件。

## 当前实现进度

截至 2026-10-19，Goal 1 的资源检查和薄 IPA 构建入口已经实现；使用当前 `work/game` 资源验证通过，发现 4 个 ExeFS 模块和 4636 个 RomFS 文件，并生成了带 Build ID 与 SHA-256 的构建报告。Goal 5 已完成实体手柄接入、触控层自动隐藏/恢复以及 2D/3D 布局切换和持久化。Metal 运行时现在记录 shader/pipeline 缓存命中与未命中计数。`build_ipa.py --build --installable` 已能把资源检查、shell 构建和 Guest.framework 注入串成一条 macOS 流程；Windows 上已用现有 shell IPA 和 `work/rewrite` 产出并通过薄 IPA 检查。macOS/Xcode 构建、Metal 真机呈现、音频长时间运行和完整关卡仍需真机验收。

## Goal 1：薄 IPA 与现有资源复用

### 目标

让新 IPA 直接使用当前项目已有的游戏资源，不将 NSP、ExeFS、RomFS 和大型游戏内容复制进 IPA。

### 兼容资源布局

```text
Documents/
├── ExeFS/
├── RomFS/
├── RomFS.smoa.0
├── RomFS.smoa.1
├── ShaderData/       # 可选，兼容旧布局
├── save/
└── env.txt
```

### 验收条件

- 支持当前已有的 `Documents/ExeFS`；
- 支持当前已有的 `Documents/RomFS`；
- 支持当前的 `RomFS.smoa.N` 分卷格式；
- 资源缺失时显示明确的路径和修复提示；
- IPA 体积不随 RomFS 和游戏主体资源增长；
- 安装后能够自动发现现有资源并启动资源检查。

## Goal 2：统一构建流水线

### 目标

把资源检查、NSO 改写、模块验证、着色器处理和 IPA 构建串成一条可重复执行的流水线。

### 目标流程

```text
当前游戏资源
  → 资源检查
  → NSO 改写
  → 模块验证
  → 着色器提取/翻译
  → RuntimeShaders 归档
  → iOS 壳构建
  → IPA 输出
```

### 建议入口

```bash
python3 smo/tools/build_ipa.py \
  --resources <当前游戏资源目录> \
  --output SMOMobile.ipa
```

### 验收条件

- 重复构建时复用 shader 和 pipeline 缓存；
- 每个阶段都有独立日志；
- 构建报告记录游戏版本、Build ID、资源哈希和着色器数量；
- 资源版本不匹配时构建失败；
- 构建结果不依赖临时目录中的未声明文件。

## Goal 3：宿主和游戏模块稳定启动

### 目标

沿用当前项目的 native execution 路径，稳定加载并运行 `rtld`、`sdk`、`subsdk0` 和 `main`。

### 验收条件

- NSO 改写结果通过结构和等价性检查；
- 模块加载顺序和重定位结果稳定；
- `nnMain` 能进入并持续运行；
- svc、线程、TLS、时钟和文件服务不会返回未初始化值；
- 首次启动不会因字体、RomFS 或 shader archive 错误直接崩溃；
- 日志记录第一个失败服务、调用模块和调用次数。

## Goal 4：NVN 到 Metal 的真实渲染闭环

### 目标

让游戏的 NVN 调用进入真实 Metal 渲染路径，并通过 `CAMetalLayer` 显示游戏画面。

### 验收条件

- 完成 NVN device、queue、memory、texture、sampler、program 和 window 初始化；
- 支持 framebuffer、depth/stencil attachment、viewport 和 scissor；
- 支持 RuntimeShaders 中的 vertex/fragment shader；
- 使用稳定的 pipeline key 缓存；
- 至少显示清屏、标题画面和一个真实 draw；
- 前后台切换后 Metal 资源可以恢复；
- 真机连续运行 30 分钟不出现黑屏或持续的 command buffer 错误。

## Goal 5：触控与实体手柄

### 目标

将当前双摇杆和 16 键输入升级为可切换、可持久化的 iOS 输入系统。

### 验收条件

- 保留当前双摇杆和 16 键映射；
- 增加 2D 和 3D 两套触控布局；
- 保存用户选择并在下次启动恢复；
- 支持 `GameController`；
- 实体手柄连接后隐藏触控按钮；
- 实体手柄断开后恢复触控；
- 后台、锁屏和中断时释放所有按键与摇杆状态。

## Goal 6：音频稳定输出

### 目标

完成 Audren 到 PCM ring buffer 再到 iOS 音频设备的长期稳定输出。

### 验收条件

- 游戏音频能够持续进入当前 PCM ring buffer；
- RemoteIO 和 `AVAudioSession` 正常播放；
- 切后台再恢复后音频继续输出；
- 音频中断和 Media Services reset 后能够自动重建；
- 记录 callbacks、played、underrun 和 dropped；
- 真机连续播放 30 分钟无持续静音、爆音或明显断裂。

## Goal 7：运行时诊断与缓存

### 目标

建立可定位首个失败点的运行时诊断，并减少后续启动和场景切换的编译卡顿。

### 验收条件

- 输出 `log.txt` 和上一轮 `log.prev.txt`；
- 记录 shader 编译、pipeline 创建、texture 上传和 GPU 错误；
- 支持 `Documents/env.txt` 修改运行参数；
- 支持 shader 和 pipeline cache；
- 记录缓存命中率和编译耗时；
- 支持导出失败 shader、帧截图和 Metal 错误；
- 能区分资源错误、服务错误、NVN 错误和 Metal 错误。

## Goal 8：IPA 交付

### 目标

生成可侧载安装的最终 IPA，并让用户能够复用当前游戏资源完成安装运行。

### 验收条件

- GitHub Actions 或 macOS 本地均可构建；
- 生成未签名或可重新签名 IPA；
- IPA 不包含大型游戏主体资源；
- IPA 包含完整运行时和必要的 RuntimeShaders；
- 用户只需将当前游戏资源放入 Documents；
- 安装后能够自动识别资源并进入启动流程；
- 提供包体积、资源目录、安装步骤和已知限制说明。

## 阶段交付顺序

1. 薄 IPA 和当前资源识别；
2. 统一构建脚本；
3. 标题画面稳定启动；
4. Metal 真实呈现；
5. 触控和实体手柄切换；
6. 音频持续输出；
7. shader/pipeline 缓存；
8. 完整关卡和长时间稳定性验证。

## 第一版交付物

```text
SMOMobile.ipa
build_report.json
README_INSTALL.md
resource_layout.md
```

其中 IPA 不携带游戏主体资源，`resource_layout.md` 说明如何复用当前项目已有的 `ExeFS`、`RomFS`、RomFS 分卷和存档目录。

## 当前范围外

- 不重新分发游戏内容；
- 不改变当前游戏资源格式；
- 不把完整 RomFS 或 NSP 纳入 IPA；
- 不在第一阶段承诺联网、amiibo 或其他在线功能；
- 不把未经真机验证的完整关卡运行标记为已完成。
