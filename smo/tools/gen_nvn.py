#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 `smo/gfx/nvn/names.txt` 生成 NVN 函数表（`smo/gfx/nvn/nvn_table.c`）。

为什么生成：游戏通过 `nvnBootstrapLoader(名字)` 按名取接口，一共 469 个名字（从 main.bin 抽出来的）。
手写这张表必错；而且「哪些已实现、哪些还是桩」应该一眼看得出来。

表里每一项：
  · 名字在 IMPLEMENTED 集合里 → 指向 hle_nvn.c 里的真实现（前缀 nvn_）
  · 否则 → 指向统一的「未实现」入口（首次调用打印一行，返回 0/失败），
    与参考项目「未实现的 NVN 调用报红」的做法一致：真机日志里出现哪个名字，就是下一批要实现的。

用法：gen_nvn.py [--check]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NAMES = os.path.join(ROOT, "smo", "gfx", "nvn", "names.txt")
OUT = os.path.join(ROOT, "smo", "gfx", "nvn", "nvn_table.c")
INC = os.path.join(ROOT, "smo", "gfx", "nvn", "nvn_record_names.inc")

# 已经实现的：由 hle_nvn.c 提供，函数名 = nvn_<去掉前缀的名字>
# （逐步往这里加；加一个就把对应实现写进 hle_nvn.c）
# 已实现的：按**家族前缀**从游戏真实的名字表里选。
# 不手写名字 —— 我手写过两次都错了：游戏根本不调任何 *BuilderCreate（它直接在对象上 Initialize），
# 而 BeginRecord/EndRecord 的真名是 BeginRecording/EndRecording。名字表是唯一依据。
IMPLEMENTED_FAMILIES = [
    "nvnDevice", "nvnMemoryPool", "nvnBuffer", "nvnSync", "nvnWindow",
    "nvnProgram", "nvnTexture", "nvnSampler", "nvnQueue", "nvnEvent",
]
STATE_FAMILIES = ["nvn" + name for name in (
    "BlendState", "ColorState", "ChannelMaskState", "DepthStencilState",
    "PolygonState", "VertexAttribState", "VertexStreamState",
)]
IMPLEMENTED_FAMILIES += STATE_FAMILIES
MULTISAMPLE_IMPLEMENTED = {"nvnMultisampleStateSetDefaults"} | {
    "nvnMultisampleState"+op+field for op in ("Set","Get")
    for field in ("Samples","MultisampleEnable","AlphaToCoverageEnable","AlphaToCoverageDither")
}
RESOURCE_FAMILIES = ["nvnTextureView", "nvnTexturePool", "nvnSamplerPool"]
RESOURCE_HANDLES = {"nvnDeviceGet"+suffix for suffix in (
    "TextureHandle", "TexelFetchHandle", "ImageHandle", "SeparateTextureHandle", "SeparateSamplerHandle",
)}

# Command APIs are registered individually until the complete family exists.
COMMAND_IMPLEMENTED = {"nvnCommandBuffer" + suffix for suffix in (
    "Initialize", "Finalize", "SetMemoryCallback", "SetMemoryCallbackData",
    "GetMemoryCallback", "GetMemoryCallbackData", "AddCommandMemory", "AddControlMemory",
    "GetCommandMemorySize", "GetCommandMemoryUsed", "GetCommandMemoryFree",
    "GetControlMemorySize", "GetControlMemoryUsed", "GetControlMemoryFree",
    "BeginRecording", "EndRecording", "IsRecording", "CallCommands", "CopyCommands",
    "CopyBufferToBuffer", "UpdateUniformBuffer", "ClearBuffer", "Barrier", "SetDebugLabel",
    "SetRenderTargets", "ClearColor", "ClearDepthStencil", "SetViewports", "SetViewport",
    "SetScissors", "SetScissor", "SetDepthRanges", "SetDepthRange", "BindBlendState",
    "BindColorState", "BindChannelMaskState", "BindDepthStencilState", "BindPolygonState",
    "BindMultisampleState", "BindVertexAttribState", "BindVertexStreamState",
    "BindVertexBuffer", "BindVertexBuffers", "BindUniformBuffer", "BindUniformBuffers",
    "BindStorageBuffer", "BindStorageBuffers", "BindProgram", "SetTexturePool", "SetSamplerPool",
    "BindTexture", "BindTextures", "SetBlendColor", "SetShaderScratchMemory", "ReportCounter",
    "DrawArrays", "DrawArraysInstanced", "DrawElements", "DrawElementsInstanced", "DrawElementsBaseVertex",
    "DispatchCompute", "DispatchComputeIndirect", "BindImage", "BindImages",
)}
QUEUE_IMPLEMENTED = {"nvnQueue" + suffix for suffix in (
    "BuilderSetDefaults", "BuilderSetDevice", "BuilderSetFlags",
    "BuilderSetCommandMemorySize", "BuilderSetControlMemorySize", "BuilderSetComputeMemorySize",
    "BuilderSetCommandFlushThreshold", "BuilderSetQueueMemory", "BuilderGetQueueMemorySize",
    "Initialize", "Finalize", "SubmitCommands", "Flush", "Finish", "FenceSync", "WaitSync",
    "AcquireTexture", "PresentTexture",
)}

WINDOW_IMPLEMENTED = {"nvnWindow" + suffix for suffix in (
    "BuilderSetDefaults", "BuilderSetDevice", "BuilderSetNativeWindow", "BuilderSetTextures",
    "BuilderSetPresentInterval", "BuilderGetNativeWindow", "BuilderGetPresentInterval",
    "Initialize", "Finalize", "AcquireTexture", "SetCrop", "GetCrop", "SetPresentInterval",
    "GetPresentInterval", "GetNativeWindow", "SetDebugLabel",
)}

HEAD = """// 【自动生成，不要手改】由 smo/tools/gen_nvn.py 从 smo/gfx/nvn/names.txt 生成。
//
// 游戏通过 nvnBootstrapLoader(名字) 按名取接口；这张表就是「名字 → 宿主实现」。
// Named missing-API wrappers preserve each invoked name in runtime diagnostics.
// Missing command wrappers retain their existing submission rejection behavior.
#include "nvn_host.h"
#include "nvn_cmd.h"

"""


def main():
    names = []
    for line in open(NAMES, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            names.append(line)
    impl = {n for n in names if any(n.startswith(p) for p in IMPLEMENTED_FAMILIES)} | COMMAND_IMPLEMENTED | MULTISAMPLE_IMPLEMENTED
    missing = impl - set(names)
    if missing:
        print(f"🔴 IMPLEMENTED 里有 {len(missing)} 个名字不在 names.txt 里：{sorted(missing)[:5]}")
        return 1
    out = [HEAD]
    for n in sorted(impl):
        out.append(f"uint64_t nvn_{n[3:]}(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);")
    out.append("")
    # Record named gaps, report the whole batch, and reject submission before commit.
    missing_commands = sorted(n for n in names if n.startswith("nvnCommandBuffer") and n not in impl)
    out.extend([
        "#define NVN_MISSING_COMMAND(name) \\",
        "static uint64_t missing_##name(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, \\",
        "    uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) { \\",
        "    uint64_t args[8] = {a0,a1,a2,a3,a4,a5,a6,a7}; \\",
        '    return nvn_cmd_record_missing(#name,args); }',
    ])
    out.extend(f"NVN_MISSING_COMMAND({n})" for n in missing_commands)
    out.extend(["#undef NVN_MISSING_COMMAND", ""])
    missing_apis = sorted(set(names) - impl - set(missing_commands))
    for n in missing_apis:
        out.extend([
            f"static uint64_t missing_{n}(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {{",
            "    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;",
            f'    return nvn_unimplemented_named("{n}");', "}",
        ])
    out.append("static const nvn_fn missing_apis[] = {")
    out.extend(f"    missing_{n}," for n in missing_apis)
    out.extend(["};", "int nvn_is_unimplemented(nvn_fn fn) {",
                "    if(fn==nvn_unimplemented)return 1;",
                "    for(unsigned i=0;i<sizeof missing_apis/sizeof *missing_apis;i++)if(fn==missing_apis[i])return 1;",
                "    return 0;", "}", ""])
    out.append("static const nvn_fn missing_commands[] = {")
    out.extend(f"    (nvn_fn)missing_{n}," for n in missing_commands)
    out.extend([
        "};",
        "int nvn_is_missing_command(nvn_fn fn) {",
        "    for (unsigned i=0; i<sizeof missing_commands/sizeof *missing_commands; ++i)",
        "        if (missing_commands[i] == fn) return 1;",
        "    return 0;",
        "}", "",
    ])
    out.append("// 未实现：打印一次名字（含调用次数），返回 0")
    out.append("uint64_t nvn_unimplemented(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);")
    out.append("")
    # 「记录」桩：统一签名下一条宏就够，不需要逐个人工写（状态实现逐批替换掉它们）
    out.append("// 记录桩（生成）：把这次调用连同参数记下来，首次调用打印一行。")
    out.append("// 它们要按 NVN 的真实结构布局逐批换成真实现（见 gfx/README.md 的 TODO）。")
    out.append("const char *const g_nvn_record_names[] = {")
    for n in sorted(impl):
        out.append(f'    "{n}",')
    out.append("};")
    out.append(f"const unsigned g_nvn_record_n = {len(impl)};")
    out.append("")
    out.append("const nvn_ent g_nvn_table[] = {")
    for n in names:
        if n in impl:
            out.append(f'    {{"{n}", (nvn_fn)nvn_{n[3:]}}},')
        elif n in missing_commands:
            out.append(f'    {{"{n}", (nvn_fn)missing_{n}}},')
        else:
            out.append(f'    {{"{n}", (nvn_fn)missing_{n}}},')
    out.append("};")
    out.append(f"const unsigned g_nvn_table_n = {len(names)};")
    out.append(f"const unsigned g_nvn_impl_n = {len(impl)};")
    out.append("")
    text = "\n".join(out)
    if "--check" in sys.argv:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            print(f"🔴 {OUT} 与 names.txt 不一致：重跑 gen_nvn.py")
            return 1
        print(f"✓ {OUT} 一致（{len(names)} 个名字，其中已实现 {len(impl)}）")
        return 0
    open(OUT, "w", encoding="utf-8", newline="\n").write(text)
    print(f"已生成 {OUT}：{len(names)} 个名字，已实现 {len(impl)}，其余 {len(names) - len(impl)} 个接到未实现入口")
    return 0


if __name__ == "__main__":
    sys.exit(main())
