# 计算着色器（离线部分，进行中）

游戏的计算着色器在 RomFS `ShaderData/*.szs` 的 `.sharcb` 里，和图形着色器同一个归档。
它们**没有** 0x12345678 槽位标记和 0x50 字节 SPH，所以 `smo/tools/sharcb.py` 的 `blobs()` 看不到，
之前的离线产物里一个 compute 都没有。

已确认的布局（以 `alComputeShader.sharcb` 为例）：

- 头部 dword 0x1c = 代码段起点；计算程序在代码段内按 0x100 对齐
- 程序记录（标记 0x98761234）按「相对代码段的偏移」引用代码
- 程序中间可以有 EXIT，不能按第一个 EXIT 切；`compute_jobs.py` 把起点到段尾整段交给翻译器，
  `dmsh_xlate --spans` 报出真实长度（ctx.Size）。`alComputeShader`：113 个候选起点 → 26 个互不重叠的程序

翻译：`dmsh_xlate` 需要打上 `../dmsh_xlate/patches/0001-ast-optimizer-keep-call-arguments-local.patch`。
原版 Ryujinx 的 AST 优化会把表达式传播进 `Call` 的实参，而 SPIR-V 代码生成要求实参是局部变量
（`GenerateCall` 里 `(AstOperand)` 强转）→ `InvalidCastException`。打补丁后 `alComputeShader` 25/25 翻译成功，
spirv-cross 25/25 出 `kernel`。

还没做：

1. 每个程序的 facts（`local` 线程组大小、`img` 图像类型/格式、`shared`）——目前全是缺省值，
   要从同名 `.sharc` 的 GLSL 推（`smo/tools/glsl_facts.py` 已认 `AGL_COMPUTE_SHADER`），并按程序记录配对
2. 扩到全部 18 个归档、进随包索引（没有 SPH：运行期匹配要单独一条路）
3. 宿主：录制 `DispatchCompute`、Metal 计算管线、缓冲/图像绑定、与图形绘制的同步
