# 计算着色器

游戏的计算着色器只在 RomFS `ShaderData/alComputeShader.szs` 的 `.sharcb` 里（25 个程序）。它们**没有**
0x12345678 槽位标记和 0x50 字节 SPH，所以 `smo/tools/sharcb.py` 的 `blobs()` 看不到。

## 离线链路

```
compute_jobs.py jobs   <RomFS> <out>          # 按程序记录出作业（每个程序 = 一个代码偏移 + 线程组大小）
dmsh_xlate --spans <out>/candidates.json <out>/spans
compute_jobs.py select <out> <out>/spans      # 按真实长度切出代码，按内容键（sha256 前 16 位）
dmsh_xlate <out>/jobs.json <out>/msl          # SPIR-V + res.json
compute_fixture.py --jobs <out>/jobs.json --translated <out>/msl --romfs <RomFS> --out compute.zip
```

`compute.zip` 与图形着色器 fixture 同格式（`.metal` / `.bindings.json` / `shaders.idx` / `manifest.json`），
由 `smo/ios/tools/prepare_runtime_shaders.py --extra` 合并进随包。它含游戏数据，放私有仓
`input/boot-compute-shaders.zip`，工作流按 commit 与 sha256 固定。

布局（`alComputeShader.sharcb`）：

- 头部 dword 0x1c = 代码段起点
- 程序记录：dwords `N, 3, 0, N-0x10, code_offset, 0, 0x7d1, 0x60`，`code_offset` 相对代码段。
  完整记录（≥0x7c4 字节）在 +0x7b8 存 GLSL 的 `local_size`；短的变体记录在 +0x1c 存回指完整记录的有符号偏移
- 记录 +0x70 是 NVN 控制段（标记 0x98761234），+0x700/+0x704 是 c1 常量段在代码里的范围
- 程序中间可以有 EXIT，长度以翻译器解码出的 ctx.Size 为准

翻译器要打 `../dmsh_xlate/patches/0001-ast-optimizer-keep-call-arguments-local.patch`：原版 Ryujinx 的
AST 优化把表达式传进 `Call` 实参，SPIR-V 代码生成要求实参是局部变量 → `InvalidCastException`。
`C:/toolchain/dmsh_xlate` 是旧版（没有 `--spans`），要用仓内源码重编（`-p:RyuSrc=` 指向打过补丁的副本）。

## 绑定约定（Maxwell / NVN 计算阶段）

| 着色器里 | 含义 | 运行期从哪来 |
|---|---|---|
| `cp_c{3+r}` | uniform 缓冲 r | 计算阶段的 BindUniformBuffer(r) |
| `cp_s*` | 存储缓冲：地址在 c0[0x310 + 16 r] | 计算阶段的 BindStorageBuffer(r) |
| `cp_c1` | 编译器常量段 | 控制段 +0x700/+0x704 |
| `cp_c0` | 驱动段 | 现填：存储表（0x310..0x410）、0x200 = 网格大小（gl_NumWorkGroups） |
| `cp_i_*` | 图像 | c2 句柄 → 纹理池里的 image 注册 |

lane id：spirv-cross 把 `SubgroupLocalInvocationId` 译成 `thread_index_in_simdgroup`，只在 SIMD 宽 32 时等于
Maxwell 的 lane（Apple GPU 是 32）；运行期断言 `threadExecutionWidth == 32`。

## 现状

- 25 个程序全部翻译成功；24 个打包（剔除选择 / 顶点数组 / 间接绘制数据这一类剔除计算核）
- `alComputeClearTexture3D`（3D 图像写）暂不打包：图像句柄的格式还没核实，元数据里标为 unsupported
- 运行期：`nvn_metal_render.m` 的 `dispatch_compute`；`metal_compute_selftest` 在 CI 的真 Metal 上验证
  绑定 → 匹配 → 直接 / 间接派发 → 回读
- 真机还没验证过；游戏里每帧几十次的派发能否正确剔除、画面是否因此变化，要看真机日志
  （`NVN_METAL_COMPUTE_DISPATCH` / `NVN_METAL_DRAW_SKIPPED compute …`）
