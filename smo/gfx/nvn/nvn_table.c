// 【自动生成，不要手改】由 smo/tools/gen_nvn.py 从 smo/gfx/nvn/names.txt 生成。
//
// 游戏通过 nvnBootstrapLoader(名字) 按名取接口；这张表就是「名字 → 宿主实现」。
// Named missing-API wrappers preserve each invoked name in runtime diagnostics.
// Missing command wrappers retain their existing submission rejection behavior.
#include "nvn_host.h"
#include "nvn_cmd.h"


uint64_t nvn_BlendStateGetAdvancedMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateGetAdvancedNormalizedDst(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateGetAdvancedOverlap(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateGetAdvancedPremultipliedSrc(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateGetBlendEquation(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateGetBlendFunc(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateGetBlendTarget(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateSetAdvancedMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateSetAdvancedNormalizedDst(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateSetAdvancedOverlap(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateSetAdvancedPremultipliedSrc(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateSetBlendEquation(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateSetBlendFunc(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateSetBlendTarget(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BlendStateSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferBuilderGetMemoryOffset(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferBuilderGetMemoryPool(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferBuilderGetSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferBuilderSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferBuilderSetDevice(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferBuilderSetStorage(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferFlushMappedRange(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferGetAddress(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferGetDebugID(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferGetMemoryOffset(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferGetMemoryPool(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferGetSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferInvalidateMappedRange(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferMap(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_BufferSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ChannelMaskStateGetChannelMask(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ChannelMaskStateSetChannelMask(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ChannelMaskStateSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ColorStateGetAlphaTest(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ColorStateGetBlendEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ColorStateGetLogicOp(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ColorStateSetAlphaTest(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ColorStateSetBlendEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ColorStateSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ColorStateSetLogicOp(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferAddCommandMemory(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferAddControlMemory(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBarrier(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBeginRecording(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindBlendState(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindChannelMaskState(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindColorState(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindDepthStencilState(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindImage(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindImages(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindMultisampleState(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindPolygonState(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindProgram(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindStorageBuffer(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindStorageBuffers(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindTexture(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindTextures(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindUniformBuffer(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindUniformBuffers(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindVertexAttribState(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindVertexBuffer(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindVertexBuffers(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferBindVertexStreamState(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferCallCommands(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferClearBuffer(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferClearColor(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferClearDepthStencil(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferCopyBufferToBuffer(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferCopyCommands(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferDispatchCompute(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferDispatchComputeIndirect(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferDrawArrays(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferDrawArraysInstanced(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferDrawElements(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferDrawElementsBaseVertex(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferDrawElementsInstanced(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferEndRecording(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferGetCommandMemoryFree(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferGetCommandMemorySize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferGetCommandMemoryUsed(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferGetControlMemoryFree(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferGetControlMemorySize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferGetControlMemoryUsed(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferGetMemoryCallback(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferGetMemoryCallbackData(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferIsRecording(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferReportCounter(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetBlendColor(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetDepthRange(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetDepthRanges(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetMemoryCallback(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetMemoryCallbackData(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetRenderTargets(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetSamplerPool(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetScissor(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetScissors(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetShaderScratchMemory(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetTexturePool(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetViewport(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferSetViewports(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_CommandBufferUpdateUniformBuffer(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateGetDepthFunc(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateGetDepthTestEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateGetDepthWriteEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateGetStencilFunc(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateGetStencilOp(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateGetStencilTestEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateSetDepthFunc(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateSetDepthTestEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateSetDepthWriteEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateSetStencilFunc(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateSetStencilOp(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DepthStencilStateSetStencilTestEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceApplyDeferredFinalizes(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceBuilderSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceBuilderSetFlags(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceFinalizeCommandHandle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetCurrentTimestampInNanoseconds(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetDepthMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetImageHandle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetInteger(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetProcAddress(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetSeparateSamplerHandle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetSeparateTextureHandle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetTexelFetchHandle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetTextureHandle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetTimestampInNanoseconds(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceGetWindowOriginMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceInstallDebugCallback(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceRegisterFastClearColor(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceRegisterFastClearColori(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceRegisterFastClearColorui(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceRegisterFastClearDepth(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceSetDepthMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceSetIntermediateShaderCache(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceSetWindowOriginMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_DeviceWalkDebugDatabase(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolBuilderGetFlags(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolBuilderGetMemory(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolBuilderGetSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolBuilderSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolBuilderSetDevice(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolBuilderSetFlags(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolBuilderSetStorage(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolFlushMappedRange(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolGetBufferAddress(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolGetFlags(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolGetSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolInitializeEP13NVNmemoryPoolPK20(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolInvalidateMappedRange(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolMap(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolMapVirtual(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MemoryPoolSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MultisampleStateGetAlphaToCoverageDither(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MultisampleStateGetAlphaToCoverageEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MultisampleStateGetMultisampleEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MultisampleStateGetSamples(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MultisampleStateSetAlphaToCoverageDither(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MultisampleStateSetAlphaToCoverageEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MultisampleStateSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MultisampleStateSetMultisampleEnable(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_MultisampleStateSetSamples(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_PolygonStateGetCullFace(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_PolygonStateGetFrontFace(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_PolygonStateGetPolygonMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_PolygonStateGetPolygonOffsetEnables(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_PolygonStateSetCullFace(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_PolygonStateSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_PolygonStateSetFrontFace(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_PolygonStateSetPolygonMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_PolygonStateSetPolygonOffsetEnables(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ProgramFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ProgramInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ProgramSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ProgramSetShaders(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_ProgramSetSubroutineLinkage(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueAcquireTexture(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueBuilderGetQueueMemorySize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueBuilderSetCommandFlushThreshold(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueBuilderSetCommandMemorySize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueBuilderSetComputeMemorySize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueBuilderSetControlMemorySize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueBuilderSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueBuilderSetDevice(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueBuilderSetFlags(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueBuilderSetQueueMemory(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueFenceSync(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueFinish(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueFlush(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueGetError(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueGetTotalCommandMemoryUsed(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueGetTotalComputeMemoryUsed(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueGetTotalControlMemoryUsed(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueuePresentTexture(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueResetMemoryUsageCounts(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueSubmitCommands(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_QueueWaitSync(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetBorderColor(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetBorderColori(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetBorderColorui(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetCompare(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetLodBias(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetLodClamp(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetMaxAnisotropy(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetMinMagFilter(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetReductionFilter(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderGetWrapMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetBorderColor(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetBorderColori(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetBorderColorui(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetCompare(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetDevice(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetLodBias(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetLodClamp(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetMaxAnisotropy(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetMinMagFilter(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetReductionFilter(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerBuilderSetWrapMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerCompare(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetBorderColor(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetBorderColori(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetBorderColorui(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetCompare(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetDebugID(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetLodBias(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetLodClamp(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetMaxAnisotropy(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetMinMagFilter(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetReductionFilter(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerGetWrapMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerPoolFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerPoolGetMemoryOffset(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerPoolGetMemoryPool(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerPoolGetSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerPoolInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerPoolRegisterSampler(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerPoolRegisterSamplerBuilder(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerPoolSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SamplerSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SyncFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SyncInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SyncSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_SyncWait(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetDepth(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetDepthStencilMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetFlags(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetFormat(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetGLTextureName(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetHeight(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetLevels(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetMemoryOffset(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetMemoryPool(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetPackagedTextureData(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetSamples(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetSparseTileLayout(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetStorageAlignment(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetStorageClass(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetStorageSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetStride(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetSwizzle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetTarget(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetWidth(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderGetZCullStorageSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetDepth(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetDepthStencilMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetDevice(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetFlags(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetFormat(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetGLTextureName(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetHeight(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetLevels(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetPackagedTextureData(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetPackagedTextureLayout(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetSamples(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetSize1D(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetSize2D(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetSize3D(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetStorage(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetStride(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetSwizzle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetTarget(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureBuilderSetWidth(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureCompare(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureFlushTexels(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetDebugID(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetDepth(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetDepthStencilMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetFlags(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetFormat(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetHeight(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetLevels(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetMemoryOffset(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetMemoryPool(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetSamples(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetSparseTileLayout(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetStorageClass(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetStorageSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetStride(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetSwizzle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetTarget(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetTextureAddress(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetViewOffset(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetWidth(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureGetZCullStorageSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureInvalidateTexels(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TexturePoolFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TexturePoolGetMemoryOffset(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TexturePoolGetMemoryPool(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TexturePoolGetSize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TexturePoolInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TexturePoolRegisterImage(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TexturePoolRegisterTexture(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TexturePoolSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureReadTexels(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureReadTexelsStrided(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewCompare(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewGetDepthStencilMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewGetFormat(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewGetLayers(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewGetLevels(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewGetSwizzle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewGetTarget(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewSetDepthStencilMode(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewSetFormat(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewSetLayers(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewSetLevels(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewSetSwizzle(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureViewSetTarget(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureWriteTexels(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_TextureWriteTexelsStrided(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexAttribStateGetFormat(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexAttribStateGetStreamIndex(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexAttribStateSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexAttribStateSetFormat(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexAttribStateSetStreamIndex(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexStreamStateGetDivisor(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexStreamStateGetStride(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexStreamStateSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexStreamStateSetDivisor(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_VertexStreamStateSetStride(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowAcquireTexture(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowBuilderGetNativeWindow(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowBuilderGetPresentInterval(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowBuilderSetDefaults(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowBuilderSetDevice(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowBuilderSetNativeWindow(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowBuilderSetPresentInterval(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowBuilderSetTextures(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowFinalize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowGetCrop(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowGetNativeWindow(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowGetPresentInterval(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowInitialize(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowSetCrop(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowSetDebugLabel(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t nvn_WindowSetPresentInterval(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

#define NVN_MISSING_COMMAND(name) \
static uint64_t missing_##name(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, \
    uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) { \
    uint64_t args[8] = {a0,a1,a2,a3,a4,a5,a6,a7}; \
    return nvn_cmd_record_missing(#name,args); }
NVN_MISSING_COMMAND(nvnCommandBufferBarrierEPNS_11DrawContextENS)
NVN_MISSING_COMMAND(nvnCommandBufferBarrier_ShaderEPNS_11DrawCon)
NVN_MISSING_COMMAND(nvnCommandBufferBeginTransformFeedback)
NVN_MISSING_COMMAND(nvnCommandBufferBindCoverageModulationTable)
NVN_MISSING_COMMAND(nvnCommandBufferBindImageEPNS_11DrawContextE)
NVN_MISSING_COMMAND(nvnCommandBufferBindSeparateSampler)
NVN_MISSING_COMMAND(nvnCommandBufferBindSeparateSamplers)
NVN_MISSING_COMMAND(nvnCommandBufferBindSeparateTexture)
NVN_MISSING_COMMAND(nvnCommandBufferBindSeparateTextures)
NVN_MISSING_COMMAND(nvnCommandBufferBindTextureEPNS_11DrawContex)
NVN_MISSING_COMMAND(nvnCommandBufferBindTransformFeedbackBuffer)
NVN_MISSING_COMMAND(nvnCommandBufferBindTransformFeedbackBuffers)
NVN_MISSING_COMMAND(nvnCommandBufferClearColori)
NVN_MISSING_COMMAND(nvnCommandBufferClearColorui)
NVN_MISSING_COMMAND(nvnCommandBufferClearTexture)
NVN_MISSING_COMMAND(nvnCommandBufferClearTexturei)
NVN_MISSING_COMMAND(nvnCommandBufferClearTextureui)
NVN_MISSING_COMMAND(nvnCommandBufferCopyBufferToTexture)
NVN_MISSING_COMMAND(nvnCommandBufferCopyTextureToBuffer)
NVN_MISSING_COMMAND(nvnCommandBufferCopyTextureToTexture)
NVN_MISSING_COMMAND(nvnCommandBufferDiscardColor)
NVN_MISSING_COMMAND(nvnCommandBufferDiscardDepthStencil)
NVN_MISSING_COMMAND(nvnCommandBufferDownsample)
NVN_MISSING_COMMAND(nvnCommandBufferDrawArraysIndirect)
NVN_MISSING_COMMAND(nvnCommandBufferDrawElementsIndirect)
NVN_MISSING_COMMAND(nvnCommandBufferDrawTexture)
NVN_MISSING_COMMAND(nvnCommandBufferDrawTransformFeedback)
NVN_MISSING_COMMAND(nvnCommandBufferEndTransformFeedback)
NVN_MISSING_COMMAND(nvnCommandBufferFenceSync)
NVN_MISSING_COMMAND(nvnCommandBufferGetCopyImageStride)
NVN_MISSING_COMMAND(nvnCommandBufferGetCopyRowStride)
NVN_MISSING_COMMAND(nvnCommandBufferInsertDebugMarker)
NVN_MISSING_COMMAND(nvnCommandBufferMultiDrawArraysIndirectCount)
NVN_MISSING_COMMAND(nvnCommandBufferMultiDrawElementsIndirectCou)
NVN_MISSING_COMMAND(nvnCommandBufferPauseTransformFeedback)
NVN_MISSING_COMMAND(nvnCommandBufferPopDebugGroup)
NVN_MISSING_COMMAND(nvnCommandBufferPopDebugGroupId)
NVN_MISSING_COMMAND(nvnCommandBufferPushDebugGroup)
NVN_MISSING_COMMAND(nvnCommandBufferPushDebugGroupDynamic)
NVN_MISSING_COMMAND(nvnCommandBufferPushDebugGroupStatic)
NVN_MISSING_COMMAND(nvnCommandBufferReportValue)
NVN_MISSING_COMMAND(nvnCommandBufferResetCounter)
NVN_MISSING_COMMAND(nvnCommandBufferResolveDepthBuffer)
NVN_MISSING_COMMAND(nvnCommandBufferRestoreZCullData)
NVN_MISSING_COMMAND(nvnCommandBufferResumeTransformFeedback)
NVN_MISSING_COMMAND(nvnCommandBufferSaveZCullData)
NVN_MISSING_COMMAND(nvnCommandBufferSetAlphaRef)
NVN_MISSING_COMMAND(nvnCommandBufferSetConservativeRasterDilate)
NVN_MISSING_COMMAND(nvnCommandBufferSetConservativeRasterEnable)
NVN_MISSING_COMMAND(nvnCommandBufferSetCopyImageStride)
NVN_MISSING_COMMAND(nvnCommandBufferSetCopyRowStride)
NVN_MISSING_COMMAND(nvnCommandBufferSetDepthBounds)
NVN_MISSING_COMMAND(nvnCommandBufferSetDepthClamp)
NVN_MISSING_COMMAND(nvnCommandBufferSetInnerTessellationLevels)
NVN_MISSING_COMMAND(nvnCommandBufferSetLineWidth)
NVN_MISSING_COMMAND(nvnCommandBufferSetOuterTessellationLevels)
NVN_MISSING_COMMAND(nvnCommandBufferSetPatchSize)
NVN_MISSING_COMMAND(nvnCommandBufferSetPointSize)
NVN_MISSING_COMMAND(nvnCommandBufferSetPolygonOffsetClamp)
NVN_MISSING_COMMAND(nvnCommandBufferSetPrimitiveRestart)
NVN_MISSING_COMMAND(nvnCommandBufferSetProgramSubroutines)
NVN_MISSING_COMMAND(nvnCommandBufferSetRasterizerDiscard)
NVN_MISSING_COMMAND(nvnCommandBufferSetRenderEnable)
NVN_MISSING_COMMAND(nvnCommandBufferSetRenderEnableConditional)
NVN_MISSING_COMMAND(nvnCommandBufferSetSampleMask)
NVN_MISSING_COMMAND(nvnCommandBufferSetStencilMask)
NVN_MISSING_COMMAND(nvnCommandBufferSetStencilRef)
NVN_MISSING_COMMAND(nvnCommandBufferSetStencilValueMask)
NVN_MISSING_COMMAND(nvnCommandBufferSetSubpixelPrecisionBias)
NVN_MISSING_COMMAND(nvnCommandBufferSetTiledCacheAction)
NVN_MISSING_COMMAND(nvnCommandBufferSetTiledCacheTileSize)
NVN_MISSING_COMMAND(nvnCommandBufferSetViewportSwizzles)
NVN_MISSING_COMMAND(nvnCommandBufferTiledDownsample)
NVN_MISSING_COMMAND(nvnCommandBufferWaitSync)
#undef NVN_MISSING_COMMAND

static uint64_t missing_nvnBootstrapLoader(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnBootstrapLoader");
}
static uint64_t missing_nvnDebugCallbackE22NVNdebugCallbackSource20N(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnDebugCallbackE22NVNdebugCallbackSource20N");
}
static uint64_t missing_nvnLoadCProcs(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnLoadCProcs");
}
static uint64_t missing_nvnMultisampleStateGetCoverageModulationMode(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateGetCoverageModulationMode");
}
static uint64_t missing_nvnMultisampleStateGetCoverageToColorEnable(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateGetCoverageToColorEnable");
}
static uint64_t missing_nvnMultisampleStateGetCoverageToColorOutput(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateGetCoverageToColorOutput");
}
static uint64_t missing_nvnMultisampleStateGetRasterSamples(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateGetRasterSamples");
}
static uint64_t missing_nvnMultisampleStateGetSampleLocationsEnable(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateGetSampleLocationsEnable");
}
static uint64_t missing_nvnMultisampleStateGetSampleLocationsGrid(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateGetSampleLocationsGrid");
}
static uint64_t missing_nvnMultisampleStateGetSampleLocationsGridEna(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateGetSampleLocationsGridEna");
}
static uint64_t missing_nvnMultisampleStateSetCoverageModulationMode(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateSetCoverageModulationMode");
}
static uint64_t missing_nvnMultisampleStateSetCoverageToColorEnable(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateSetCoverageToColorEnable");
}
static uint64_t missing_nvnMultisampleStateSetCoverageToColorOutput(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateSetCoverageToColorOutput");
}
static uint64_t missing_nvnMultisampleStateSetRasterSamples(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateSetRasterSamples");
}
static uint64_t missing_nvnMultisampleStateSetSampleLocations(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateSetSampleLocations");
}
static uint64_t missing_nvnMultisampleStateSetSampleLocationsEnable(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateSetSampleLocationsEnable");
}
static uint64_t missing_nvnMultisampleStateSetSampleLocationsGridEna(uint64_t a0,uint64_t a1,uint64_t a2,uint64_t a3,uint64_t a4,uint64_t a5,uint64_t a6,uint64_t a7) {
    (void)a0;(void)a1;(void)a2;(void)a3;(void)a4;(void)a5;(void)a6;(void)a7;
    return nvn_unimplemented_named("nvnMultisampleStateSetSampleLocationsGridEna");
}
static const nvn_fn missing_apis[] = {
    missing_nvnBootstrapLoader,
    missing_nvnDebugCallbackE22NVNdebugCallbackSource20N,
    missing_nvnLoadCProcs,
    missing_nvnMultisampleStateGetCoverageModulationMode,
    missing_nvnMultisampleStateGetCoverageToColorEnable,
    missing_nvnMultisampleStateGetCoverageToColorOutput,
    missing_nvnMultisampleStateGetRasterSamples,
    missing_nvnMultisampleStateGetSampleLocationsEnable,
    missing_nvnMultisampleStateGetSampleLocationsGrid,
    missing_nvnMultisampleStateGetSampleLocationsGridEna,
    missing_nvnMultisampleStateSetCoverageModulationMode,
    missing_nvnMultisampleStateSetCoverageToColorEnable,
    missing_nvnMultisampleStateSetCoverageToColorOutput,
    missing_nvnMultisampleStateSetRasterSamples,
    missing_nvnMultisampleStateSetSampleLocations,
    missing_nvnMultisampleStateSetSampleLocationsEnable,
    missing_nvnMultisampleStateSetSampleLocationsGridEna,
};
int nvn_is_unimplemented(nvn_fn fn) {
    if(fn==nvn_unimplemented)return 1;
    for(unsigned i=0;i<sizeof missing_apis/sizeof *missing_apis;i++)if(fn==missing_apis[i])return 1;
    return 0;
}

static const nvn_fn missing_commands[] = {
    (nvn_fn)missing_nvnCommandBufferBarrierEPNS_11DrawContextENS,
    (nvn_fn)missing_nvnCommandBufferBarrier_ShaderEPNS_11DrawCon,
    (nvn_fn)missing_nvnCommandBufferBeginTransformFeedback,
    (nvn_fn)missing_nvnCommandBufferBindCoverageModulationTable,
    (nvn_fn)missing_nvnCommandBufferBindImageEPNS_11DrawContextE,
    (nvn_fn)missing_nvnCommandBufferBindSeparateSampler,
    (nvn_fn)missing_nvnCommandBufferBindSeparateSamplers,
    (nvn_fn)missing_nvnCommandBufferBindSeparateTexture,
    (nvn_fn)missing_nvnCommandBufferBindSeparateTextures,
    (nvn_fn)missing_nvnCommandBufferBindTextureEPNS_11DrawContex,
    (nvn_fn)missing_nvnCommandBufferBindTransformFeedbackBuffer,
    (nvn_fn)missing_nvnCommandBufferBindTransformFeedbackBuffers,
    (nvn_fn)missing_nvnCommandBufferClearColori,
    (nvn_fn)missing_nvnCommandBufferClearColorui,
    (nvn_fn)missing_nvnCommandBufferClearTexture,
    (nvn_fn)missing_nvnCommandBufferClearTexturei,
    (nvn_fn)missing_nvnCommandBufferClearTextureui,
    (nvn_fn)missing_nvnCommandBufferCopyBufferToTexture,
    (nvn_fn)missing_nvnCommandBufferCopyTextureToBuffer,
    (nvn_fn)missing_nvnCommandBufferCopyTextureToTexture,
    (nvn_fn)missing_nvnCommandBufferDiscardColor,
    (nvn_fn)missing_nvnCommandBufferDiscardDepthStencil,
    (nvn_fn)missing_nvnCommandBufferDownsample,
    (nvn_fn)missing_nvnCommandBufferDrawArraysIndirect,
    (nvn_fn)missing_nvnCommandBufferDrawElementsIndirect,
    (nvn_fn)missing_nvnCommandBufferDrawTexture,
    (nvn_fn)missing_nvnCommandBufferDrawTransformFeedback,
    (nvn_fn)missing_nvnCommandBufferEndTransformFeedback,
    (nvn_fn)missing_nvnCommandBufferFenceSync,
    (nvn_fn)missing_nvnCommandBufferGetCopyImageStride,
    (nvn_fn)missing_nvnCommandBufferGetCopyRowStride,
    (nvn_fn)missing_nvnCommandBufferInsertDebugMarker,
    (nvn_fn)missing_nvnCommandBufferMultiDrawArraysIndirectCount,
    (nvn_fn)missing_nvnCommandBufferMultiDrawElementsIndirectCou,
    (nvn_fn)missing_nvnCommandBufferPauseTransformFeedback,
    (nvn_fn)missing_nvnCommandBufferPopDebugGroup,
    (nvn_fn)missing_nvnCommandBufferPopDebugGroupId,
    (nvn_fn)missing_nvnCommandBufferPushDebugGroup,
    (nvn_fn)missing_nvnCommandBufferPushDebugGroupDynamic,
    (nvn_fn)missing_nvnCommandBufferPushDebugGroupStatic,
    (nvn_fn)missing_nvnCommandBufferReportValue,
    (nvn_fn)missing_nvnCommandBufferResetCounter,
    (nvn_fn)missing_nvnCommandBufferResolveDepthBuffer,
    (nvn_fn)missing_nvnCommandBufferRestoreZCullData,
    (nvn_fn)missing_nvnCommandBufferResumeTransformFeedback,
    (nvn_fn)missing_nvnCommandBufferSaveZCullData,
    (nvn_fn)missing_nvnCommandBufferSetAlphaRef,
    (nvn_fn)missing_nvnCommandBufferSetConservativeRasterDilate,
    (nvn_fn)missing_nvnCommandBufferSetConservativeRasterEnable,
    (nvn_fn)missing_nvnCommandBufferSetCopyImageStride,
    (nvn_fn)missing_nvnCommandBufferSetCopyRowStride,
    (nvn_fn)missing_nvnCommandBufferSetDepthBounds,
    (nvn_fn)missing_nvnCommandBufferSetDepthClamp,
    (nvn_fn)missing_nvnCommandBufferSetInnerTessellationLevels,
    (nvn_fn)missing_nvnCommandBufferSetLineWidth,
    (nvn_fn)missing_nvnCommandBufferSetOuterTessellationLevels,
    (nvn_fn)missing_nvnCommandBufferSetPatchSize,
    (nvn_fn)missing_nvnCommandBufferSetPointSize,
    (nvn_fn)missing_nvnCommandBufferSetPolygonOffsetClamp,
    (nvn_fn)missing_nvnCommandBufferSetPrimitiveRestart,
    (nvn_fn)missing_nvnCommandBufferSetProgramSubroutines,
    (nvn_fn)missing_nvnCommandBufferSetRasterizerDiscard,
    (nvn_fn)missing_nvnCommandBufferSetRenderEnable,
    (nvn_fn)missing_nvnCommandBufferSetRenderEnableConditional,
    (nvn_fn)missing_nvnCommandBufferSetSampleMask,
    (nvn_fn)missing_nvnCommandBufferSetStencilMask,
    (nvn_fn)missing_nvnCommandBufferSetStencilRef,
    (nvn_fn)missing_nvnCommandBufferSetStencilValueMask,
    (nvn_fn)missing_nvnCommandBufferSetSubpixelPrecisionBias,
    (nvn_fn)missing_nvnCommandBufferSetTiledCacheAction,
    (nvn_fn)missing_nvnCommandBufferSetTiledCacheTileSize,
    (nvn_fn)missing_nvnCommandBufferSetViewportSwizzles,
    (nvn_fn)missing_nvnCommandBufferTiledDownsample,
    (nvn_fn)missing_nvnCommandBufferWaitSync,
};
int nvn_is_missing_command(nvn_fn fn) {
    for (unsigned i=0; i<sizeof missing_commands/sizeof *missing_commands; ++i)
        if (missing_commands[i] == fn) return 1;
    return 0;
}

// 未实现：打印一次名字（含调用次数），返回 0
uint64_t nvn_unimplemented(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

// 记录桩（生成）：把这次调用连同参数记下来，首次调用打印一行。
// 它们要按 NVN 的真实结构布局逐批换成真实现（见 gfx/README.md 的 TODO）。
const char *const g_nvn_record_names[] = {
    "nvnBlendStateGetAdvancedMode",
    "nvnBlendStateGetAdvancedNormalizedDst",
    "nvnBlendStateGetAdvancedOverlap",
    "nvnBlendStateGetAdvancedPremultipliedSrc",
    "nvnBlendStateGetBlendEquation",
    "nvnBlendStateGetBlendFunc",
    "nvnBlendStateGetBlendTarget",
    "nvnBlendStateSetAdvancedMode",
    "nvnBlendStateSetAdvancedNormalizedDst",
    "nvnBlendStateSetAdvancedOverlap",
    "nvnBlendStateSetAdvancedPremultipliedSrc",
    "nvnBlendStateSetBlendEquation",
    "nvnBlendStateSetBlendFunc",
    "nvnBlendStateSetBlendTarget",
    "nvnBlendStateSetDefaults",
    "nvnBufferBuilderGetMemoryOffset",
    "nvnBufferBuilderGetMemoryPool",
    "nvnBufferBuilderGetSize",
    "nvnBufferBuilderSetDefaults",
    "nvnBufferBuilderSetDevice",
    "nvnBufferBuilderSetStorage",
    "nvnBufferFinalize",
    "nvnBufferFlushMappedRange",
    "nvnBufferGetAddress",
    "nvnBufferGetDebugID",
    "nvnBufferGetMemoryOffset",
    "nvnBufferGetMemoryPool",
    "nvnBufferGetSize",
    "nvnBufferInitialize",
    "nvnBufferInvalidateMappedRange",
    "nvnBufferMap",
    "nvnBufferSetDebugLabel",
    "nvnChannelMaskStateGetChannelMask",
    "nvnChannelMaskStateSetChannelMask",
    "nvnChannelMaskStateSetDefaults",
    "nvnColorStateGetAlphaTest",
    "nvnColorStateGetBlendEnable",
    "nvnColorStateGetLogicOp",
    "nvnColorStateSetAlphaTest",
    "nvnColorStateSetBlendEnable",
    "nvnColorStateSetDefaults",
    "nvnColorStateSetLogicOp",
    "nvnCommandBufferAddCommandMemory",
    "nvnCommandBufferAddControlMemory",
    "nvnCommandBufferBarrier",
    "nvnCommandBufferBeginRecording",
    "nvnCommandBufferBindBlendState",
    "nvnCommandBufferBindChannelMaskState",
    "nvnCommandBufferBindColorState",
    "nvnCommandBufferBindDepthStencilState",
    "nvnCommandBufferBindImage",
    "nvnCommandBufferBindImages",
    "nvnCommandBufferBindMultisampleState",
    "nvnCommandBufferBindPolygonState",
    "nvnCommandBufferBindProgram",
    "nvnCommandBufferBindStorageBuffer",
    "nvnCommandBufferBindStorageBuffers",
    "nvnCommandBufferBindTexture",
    "nvnCommandBufferBindTextures",
    "nvnCommandBufferBindUniformBuffer",
    "nvnCommandBufferBindUniformBuffers",
    "nvnCommandBufferBindVertexAttribState",
    "nvnCommandBufferBindVertexBuffer",
    "nvnCommandBufferBindVertexBuffers",
    "nvnCommandBufferBindVertexStreamState",
    "nvnCommandBufferCallCommands",
    "nvnCommandBufferClearBuffer",
    "nvnCommandBufferClearColor",
    "nvnCommandBufferClearDepthStencil",
    "nvnCommandBufferCopyBufferToBuffer",
    "nvnCommandBufferCopyCommands",
    "nvnCommandBufferDispatchCompute",
    "nvnCommandBufferDispatchComputeIndirect",
    "nvnCommandBufferDrawArrays",
    "nvnCommandBufferDrawArraysInstanced",
    "nvnCommandBufferDrawElements",
    "nvnCommandBufferDrawElementsBaseVertex",
    "nvnCommandBufferDrawElementsInstanced",
    "nvnCommandBufferEndRecording",
    "nvnCommandBufferFinalize",
    "nvnCommandBufferGetCommandMemoryFree",
    "nvnCommandBufferGetCommandMemorySize",
    "nvnCommandBufferGetCommandMemoryUsed",
    "nvnCommandBufferGetControlMemoryFree",
    "nvnCommandBufferGetControlMemorySize",
    "nvnCommandBufferGetControlMemoryUsed",
    "nvnCommandBufferGetMemoryCallback",
    "nvnCommandBufferGetMemoryCallbackData",
    "nvnCommandBufferInitialize",
    "nvnCommandBufferIsRecording",
    "nvnCommandBufferReportCounter",
    "nvnCommandBufferSetBlendColor",
    "nvnCommandBufferSetDebugLabel",
    "nvnCommandBufferSetDepthRange",
    "nvnCommandBufferSetDepthRanges",
    "nvnCommandBufferSetMemoryCallback",
    "nvnCommandBufferSetMemoryCallbackData",
    "nvnCommandBufferSetRenderTargets",
    "nvnCommandBufferSetSamplerPool",
    "nvnCommandBufferSetScissor",
    "nvnCommandBufferSetScissors",
    "nvnCommandBufferSetShaderScratchMemory",
    "nvnCommandBufferSetTexturePool",
    "nvnCommandBufferSetViewport",
    "nvnCommandBufferSetViewports",
    "nvnCommandBufferUpdateUniformBuffer",
    "nvnDepthStencilStateGetDepthFunc",
    "nvnDepthStencilStateGetDepthTestEnable",
    "nvnDepthStencilStateGetDepthWriteEnable",
    "nvnDepthStencilStateGetStencilFunc",
    "nvnDepthStencilStateGetStencilOp",
    "nvnDepthStencilStateGetStencilTestEnable",
    "nvnDepthStencilStateSetDefaults",
    "nvnDepthStencilStateSetDepthFunc",
    "nvnDepthStencilStateSetDepthTestEnable",
    "nvnDepthStencilStateSetDepthWriteEnable",
    "nvnDepthStencilStateSetStencilFunc",
    "nvnDepthStencilStateSetStencilOp",
    "nvnDepthStencilStateSetStencilTestEnable",
    "nvnDeviceApplyDeferredFinalizes",
    "nvnDeviceBuilderSetDefaults",
    "nvnDeviceBuilderSetFlags",
    "nvnDeviceFinalize",
    "nvnDeviceFinalizeCommandHandle",
    "nvnDeviceGetCurrentTimestampInNanoseconds",
    "nvnDeviceGetDepthMode",
    "nvnDeviceGetImageHandle",
    "nvnDeviceGetInteger",
    "nvnDeviceGetProcAddress",
    "nvnDeviceGetSeparateSamplerHandle",
    "nvnDeviceGetSeparateTextureHandle",
    "nvnDeviceGetTexelFetchHandle",
    "nvnDeviceGetTextureHandle",
    "nvnDeviceGetTimestampInNanoseconds",
    "nvnDeviceGetWindowOriginMode",
    "nvnDeviceInitialize",
    "nvnDeviceInstallDebugCallback",
    "nvnDeviceRegisterFastClearColor",
    "nvnDeviceRegisterFastClearColori",
    "nvnDeviceRegisterFastClearColorui",
    "nvnDeviceRegisterFastClearDepth",
    "nvnDeviceSetDebugLabel",
    "nvnDeviceSetDepthMode",
    "nvnDeviceSetIntermediateShaderCache",
    "nvnDeviceSetWindowOriginMode",
    "nvnDeviceWalkDebugDatabase",
    "nvnMemoryPoolBuilderGetFlags",
    "nvnMemoryPoolBuilderGetMemory",
    "nvnMemoryPoolBuilderGetSize",
    "nvnMemoryPoolBuilderSetDefaults",
    "nvnMemoryPoolBuilderSetDevice",
    "nvnMemoryPoolBuilderSetFlags",
    "nvnMemoryPoolBuilderSetStorage",
    "nvnMemoryPoolFinalize",
    "nvnMemoryPoolFlushMappedRange",
    "nvnMemoryPoolGetBufferAddress",
    "nvnMemoryPoolGetFlags",
    "nvnMemoryPoolGetSize",
    "nvnMemoryPoolInitialize",
    "nvnMemoryPoolInitializeEP13NVNmemoryPoolPK20",
    "nvnMemoryPoolInvalidateMappedRange",
    "nvnMemoryPoolMap",
    "nvnMemoryPoolMapVirtual",
    "nvnMemoryPoolSetDebugLabel",
    "nvnMultisampleStateGetAlphaToCoverageDither",
    "nvnMultisampleStateGetAlphaToCoverageEnable",
    "nvnMultisampleStateGetMultisampleEnable",
    "nvnMultisampleStateGetSamples",
    "nvnMultisampleStateSetAlphaToCoverageDither",
    "nvnMultisampleStateSetAlphaToCoverageEnable",
    "nvnMultisampleStateSetDefaults",
    "nvnMultisampleStateSetMultisampleEnable",
    "nvnMultisampleStateSetSamples",
    "nvnPolygonStateGetCullFace",
    "nvnPolygonStateGetFrontFace",
    "nvnPolygonStateGetPolygonMode",
    "nvnPolygonStateGetPolygonOffsetEnables",
    "nvnPolygonStateSetCullFace",
    "nvnPolygonStateSetDefaults",
    "nvnPolygonStateSetFrontFace",
    "nvnPolygonStateSetPolygonMode",
    "nvnPolygonStateSetPolygonOffsetEnables",
    "nvnProgramFinalize",
    "nvnProgramInitialize",
    "nvnProgramSetDebugLabel",
    "nvnProgramSetShaders",
    "nvnProgramSetSubroutineLinkage",
    "nvnQueueAcquireTexture",
    "nvnQueueBuilderGetQueueMemorySize",
    "nvnQueueBuilderSetCommandFlushThreshold",
    "nvnQueueBuilderSetCommandMemorySize",
    "nvnQueueBuilderSetComputeMemorySize",
    "nvnQueueBuilderSetControlMemorySize",
    "nvnQueueBuilderSetDefaults",
    "nvnQueueBuilderSetDevice",
    "nvnQueueBuilderSetFlags",
    "nvnQueueBuilderSetQueueMemory",
    "nvnQueueFenceSync",
    "nvnQueueFinalize",
    "nvnQueueFinish",
    "nvnQueueFlush",
    "nvnQueueGetError",
    "nvnQueueGetTotalCommandMemoryUsed",
    "nvnQueueGetTotalComputeMemoryUsed",
    "nvnQueueGetTotalControlMemoryUsed",
    "nvnQueueInitialize",
    "nvnQueuePresentTexture",
    "nvnQueueResetMemoryUsageCounts",
    "nvnQueueSetDebugLabel",
    "nvnQueueSubmitCommands",
    "nvnQueueWaitSync",
    "nvnSamplerBuilderGetBorderColor",
    "nvnSamplerBuilderGetBorderColori",
    "nvnSamplerBuilderGetBorderColorui",
    "nvnSamplerBuilderGetCompare",
    "nvnSamplerBuilderGetLodBias",
    "nvnSamplerBuilderGetLodClamp",
    "nvnSamplerBuilderGetMaxAnisotropy",
    "nvnSamplerBuilderGetMinMagFilter",
    "nvnSamplerBuilderGetReductionFilter",
    "nvnSamplerBuilderGetWrapMode",
    "nvnSamplerBuilderSetBorderColor",
    "nvnSamplerBuilderSetBorderColori",
    "nvnSamplerBuilderSetBorderColorui",
    "nvnSamplerBuilderSetCompare",
    "nvnSamplerBuilderSetDefaults",
    "nvnSamplerBuilderSetDevice",
    "nvnSamplerBuilderSetLodBias",
    "nvnSamplerBuilderSetLodClamp",
    "nvnSamplerBuilderSetMaxAnisotropy",
    "nvnSamplerBuilderSetMinMagFilter",
    "nvnSamplerBuilderSetReductionFilter",
    "nvnSamplerBuilderSetWrapMode",
    "nvnSamplerCompare",
    "nvnSamplerFinalize",
    "nvnSamplerGetBorderColor",
    "nvnSamplerGetBorderColori",
    "nvnSamplerGetBorderColorui",
    "nvnSamplerGetCompare",
    "nvnSamplerGetDebugID",
    "nvnSamplerGetLodBias",
    "nvnSamplerGetLodClamp",
    "nvnSamplerGetMaxAnisotropy",
    "nvnSamplerGetMinMagFilter",
    "nvnSamplerGetReductionFilter",
    "nvnSamplerGetWrapMode",
    "nvnSamplerInitialize",
    "nvnSamplerPoolFinalize",
    "nvnSamplerPoolGetMemoryOffset",
    "nvnSamplerPoolGetMemoryPool",
    "nvnSamplerPoolGetSize",
    "nvnSamplerPoolInitialize",
    "nvnSamplerPoolRegisterSampler",
    "nvnSamplerPoolRegisterSamplerBuilder",
    "nvnSamplerPoolSetDebugLabel",
    "nvnSamplerSetDebugLabel",
    "nvnSyncFinalize",
    "nvnSyncInitialize",
    "nvnSyncSetDebugLabel",
    "nvnSyncWait",
    "nvnTextureBuilderGetDepth",
    "nvnTextureBuilderGetDepthStencilMode",
    "nvnTextureBuilderGetFlags",
    "nvnTextureBuilderGetFormat",
    "nvnTextureBuilderGetGLTextureName",
    "nvnTextureBuilderGetHeight",
    "nvnTextureBuilderGetLevels",
    "nvnTextureBuilderGetMemoryOffset",
    "nvnTextureBuilderGetMemoryPool",
    "nvnTextureBuilderGetPackagedTextureData",
    "nvnTextureBuilderGetSamples",
    "nvnTextureBuilderGetSparseTileLayout",
    "nvnTextureBuilderGetStorageAlignment",
    "nvnTextureBuilderGetStorageClass",
    "nvnTextureBuilderGetStorageSize",
    "nvnTextureBuilderGetStride",
    "nvnTextureBuilderGetSwizzle",
    "nvnTextureBuilderGetTarget",
    "nvnTextureBuilderGetWidth",
    "nvnTextureBuilderGetZCullStorageSize",
    "nvnTextureBuilderSetDefaults",
    "nvnTextureBuilderSetDepth",
    "nvnTextureBuilderSetDepthStencilMode",
    "nvnTextureBuilderSetDevice",
    "nvnTextureBuilderSetFlags",
    "nvnTextureBuilderSetFormat",
    "nvnTextureBuilderSetGLTextureName",
    "nvnTextureBuilderSetHeight",
    "nvnTextureBuilderSetLevels",
    "nvnTextureBuilderSetPackagedTextureData",
    "nvnTextureBuilderSetPackagedTextureLayout",
    "nvnTextureBuilderSetSamples",
    "nvnTextureBuilderSetSize1D",
    "nvnTextureBuilderSetSize2D",
    "nvnTextureBuilderSetSize3D",
    "nvnTextureBuilderSetStorage",
    "nvnTextureBuilderSetStride",
    "nvnTextureBuilderSetSwizzle",
    "nvnTextureBuilderSetTarget",
    "nvnTextureBuilderSetWidth",
    "nvnTextureCompare",
    "nvnTextureFinalize",
    "nvnTextureFlushTexels",
    "nvnTextureGetDebugID",
    "nvnTextureGetDepth",
    "nvnTextureGetDepthStencilMode",
    "nvnTextureGetFlags",
    "nvnTextureGetFormat",
    "nvnTextureGetHeight",
    "nvnTextureGetLevels",
    "nvnTextureGetMemoryOffset",
    "nvnTextureGetMemoryPool",
    "nvnTextureGetSamples",
    "nvnTextureGetSparseTileLayout",
    "nvnTextureGetStorageClass",
    "nvnTextureGetStorageSize",
    "nvnTextureGetStride",
    "nvnTextureGetSwizzle",
    "nvnTextureGetTarget",
    "nvnTextureGetTextureAddress",
    "nvnTextureGetViewOffset",
    "nvnTextureGetWidth",
    "nvnTextureGetZCullStorageSize",
    "nvnTextureInitialize",
    "nvnTextureInvalidateTexels",
    "nvnTexturePoolFinalize",
    "nvnTexturePoolGetMemoryOffset",
    "nvnTexturePoolGetMemoryPool",
    "nvnTexturePoolGetSize",
    "nvnTexturePoolInitialize",
    "nvnTexturePoolRegisterImage",
    "nvnTexturePoolRegisterTexture",
    "nvnTexturePoolSetDebugLabel",
    "nvnTextureReadTexels",
    "nvnTextureReadTexelsStrided",
    "nvnTextureSetDebugLabel",
    "nvnTextureViewCompare",
    "nvnTextureViewGetDepthStencilMode",
    "nvnTextureViewGetFormat",
    "nvnTextureViewGetLayers",
    "nvnTextureViewGetLevels",
    "nvnTextureViewGetSwizzle",
    "nvnTextureViewGetTarget",
    "nvnTextureViewSetDefaults",
    "nvnTextureViewSetDepthStencilMode",
    "nvnTextureViewSetFormat",
    "nvnTextureViewSetLayers",
    "nvnTextureViewSetLevels",
    "nvnTextureViewSetSwizzle",
    "nvnTextureViewSetTarget",
    "nvnTextureWriteTexels",
    "nvnTextureWriteTexelsStrided",
    "nvnVertexAttribStateGetFormat",
    "nvnVertexAttribStateGetStreamIndex",
    "nvnVertexAttribStateSetDefaults",
    "nvnVertexAttribStateSetFormat",
    "nvnVertexAttribStateSetStreamIndex",
    "nvnVertexStreamStateGetDivisor",
    "nvnVertexStreamStateGetStride",
    "nvnVertexStreamStateSetDefaults",
    "nvnVertexStreamStateSetDivisor",
    "nvnVertexStreamStateSetStride",
    "nvnWindowAcquireTexture",
    "nvnWindowBuilderGetNativeWindow",
    "nvnWindowBuilderGetPresentInterval",
    "nvnWindowBuilderSetDefaults",
    "nvnWindowBuilderSetDevice",
    "nvnWindowBuilderSetNativeWindow",
    "nvnWindowBuilderSetPresentInterval",
    "nvnWindowBuilderSetTextures",
    "nvnWindowFinalize",
    "nvnWindowGetCrop",
    "nvnWindowGetNativeWindow",
    "nvnWindowGetPresentInterval",
    "nvnWindowInitialize",
    "nvnWindowSetCrop",
    "nvnWindowSetDebugLabel",
    "nvnWindowSetPresentInterval",
};
const unsigned g_nvn_record_n = 378;

const nvn_ent g_nvn_table[] = {
    {"nvnBlendStateGetAdvancedMode", (nvn_fn)nvn_BlendStateGetAdvancedMode},
    {"nvnBlendStateGetAdvancedNormalizedDst", (nvn_fn)nvn_BlendStateGetAdvancedNormalizedDst},
    {"nvnBlendStateGetAdvancedOverlap", (nvn_fn)nvn_BlendStateGetAdvancedOverlap},
    {"nvnBlendStateGetAdvancedPremultipliedSrc", (nvn_fn)nvn_BlendStateGetAdvancedPremultipliedSrc},
    {"nvnBlendStateGetBlendEquation", (nvn_fn)nvn_BlendStateGetBlendEquation},
    {"nvnBlendStateGetBlendFunc", (nvn_fn)nvn_BlendStateGetBlendFunc},
    {"nvnBlendStateGetBlendTarget", (nvn_fn)nvn_BlendStateGetBlendTarget},
    {"nvnBlendStateSetAdvancedMode", (nvn_fn)nvn_BlendStateSetAdvancedMode},
    {"nvnBlendStateSetAdvancedNormalizedDst", (nvn_fn)nvn_BlendStateSetAdvancedNormalizedDst},
    {"nvnBlendStateSetAdvancedOverlap", (nvn_fn)nvn_BlendStateSetAdvancedOverlap},
    {"nvnBlendStateSetAdvancedPremultipliedSrc", (nvn_fn)nvn_BlendStateSetAdvancedPremultipliedSrc},
    {"nvnBlendStateSetBlendEquation", (nvn_fn)nvn_BlendStateSetBlendEquation},
    {"nvnBlendStateSetBlendFunc", (nvn_fn)nvn_BlendStateSetBlendFunc},
    {"nvnBlendStateSetBlendTarget", (nvn_fn)nvn_BlendStateSetBlendTarget},
    {"nvnBlendStateSetDefaults", (nvn_fn)nvn_BlendStateSetDefaults},
    {"nvnBootstrapLoader", (nvn_fn)missing_nvnBootstrapLoader},
    {"nvnBufferBuilderGetMemoryOffset", (nvn_fn)nvn_BufferBuilderGetMemoryOffset},
    {"nvnBufferBuilderGetMemoryPool", (nvn_fn)nvn_BufferBuilderGetMemoryPool},
    {"nvnBufferBuilderGetSize", (nvn_fn)nvn_BufferBuilderGetSize},
    {"nvnBufferBuilderSetDefaults", (nvn_fn)nvn_BufferBuilderSetDefaults},
    {"nvnBufferBuilderSetDevice", (nvn_fn)nvn_BufferBuilderSetDevice},
    {"nvnBufferBuilderSetStorage", (nvn_fn)nvn_BufferBuilderSetStorage},
    {"nvnBufferFinalize", (nvn_fn)nvn_BufferFinalize},
    {"nvnBufferFlushMappedRange", (nvn_fn)nvn_BufferFlushMappedRange},
    {"nvnBufferGetAddress", (nvn_fn)nvn_BufferGetAddress},
    {"nvnBufferGetDebugID", (nvn_fn)nvn_BufferGetDebugID},
    {"nvnBufferGetMemoryOffset", (nvn_fn)nvn_BufferGetMemoryOffset},
    {"nvnBufferGetMemoryPool", (nvn_fn)nvn_BufferGetMemoryPool},
    {"nvnBufferGetSize", (nvn_fn)nvn_BufferGetSize},
    {"nvnBufferInitialize", (nvn_fn)nvn_BufferInitialize},
    {"nvnBufferInvalidateMappedRange", (nvn_fn)nvn_BufferInvalidateMappedRange},
    {"nvnBufferMap", (nvn_fn)nvn_BufferMap},
    {"nvnBufferSetDebugLabel", (nvn_fn)nvn_BufferSetDebugLabel},
    {"nvnChannelMaskStateGetChannelMask", (nvn_fn)nvn_ChannelMaskStateGetChannelMask},
    {"nvnChannelMaskStateSetChannelMask", (nvn_fn)nvn_ChannelMaskStateSetChannelMask},
    {"nvnChannelMaskStateSetDefaults", (nvn_fn)nvn_ChannelMaskStateSetDefaults},
    {"nvnColorStateGetAlphaTest", (nvn_fn)nvn_ColorStateGetAlphaTest},
    {"nvnColorStateGetBlendEnable", (nvn_fn)nvn_ColorStateGetBlendEnable},
    {"nvnColorStateGetLogicOp", (nvn_fn)nvn_ColorStateGetLogicOp},
    {"nvnColorStateSetAlphaTest", (nvn_fn)nvn_ColorStateSetAlphaTest},
    {"nvnColorStateSetBlendEnable", (nvn_fn)nvn_ColorStateSetBlendEnable},
    {"nvnColorStateSetDefaults", (nvn_fn)nvn_ColorStateSetDefaults},
    {"nvnColorStateSetLogicOp", (nvn_fn)nvn_ColorStateSetLogicOp},
    {"nvnCommandBufferAddCommandMemory", (nvn_fn)nvn_CommandBufferAddCommandMemory},
    {"nvnCommandBufferAddControlMemory", (nvn_fn)nvn_CommandBufferAddControlMemory},
    {"nvnCommandBufferBarrier", (nvn_fn)nvn_CommandBufferBarrier},
    {"nvnCommandBufferBarrierEPNS_11DrawContextENS", (nvn_fn)missing_nvnCommandBufferBarrierEPNS_11DrawContextENS},
    {"nvnCommandBufferBarrier_ShaderEPNS_11DrawCon", (nvn_fn)missing_nvnCommandBufferBarrier_ShaderEPNS_11DrawCon},
    {"nvnCommandBufferBeginRecording", (nvn_fn)nvn_CommandBufferBeginRecording},
    {"nvnCommandBufferBeginTransformFeedback", (nvn_fn)missing_nvnCommandBufferBeginTransformFeedback},
    {"nvnCommandBufferBindBlendState", (nvn_fn)nvn_CommandBufferBindBlendState},
    {"nvnCommandBufferBindChannelMaskState", (nvn_fn)nvn_CommandBufferBindChannelMaskState},
    {"nvnCommandBufferBindColorState", (nvn_fn)nvn_CommandBufferBindColorState},
    {"nvnCommandBufferBindCoverageModulationTable", (nvn_fn)missing_nvnCommandBufferBindCoverageModulationTable},
    {"nvnCommandBufferBindDepthStencilState", (nvn_fn)nvn_CommandBufferBindDepthStencilState},
    {"nvnCommandBufferBindImage", (nvn_fn)nvn_CommandBufferBindImage},
    {"nvnCommandBufferBindImageEPNS_11DrawContextE", (nvn_fn)missing_nvnCommandBufferBindImageEPNS_11DrawContextE},
    {"nvnCommandBufferBindImages", (nvn_fn)nvn_CommandBufferBindImages},
    {"nvnCommandBufferBindMultisampleState", (nvn_fn)nvn_CommandBufferBindMultisampleState},
    {"nvnCommandBufferBindPolygonState", (nvn_fn)nvn_CommandBufferBindPolygonState},
    {"nvnCommandBufferBindProgram", (nvn_fn)nvn_CommandBufferBindProgram},
    {"nvnCommandBufferBindSeparateSampler", (nvn_fn)missing_nvnCommandBufferBindSeparateSampler},
    {"nvnCommandBufferBindSeparateSamplers", (nvn_fn)missing_nvnCommandBufferBindSeparateSamplers},
    {"nvnCommandBufferBindSeparateTexture", (nvn_fn)missing_nvnCommandBufferBindSeparateTexture},
    {"nvnCommandBufferBindSeparateTextures", (nvn_fn)missing_nvnCommandBufferBindSeparateTextures},
    {"nvnCommandBufferBindStorageBuffer", (nvn_fn)nvn_CommandBufferBindStorageBuffer},
    {"nvnCommandBufferBindStorageBuffers", (nvn_fn)nvn_CommandBufferBindStorageBuffers},
    {"nvnCommandBufferBindTexture", (nvn_fn)nvn_CommandBufferBindTexture},
    {"nvnCommandBufferBindTextureEPNS_11DrawContex", (nvn_fn)missing_nvnCommandBufferBindTextureEPNS_11DrawContex},
    {"nvnCommandBufferBindTextures", (nvn_fn)nvn_CommandBufferBindTextures},
    {"nvnCommandBufferBindTransformFeedbackBuffer", (nvn_fn)missing_nvnCommandBufferBindTransformFeedbackBuffer},
    {"nvnCommandBufferBindTransformFeedbackBuffers", (nvn_fn)missing_nvnCommandBufferBindTransformFeedbackBuffers},
    {"nvnCommandBufferBindUniformBuffer", (nvn_fn)nvn_CommandBufferBindUniformBuffer},
    {"nvnCommandBufferBindUniformBuffers", (nvn_fn)nvn_CommandBufferBindUniformBuffers},
    {"nvnCommandBufferBindVertexAttribState", (nvn_fn)nvn_CommandBufferBindVertexAttribState},
    {"nvnCommandBufferBindVertexBuffer", (nvn_fn)nvn_CommandBufferBindVertexBuffer},
    {"nvnCommandBufferBindVertexBuffers", (nvn_fn)nvn_CommandBufferBindVertexBuffers},
    {"nvnCommandBufferBindVertexStreamState", (nvn_fn)nvn_CommandBufferBindVertexStreamState},
    {"nvnCommandBufferCallCommands", (nvn_fn)nvn_CommandBufferCallCommands},
    {"nvnCommandBufferClearBuffer", (nvn_fn)nvn_CommandBufferClearBuffer},
    {"nvnCommandBufferClearColor", (nvn_fn)nvn_CommandBufferClearColor},
    {"nvnCommandBufferClearColori", (nvn_fn)missing_nvnCommandBufferClearColori},
    {"nvnCommandBufferClearColorui", (nvn_fn)missing_nvnCommandBufferClearColorui},
    {"nvnCommandBufferClearDepthStencil", (nvn_fn)nvn_CommandBufferClearDepthStencil},
    {"nvnCommandBufferClearTexture", (nvn_fn)missing_nvnCommandBufferClearTexture},
    {"nvnCommandBufferClearTexturei", (nvn_fn)missing_nvnCommandBufferClearTexturei},
    {"nvnCommandBufferClearTextureui", (nvn_fn)missing_nvnCommandBufferClearTextureui},
    {"nvnCommandBufferCopyBufferToBuffer", (nvn_fn)nvn_CommandBufferCopyBufferToBuffer},
    {"nvnCommandBufferCopyBufferToTexture", (nvn_fn)missing_nvnCommandBufferCopyBufferToTexture},
    {"nvnCommandBufferCopyCommands", (nvn_fn)nvn_CommandBufferCopyCommands},
    {"nvnCommandBufferCopyTextureToBuffer", (nvn_fn)missing_nvnCommandBufferCopyTextureToBuffer},
    {"nvnCommandBufferCopyTextureToTexture", (nvn_fn)missing_nvnCommandBufferCopyTextureToTexture},
    {"nvnCommandBufferDiscardColor", (nvn_fn)missing_nvnCommandBufferDiscardColor},
    {"nvnCommandBufferDiscardDepthStencil", (nvn_fn)missing_nvnCommandBufferDiscardDepthStencil},
    {"nvnCommandBufferDispatchCompute", (nvn_fn)nvn_CommandBufferDispatchCompute},
    {"nvnCommandBufferDispatchComputeIndirect", (nvn_fn)nvn_CommandBufferDispatchComputeIndirect},
    {"nvnCommandBufferDownsample", (nvn_fn)missing_nvnCommandBufferDownsample},
    {"nvnCommandBufferDrawArrays", (nvn_fn)nvn_CommandBufferDrawArrays},
    {"nvnCommandBufferDrawArraysIndirect", (nvn_fn)missing_nvnCommandBufferDrawArraysIndirect},
    {"nvnCommandBufferDrawArraysInstanced", (nvn_fn)nvn_CommandBufferDrawArraysInstanced},
    {"nvnCommandBufferDrawElements", (nvn_fn)nvn_CommandBufferDrawElements},
    {"nvnCommandBufferDrawElementsBaseVertex", (nvn_fn)nvn_CommandBufferDrawElementsBaseVertex},
    {"nvnCommandBufferDrawElementsIndirect", (nvn_fn)missing_nvnCommandBufferDrawElementsIndirect},
    {"nvnCommandBufferDrawElementsInstanced", (nvn_fn)nvn_CommandBufferDrawElementsInstanced},
    {"nvnCommandBufferDrawTexture", (nvn_fn)missing_nvnCommandBufferDrawTexture},
    {"nvnCommandBufferDrawTransformFeedback", (nvn_fn)missing_nvnCommandBufferDrawTransformFeedback},
    {"nvnCommandBufferEndRecording", (nvn_fn)nvn_CommandBufferEndRecording},
    {"nvnCommandBufferEndTransformFeedback", (nvn_fn)missing_nvnCommandBufferEndTransformFeedback},
    {"nvnCommandBufferFenceSync", (nvn_fn)missing_nvnCommandBufferFenceSync},
    {"nvnCommandBufferFinalize", (nvn_fn)nvn_CommandBufferFinalize},
    {"nvnCommandBufferGetCommandMemoryFree", (nvn_fn)nvn_CommandBufferGetCommandMemoryFree},
    {"nvnCommandBufferGetCommandMemorySize", (nvn_fn)nvn_CommandBufferGetCommandMemorySize},
    {"nvnCommandBufferGetCommandMemoryUsed", (nvn_fn)nvn_CommandBufferGetCommandMemoryUsed},
    {"nvnCommandBufferGetControlMemoryFree", (nvn_fn)nvn_CommandBufferGetControlMemoryFree},
    {"nvnCommandBufferGetControlMemorySize", (nvn_fn)nvn_CommandBufferGetControlMemorySize},
    {"nvnCommandBufferGetControlMemoryUsed", (nvn_fn)nvn_CommandBufferGetControlMemoryUsed},
    {"nvnCommandBufferGetCopyImageStride", (nvn_fn)missing_nvnCommandBufferGetCopyImageStride},
    {"nvnCommandBufferGetCopyRowStride", (nvn_fn)missing_nvnCommandBufferGetCopyRowStride},
    {"nvnCommandBufferGetMemoryCallback", (nvn_fn)nvn_CommandBufferGetMemoryCallback},
    {"nvnCommandBufferGetMemoryCallbackData", (nvn_fn)nvn_CommandBufferGetMemoryCallbackData},
    {"nvnCommandBufferInitialize", (nvn_fn)nvn_CommandBufferInitialize},
    {"nvnCommandBufferInsertDebugMarker", (nvn_fn)missing_nvnCommandBufferInsertDebugMarker},
    {"nvnCommandBufferIsRecording", (nvn_fn)nvn_CommandBufferIsRecording},
    {"nvnCommandBufferMultiDrawArraysIndirectCount", (nvn_fn)missing_nvnCommandBufferMultiDrawArraysIndirectCount},
    {"nvnCommandBufferMultiDrawElementsIndirectCou", (nvn_fn)missing_nvnCommandBufferMultiDrawElementsIndirectCou},
    {"nvnCommandBufferPauseTransformFeedback", (nvn_fn)missing_nvnCommandBufferPauseTransformFeedback},
    {"nvnCommandBufferPopDebugGroup", (nvn_fn)missing_nvnCommandBufferPopDebugGroup},
    {"nvnCommandBufferPopDebugGroupId", (nvn_fn)missing_nvnCommandBufferPopDebugGroupId},
    {"nvnCommandBufferPushDebugGroup", (nvn_fn)missing_nvnCommandBufferPushDebugGroup},
    {"nvnCommandBufferPushDebugGroupDynamic", (nvn_fn)missing_nvnCommandBufferPushDebugGroupDynamic},
    {"nvnCommandBufferPushDebugGroupStatic", (nvn_fn)missing_nvnCommandBufferPushDebugGroupStatic},
    {"nvnCommandBufferReportCounter", (nvn_fn)nvn_CommandBufferReportCounter},
    {"nvnCommandBufferReportValue", (nvn_fn)missing_nvnCommandBufferReportValue},
    {"nvnCommandBufferResetCounter", (nvn_fn)missing_nvnCommandBufferResetCounter},
    {"nvnCommandBufferResolveDepthBuffer", (nvn_fn)missing_nvnCommandBufferResolveDepthBuffer},
    {"nvnCommandBufferRestoreZCullData", (nvn_fn)missing_nvnCommandBufferRestoreZCullData},
    {"nvnCommandBufferResumeTransformFeedback", (nvn_fn)missing_nvnCommandBufferResumeTransformFeedback},
    {"nvnCommandBufferSaveZCullData", (nvn_fn)missing_nvnCommandBufferSaveZCullData},
    {"nvnCommandBufferSetAlphaRef", (nvn_fn)missing_nvnCommandBufferSetAlphaRef},
    {"nvnCommandBufferSetBlendColor", (nvn_fn)nvn_CommandBufferSetBlendColor},
    {"nvnCommandBufferSetConservativeRasterDilate", (nvn_fn)missing_nvnCommandBufferSetConservativeRasterDilate},
    {"nvnCommandBufferSetConservativeRasterEnable", (nvn_fn)missing_nvnCommandBufferSetConservativeRasterEnable},
    {"nvnCommandBufferSetCopyImageStride", (nvn_fn)missing_nvnCommandBufferSetCopyImageStride},
    {"nvnCommandBufferSetCopyRowStride", (nvn_fn)missing_nvnCommandBufferSetCopyRowStride},
    {"nvnCommandBufferSetDebugLabel", (nvn_fn)nvn_CommandBufferSetDebugLabel},
    {"nvnCommandBufferSetDepthBounds", (nvn_fn)missing_nvnCommandBufferSetDepthBounds},
    {"nvnCommandBufferSetDepthClamp", (nvn_fn)missing_nvnCommandBufferSetDepthClamp},
    {"nvnCommandBufferSetDepthRange", (nvn_fn)nvn_CommandBufferSetDepthRange},
    {"nvnCommandBufferSetDepthRanges", (nvn_fn)nvn_CommandBufferSetDepthRanges},
    {"nvnCommandBufferSetInnerTessellationLevels", (nvn_fn)missing_nvnCommandBufferSetInnerTessellationLevels},
    {"nvnCommandBufferSetLineWidth", (nvn_fn)missing_nvnCommandBufferSetLineWidth},
    {"nvnCommandBufferSetMemoryCallback", (nvn_fn)nvn_CommandBufferSetMemoryCallback},
    {"nvnCommandBufferSetMemoryCallbackData", (nvn_fn)nvn_CommandBufferSetMemoryCallbackData},
    {"nvnCommandBufferSetOuterTessellationLevels", (nvn_fn)missing_nvnCommandBufferSetOuterTessellationLevels},
    {"nvnCommandBufferSetPatchSize", (nvn_fn)missing_nvnCommandBufferSetPatchSize},
    {"nvnCommandBufferSetPointSize", (nvn_fn)missing_nvnCommandBufferSetPointSize},
    {"nvnCommandBufferSetPolygonOffsetClamp", (nvn_fn)missing_nvnCommandBufferSetPolygonOffsetClamp},
    {"nvnCommandBufferSetPrimitiveRestart", (nvn_fn)missing_nvnCommandBufferSetPrimitiveRestart},
    {"nvnCommandBufferSetProgramSubroutines", (nvn_fn)missing_nvnCommandBufferSetProgramSubroutines},
    {"nvnCommandBufferSetRasterizerDiscard", (nvn_fn)missing_nvnCommandBufferSetRasterizerDiscard},
    {"nvnCommandBufferSetRenderEnable", (nvn_fn)missing_nvnCommandBufferSetRenderEnable},
    {"nvnCommandBufferSetRenderEnableConditional", (nvn_fn)missing_nvnCommandBufferSetRenderEnableConditional},
    {"nvnCommandBufferSetRenderTargets", (nvn_fn)nvn_CommandBufferSetRenderTargets},
    {"nvnCommandBufferSetSampleMask", (nvn_fn)missing_nvnCommandBufferSetSampleMask},
    {"nvnCommandBufferSetSamplerPool", (nvn_fn)nvn_CommandBufferSetSamplerPool},
    {"nvnCommandBufferSetScissor", (nvn_fn)nvn_CommandBufferSetScissor},
    {"nvnCommandBufferSetScissors", (nvn_fn)nvn_CommandBufferSetScissors},
    {"nvnCommandBufferSetShaderScratchMemory", (nvn_fn)nvn_CommandBufferSetShaderScratchMemory},
    {"nvnCommandBufferSetStencilMask", (nvn_fn)missing_nvnCommandBufferSetStencilMask},
    {"nvnCommandBufferSetStencilRef", (nvn_fn)missing_nvnCommandBufferSetStencilRef},
    {"nvnCommandBufferSetStencilValueMask", (nvn_fn)missing_nvnCommandBufferSetStencilValueMask},
    {"nvnCommandBufferSetSubpixelPrecisionBias", (nvn_fn)missing_nvnCommandBufferSetSubpixelPrecisionBias},
    {"nvnCommandBufferSetTexturePool", (nvn_fn)nvn_CommandBufferSetTexturePool},
    {"nvnCommandBufferSetTiledCacheAction", (nvn_fn)missing_nvnCommandBufferSetTiledCacheAction},
    {"nvnCommandBufferSetTiledCacheTileSize", (nvn_fn)missing_nvnCommandBufferSetTiledCacheTileSize},
    {"nvnCommandBufferSetViewport", (nvn_fn)nvn_CommandBufferSetViewport},
    {"nvnCommandBufferSetViewportSwizzles", (nvn_fn)missing_nvnCommandBufferSetViewportSwizzles},
    {"nvnCommandBufferSetViewports", (nvn_fn)nvn_CommandBufferSetViewports},
    {"nvnCommandBufferTiledDownsample", (nvn_fn)missing_nvnCommandBufferTiledDownsample},
    {"nvnCommandBufferUpdateUniformBuffer", (nvn_fn)nvn_CommandBufferUpdateUniformBuffer},
    {"nvnCommandBufferWaitSync", (nvn_fn)missing_nvnCommandBufferWaitSync},
    {"nvnDebugCallbackE22NVNdebugCallbackSource20N", (nvn_fn)missing_nvnDebugCallbackE22NVNdebugCallbackSource20N},
    {"nvnDepthStencilStateGetDepthFunc", (nvn_fn)nvn_DepthStencilStateGetDepthFunc},
    {"nvnDepthStencilStateGetDepthTestEnable", (nvn_fn)nvn_DepthStencilStateGetDepthTestEnable},
    {"nvnDepthStencilStateGetDepthWriteEnable", (nvn_fn)nvn_DepthStencilStateGetDepthWriteEnable},
    {"nvnDepthStencilStateGetStencilFunc", (nvn_fn)nvn_DepthStencilStateGetStencilFunc},
    {"nvnDepthStencilStateGetStencilOp", (nvn_fn)nvn_DepthStencilStateGetStencilOp},
    {"nvnDepthStencilStateGetStencilTestEnable", (nvn_fn)nvn_DepthStencilStateGetStencilTestEnable},
    {"nvnDepthStencilStateSetDefaults", (nvn_fn)nvn_DepthStencilStateSetDefaults},
    {"nvnDepthStencilStateSetDepthFunc", (nvn_fn)nvn_DepthStencilStateSetDepthFunc},
    {"nvnDepthStencilStateSetDepthTestEnable", (nvn_fn)nvn_DepthStencilStateSetDepthTestEnable},
    {"nvnDepthStencilStateSetDepthWriteEnable", (nvn_fn)nvn_DepthStencilStateSetDepthWriteEnable},
    {"nvnDepthStencilStateSetStencilFunc", (nvn_fn)nvn_DepthStencilStateSetStencilFunc},
    {"nvnDepthStencilStateSetStencilOp", (nvn_fn)nvn_DepthStencilStateSetStencilOp},
    {"nvnDepthStencilStateSetStencilTestEnable", (nvn_fn)nvn_DepthStencilStateSetStencilTestEnable},
    {"nvnDeviceApplyDeferredFinalizes", (nvn_fn)nvn_DeviceApplyDeferredFinalizes},
    {"nvnDeviceBuilderSetDefaults", (nvn_fn)nvn_DeviceBuilderSetDefaults},
    {"nvnDeviceBuilderSetFlags", (nvn_fn)nvn_DeviceBuilderSetFlags},
    {"nvnDeviceFinalize", (nvn_fn)nvn_DeviceFinalize},
    {"nvnDeviceFinalizeCommandHandle", (nvn_fn)nvn_DeviceFinalizeCommandHandle},
    {"nvnDeviceGetCurrentTimestampInNanoseconds", (nvn_fn)nvn_DeviceGetCurrentTimestampInNanoseconds},
    {"nvnDeviceGetDepthMode", (nvn_fn)nvn_DeviceGetDepthMode},
    {"nvnDeviceGetImageHandle", (nvn_fn)nvn_DeviceGetImageHandle},
    {"nvnDeviceGetInteger", (nvn_fn)nvn_DeviceGetInteger},
    {"nvnDeviceGetProcAddress", (nvn_fn)nvn_DeviceGetProcAddress},
    {"nvnDeviceGetSeparateSamplerHandle", (nvn_fn)nvn_DeviceGetSeparateSamplerHandle},
    {"nvnDeviceGetSeparateTextureHandle", (nvn_fn)nvn_DeviceGetSeparateTextureHandle},
    {"nvnDeviceGetTexelFetchHandle", (nvn_fn)nvn_DeviceGetTexelFetchHandle},
    {"nvnDeviceGetTextureHandle", (nvn_fn)nvn_DeviceGetTextureHandle},
    {"nvnDeviceGetTimestampInNanoseconds", (nvn_fn)nvn_DeviceGetTimestampInNanoseconds},
    {"nvnDeviceGetWindowOriginMode", (nvn_fn)nvn_DeviceGetWindowOriginMode},
    {"nvnDeviceInitialize", (nvn_fn)nvn_DeviceInitialize},
    {"nvnDeviceInstallDebugCallback", (nvn_fn)nvn_DeviceInstallDebugCallback},
    {"nvnDeviceRegisterFastClearColor", (nvn_fn)nvn_DeviceRegisterFastClearColor},
    {"nvnDeviceRegisterFastClearColori", (nvn_fn)nvn_DeviceRegisterFastClearColori},
    {"nvnDeviceRegisterFastClearColorui", (nvn_fn)nvn_DeviceRegisterFastClearColorui},
    {"nvnDeviceRegisterFastClearDepth", (nvn_fn)nvn_DeviceRegisterFastClearDepth},
    {"nvnDeviceSetDebugLabel", (nvn_fn)nvn_DeviceSetDebugLabel},
    {"nvnDeviceSetDepthMode", (nvn_fn)nvn_DeviceSetDepthMode},
    {"nvnDeviceSetIntermediateShaderCache", (nvn_fn)nvn_DeviceSetIntermediateShaderCache},
    {"nvnDeviceSetWindowOriginMode", (nvn_fn)nvn_DeviceSetWindowOriginMode},
    {"nvnDeviceWalkDebugDatabase", (nvn_fn)nvn_DeviceWalkDebugDatabase},
    {"nvnLoadCProcs", (nvn_fn)missing_nvnLoadCProcs},
    {"nvnMemoryPoolBuilderGetFlags", (nvn_fn)nvn_MemoryPoolBuilderGetFlags},
    {"nvnMemoryPoolBuilderGetMemory", (nvn_fn)nvn_MemoryPoolBuilderGetMemory},
    {"nvnMemoryPoolBuilderGetSize", (nvn_fn)nvn_MemoryPoolBuilderGetSize},
    {"nvnMemoryPoolBuilderSetDefaults", (nvn_fn)nvn_MemoryPoolBuilderSetDefaults},
    {"nvnMemoryPoolBuilderSetDevice", (nvn_fn)nvn_MemoryPoolBuilderSetDevice},
    {"nvnMemoryPoolBuilderSetFlags", (nvn_fn)nvn_MemoryPoolBuilderSetFlags},
    {"nvnMemoryPoolBuilderSetStorage", (nvn_fn)nvn_MemoryPoolBuilderSetStorage},
    {"nvnMemoryPoolFinalize", (nvn_fn)nvn_MemoryPoolFinalize},
    {"nvnMemoryPoolFlushMappedRange", (nvn_fn)nvn_MemoryPoolFlushMappedRange},
    {"nvnMemoryPoolGetBufferAddress", (nvn_fn)nvn_MemoryPoolGetBufferAddress},
    {"nvnMemoryPoolGetFlags", (nvn_fn)nvn_MemoryPoolGetFlags},
    {"nvnMemoryPoolGetSize", (nvn_fn)nvn_MemoryPoolGetSize},
    {"nvnMemoryPoolInitialize", (nvn_fn)nvn_MemoryPoolInitialize},
    {"nvnMemoryPoolInitializeEP13NVNmemoryPoolPK20", (nvn_fn)nvn_MemoryPoolInitializeEP13NVNmemoryPoolPK20},
    {"nvnMemoryPoolInvalidateMappedRange", (nvn_fn)nvn_MemoryPoolInvalidateMappedRange},
    {"nvnMemoryPoolMap", (nvn_fn)nvn_MemoryPoolMap},
    {"nvnMemoryPoolMapVirtual", (nvn_fn)nvn_MemoryPoolMapVirtual},
    {"nvnMemoryPoolSetDebugLabel", (nvn_fn)nvn_MemoryPoolSetDebugLabel},
    {"nvnMultisampleStateGetAlphaToCoverageDither", (nvn_fn)nvn_MultisampleStateGetAlphaToCoverageDither},
    {"nvnMultisampleStateGetAlphaToCoverageEnable", (nvn_fn)nvn_MultisampleStateGetAlphaToCoverageEnable},
    {"nvnMultisampleStateGetCoverageModulationMode", (nvn_fn)missing_nvnMultisampleStateGetCoverageModulationMode},
    {"nvnMultisampleStateGetCoverageToColorEnable", (nvn_fn)missing_nvnMultisampleStateGetCoverageToColorEnable},
    {"nvnMultisampleStateGetCoverageToColorOutput", (nvn_fn)missing_nvnMultisampleStateGetCoverageToColorOutput},
    {"nvnMultisampleStateGetMultisampleEnable", (nvn_fn)nvn_MultisampleStateGetMultisampleEnable},
    {"nvnMultisampleStateGetRasterSamples", (nvn_fn)missing_nvnMultisampleStateGetRasterSamples},
    {"nvnMultisampleStateGetSampleLocationsEnable", (nvn_fn)missing_nvnMultisampleStateGetSampleLocationsEnable},
    {"nvnMultisampleStateGetSampleLocationsGrid", (nvn_fn)missing_nvnMultisampleStateGetSampleLocationsGrid},
    {"nvnMultisampleStateGetSampleLocationsGridEna", (nvn_fn)missing_nvnMultisampleStateGetSampleLocationsGridEna},
    {"nvnMultisampleStateGetSamples", (nvn_fn)nvn_MultisampleStateGetSamples},
    {"nvnMultisampleStateSetAlphaToCoverageDither", (nvn_fn)nvn_MultisampleStateSetAlphaToCoverageDither},
    {"nvnMultisampleStateSetAlphaToCoverageEnable", (nvn_fn)nvn_MultisampleStateSetAlphaToCoverageEnable},
    {"nvnMultisampleStateSetCoverageModulationMode", (nvn_fn)missing_nvnMultisampleStateSetCoverageModulationMode},
    {"nvnMultisampleStateSetCoverageToColorEnable", (nvn_fn)missing_nvnMultisampleStateSetCoverageToColorEnable},
    {"nvnMultisampleStateSetCoverageToColorOutput", (nvn_fn)missing_nvnMultisampleStateSetCoverageToColorOutput},
    {"nvnMultisampleStateSetDefaults", (nvn_fn)nvn_MultisampleStateSetDefaults},
    {"nvnMultisampleStateSetMultisampleEnable", (nvn_fn)nvn_MultisampleStateSetMultisampleEnable},
    {"nvnMultisampleStateSetRasterSamples", (nvn_fn)missing_nvnMultisampleStateSetRasterSamples},
    {"nvnMultisampleStateSetSampleLocations", (nvn_fn)missing_nvnMultisampleStateSetSampleLocations},
    {"nvnMultisampleStateSetSampleLocationsEnable", (nvn_fn)missing_nvnMultisampleStateSetSampleLocationsEnable},
    {"nvnMultisampleStateSetSampleLocationsGridEna", (nvn_fn)missing_nvnMultisampleStateSetSampleLocationsGridEna},
    {"nvnMultisampleStateSetSamples", (nvn_fn)nvn_MultisampleStateSetSamples},
    {"nvnPolygonStateGetCullFace", (nvn_fn)nvn_PolygonStateGetCullFace},
    {"nvnPolygonStateGetFrontFace", (nvn_fn)nvn_PolygonStateGetFrontFace},
    {"nvnPolygonStateGetPolygonMode", (nvn_fn)nvn_PolygonStateGetPolygonMode},
    {"nvnPolygonStateGetPolygonOffsetEnables", (nvn_fn)nvn_PolygonStateGetPolygonOffsetEnables},
    {"nvnPolygonStateSetCullFace", (nvn_fn)nvn_PolygonStateSetCullFace},
    {"nvnPolygonStateSetDefaults", (nvn_fn)nvn_PolygonStateSetDefaults},
    {"nvnPolygonStateSetFrontFace", (nvn_fn)nvn_PolygonStateSetFrontFace},
    {"nvnPolygonStateSetPolygonMode", (nvn_fn)nvn_PolygonStateSetPolygonMode},
    {"nvnPolygonStateSetPolygonOffsetEnables", (nvn_fn)nvn_PolygonStateSetPolygonOffsetEnables},
    {"nvnProgramFinalize", (nvn_fn)nvn_ProgramFinalize},
    {"nvnProgramInitialize", (nvn_fn)nvn_ProgramInitialize},
    {"nvnProgramSetDebugLabel", (nvn_fn)nvn_ProgramSetDebugLabel},
    {"nvnProgramSetShaders", (nvn_fn)nvn_ProgramSetShaders},
    {"nvnProgramSetSubroutineLinkage", (nvn_fn)nvn_ProgramSetSubroutineLinkage},
    {"nvnQueueAcquireTexture", (nvn_fn)nvn_QueueAcquireTexture},
    {"nvnQueueBuilderGetQueueMemorySize", (nvn_fn)nvn_QueueBuilderGetQueueMemorySize},
    {"nvnQueueBuilderSetCommandFlushThreshold", (nvn_fn)nvn_QueueBuilderSetCommandFlushThreshold},
    {"nvnQueueBuilderSetCommandMemorySize", (nvn_fn)nvn_QueueBuilderSetCommandMemorySize},
    {"nvnQueueBuilderSetComputeMemorySize", (nvn_fn)nvn_QueueBuilderSetComputeMemorySize},
    {"nvnQueueBuilderSetControlMemorySize", (nvn_fn)nvn_QueueBuilderSetControlMemorySize},
    {"nvnQueueBuilderSetDefaults", (nvn_fn)nvn_QueueBuilderSetDefaults},
    {"nvnQueueBuilderSetDevice", (nvn_fn)nvn_QueueBuilderSetDevice},
    {"nvnQueueBuilderSetFlags", (nvn_fn)nvn_QueueBuilderSetFlags},
    {"nvnQueueBuilderSetQueueMemory", (nvn_fn)nvn_QueueBuilderSetQueueMemory},
    {"nvnQueueFenceSync", (nvn_fn)nvn_QueueFenceSync},
    {"nvnQueueFinalize", (nvn_fn)nvn_QueueFinalize},
    {"nvnQueueFinish", (nvn_fn)nvn_QueueFinish},
    {"nvnQueueFlush", (nvn_fn)nvn_QueueFlush},
    {"nvnQueueGetError", (nvn_fn)nvn_QueueGetError},
    {"nvnQueueGetTotalCommandMemoryUsed", (nvn_fn)nvn_QueueGetTotalCommandMemoryUsed},
    {"nvnQueueGetTotalComputeMemoryUsed", (nvn_fn)nvn_QueueGetTotalComputeMemoryUsed},
    {"nvnQueueGetTotalControlMemoryUsed", (nvn_fn)nvn_QueueGetTotalControlMemoryUsed},
    {"nvnQueueInitialize", (nvn_fn)nvn_QueueInitialize},
    {"nvnQueuePresentTexture", (nvn_fn)nvn_QueuePresentTexture},
    {"nvnQueueResetMemoryUsageCounts", (nvn_fn)nvn_QueueResetMemoryUsageCounts},
    {"nvnQueueSetDebugLabel", (nvn_fn)nvn_QueueSetDebugLabel},
    {"nvnQueueSubmitCommands", (nvn_fn)nvn_QueueSubmitCommands},
    {"nvnQueueWaitSync", (nvn_fn)nvn_QueueWaitSync},
    {"nvnSamplerBuilderGetBorderColor", (nvn_fn)nvn_SamplerBuilderGetBorderColor},
    {"nvnSamplerBuilderGetBorderColori", (nvn_fn)nvn_SamplerBuilderGetBorderColori},
    {"nvnSamplerBuilderGetBorderColorui", (nvn_fn)nvn_SamplerBuilderGetBorderColorui},
    {"nvnSamplerBuilderGetCompare", (nvn_fn)nvn_SamplerBuilderGetCompare},
    {"nvnSamplerBuilderGetLodBias", (nvn_fn)nvn_SamplerBuilderGetLodBias},
    {"nvnSamplerBuilderGetLodClamp", (nvn_fn)nvn_SamplerBuilderGetLodClamp},
    {"nvnSamplerBuilderGetMaxAnisotropy", (nvn_fn)nvn_SamplerBuilderGetMaxAnisotropy},
    {"nvnSamplerBuilderGetMinMagFilter", (nvn_fn)nvn_SamplerBuilderGetMinMagFilter},
    {"nvnSamplerBuilderGetReductionFilter", (nvn_fn)nvn_SamplerBuilderGetReductionFilter},
    {"nvnSamplerBuilderGetWrapMode", (nvn_fn)nvn_SamplerBuilderGetWrapMode},
    {"nvnSamplerBuilderSetBorderColor", (nvn_fn)nvn_SamplerBuilderSetBorderColor},
    {"nvnSamplerBuilderSetBorderColori", (nvn_fn)nvn_SamplerBuilderSetBorderColori},
    {"nvnSamplerBuilderSetBorderColorui", (nvn_fn)nvn_SamplerBuilderSetBorderColorui},
    {"nvnSamplerBuilderSetCompare", (nvn_fn)nvn_SamplerBuilderSetCompare},
    {"nvnSamplerBuilderSetDefaults", (nvn_fn)nvn_SamplerBuilderSetDefaults},
    {"nvnSamplerBuilderSetDevice", (nvn_fn)nvn_SamplerBuilderSetDevice},
    {"nvnSamplerBuilderSetLodBias", (nvn_fn)nvn_SamplerBuilderSetLodBias},
    {"nvnSamplerBuilderSetLodClamp", (nvn_fn)nvn_SamplerBuilderSetLodClamp},
    {"nvnSamplerBuilderSetMaxAnisotropy", (nvn_fn)nvn_SamplerBuilderSetMaxAnisotropy},
    {"nvnSamplerBuilderSetMinMagFilter", (nvn_fn)nvn_SamplerBuilderSetMinMagFilter},
    {"nvnSamplerBuilderSetReductionFilter", (nvn_fn)nvn_SamplerBuilderSetReductionFilter},
    {"nvnSamplerBuilderSetWrapMode", (nvn_fn)nvn_SamplerBuilderSetWrapMode},
    {"nvnSamplerCompare", (nvn_fn)nvn_SamplerCompare},
    {"nvnSamplerFinalize", (nvn_fn)nvn_SamplerFinalize},
    {"nvnSamplerGetBorderColor", (nvn_fn)nvn_SamplerGetBorderColor},
    {"nvnSamplerGetBorderColori", (nvn_fn)nvn_SamplerGetBorderColori},
    {"nvnSamplerGetBorderColorui", (nvn_fn)nvn_SamplerGetBorderColorui},
    {"nvnSamplerGetCompare", (nvn_fn)nvn_SamplerGetCompare},
    {"nvnSamplerGetDebugID", (nvn_fn)nvn_SamplerGetDebugID},
    {"nvnSamplerGetLodBias", (nvn_fn)nvn_SamplerGetLodBias},
    {"nvnSamplerGetLodClamp", (nvn_fn)nvn_SamplerGetLodClamp},
    {"nvnSamplerGetMaxAnisotropy", (nvn_fn)nvn_SamplerGetMaxAnisotropy},
    {"nvnSamplerGetMinMagFilter", (nvn_fn)nvn_SamplerGetMinMagFilter},
    {"nvnSamplerGetReductionFilter", (nvn_fn)nvn_SamplerGetReductionFilter},
    {"nvnSamplerGetWrapMode", (nvn_fn)nvn_SamplerGetWrapMode},
    {"nvnSamplerInitialize", (nvn_fn)nvn_SamplerInitialize},
    {"nvnSamplerPoolFinalize", (nvn_fn)nvn_SamplerPoolFinalize},
    {"nvnSamplerPoolGetMemoryOffset", (nvn_fn)nvn_SamplerPoolGetMemoryOffset},
    {"nvnSamplerPoolGetMemoryPool", (nvn_fn)nvn_SamplerPoolGetMemoryPool},
    {"nvnSamplerPoolGetSize", (nvn_fn)nvn_SamplerPoolGetSize},
    {"nvnSamplerPoolInitialize", (nvn_fn)nvn_SamplerPoolInitialize},
    {"nvnSamplerPoolRegisterSampler", (nvn_fn)nvn_SamplerPoolRegisterSampler},
    {"nvnSamplerPoolRegisterSamplerBuilder", (nvn_fn)nvn_SamplerPoolRegisterSamplerBuilder},
    {"nvnSamplerPoolSetDebugLabel", (nvn_fn)nvn_SamplerPoolSetDebugLabel},
    {"nvnSamplerSetDebugLabel", (nvn_fn)nvn_SamplerSetDebugLabel},
    {"nvnSyncFinalize", (nvn_fn)nvn_SyncFinalize},
    {"nvnSyncInitialize", (nvn_fn)nvn_SyncInitialize},
    {"nvnSyncSetDebugLabel", (nvn_fn)nvn_SyncSetDebugLabel},
    {"nvnSyncWait", (nvn_fn)nvn_SyncWait},
    {"nvnTextureBuilderGetDepth", (nvn_fn)nvn_TextureBuilderGetDepth},
    {"nvnTextureBuilderGetDepthStencilMode", (nvn_fn)nvn_TextureBuilderGetDepthStencilMode},
    {"nvnTextureBuilderGetFlags", (nvn_fn)nvn_TextureBuilderGetFlags},
    {"nvnTextureBuilderGetFormat", (nvn_fn)nvn_TextureBuilderGetFormat},
    {"nvnTextureBuilderGetGLTextureName", (nvn_fn)nvn_TextureBuilderGetGLTextureName},
    {"nvnTextureBuilderGetHeight", (nvn_fn)nvn_TextureBuilderGetHeight},
    {"nvnTextureBuilderGetLevels", (nvn_fn)nvn_TextureBuilderGetLevels},
    {"nvnTextureBuilderGetMemoryOffset", (nvn_fn)nvn_TextureBuilderGetMemoryOffset},
    {"nvnTextureBuilderGetMemoryPool", (nvn_fn)nvn_TextureBuilderGetMemoryPool},
    {"nvnTextureBuilderGetPackagedTextureData", (nvn_fn)nvn_TextureBuilderGetPackagedTextureData},
    {"nvnTextureBuilderGetSamples", (nvn_fn)nvn_TextureBuilderGetSamples},
    {"nvnTextureBuilderGetSparseTileLayout", (nvn_fn)nvn_TextureBuilderGetSparseTileLayout},
    {"nvnTextureBuilderGetStorageAlignment", (nvn_fn)nvn_TextureBuilderGetStorageAlignment},
    {"nvnTextureBuilderGetStorageClass", (nvn_fn)nvn_TextureBuilderGetStorageClass},
    {"nvnTextureBuilderGetStorageSize", (nvn_fn)nvn_TextureBuilderGetStorageSize},
    {"nvnTextureBuilderGetStride", (nvn_fn)nvn_TextureBuilderGetStride},
    {"nvnTextureBuilderGetSwizzle", (nvn_fn)nvn_TextureBuilderGetSwizzle},
    {"nvnTextureBuilderGetTarget", (nvn_fn)nvn_TextureBuilderGetTarget},
    {"nvnTextureBuilderGetWidth", (nvn_fn)nvn_TextureBuilderGetWidth},
    {"nvnTextureBuilderGetZCullStorageSize", (nvn_fn)nvn_TextureBuilderGetZCullStorageSize},
    {"nvnTextureBuilderSetDefaults", (nvn_fn)nvn_TextureBuilderSetDefaults},
    {"nvnTextureBuilderSetDepth", (nvn_fn)nvn_TextureBuilderSetDepth},
    {"nvnTextureBuilderSetDepthStencilMode", (nvn_fn)nvn_TextureBuilderSetDepthStencilMode},
    {"nvnTextureBuilderSetDevice", (nvn_fn)nvn_TextureBuilderSetDevice},
    {"nvnTextureBuilderSetFlags", (nvn_fn)nvn_TextureBuilderSetFlags},
    {"nvnTextureBuilderSetFormat", (nvn_fn)nvn_TextureBuilderSetFormat},
    {"nvnTextureBuilderSetGLTextureName", (nvn_fn)nvn_TextureBuilderSetGLTextureName},
    {"nvnTextureBuilderSetHeight", (nvn_fn)nvn_TextureBuilderSetHeight},
    {"nvnTextureBuilderSetLevels", (nvn_fn)nvn_TextureBuilderSetLevels},
    {"nvnTextureBuilderSetPackagedTextureData", (nvn_fn)nvn_TextureBuilderSetPackagedTextureData},
    {"nvnTextureBuilderSetPackagedTextureLayout", (nvn_fn)nvn_TextureBuilderSetPackagedTextureLayout},
    {"nvnTextureBuilderSetSamples", (nvn_fn)nvn_TextureBuilderSetSamples},
    {"nvnTextureBuilderSetSize1D", (nvn_fn)nvn_TextureBuilderSetSize1D},
    {"nvnTextureBuilderSetSize2D", (nvn_fn)nvn_TextureBuilderSetSize2D},
    {"nvnTextureBuilderSetSize3D", (nvn_fn)nvn_TextureBuilderSetSize3D},
    {"nvnTextureBuilderSetStorage", (nvn_fn)nvn_TextureBuilderSetStorage},
    {"nvnTextureBuilderSetStride", (nvn_fn)nvn_TextureBuilderSetStride},
    {"nvnTextureBuilderSetSwizzle", (nvn_fn)nvn_TextureBuilderSetSwizzle},
    {"nvnTextureBuilderSetTarget", (nvn_fn)nvn_TextureBuilderSetTarget},
    {"nvnTextureBuilderSetWidth", (nvn_fn)nvn_TextureBuilderSetWidth},
    {"nvnTextureCompare", (nvn_fn)nvn_TextureCompare},
    {"nvnTextureFinalize", (nvn_fn)nvn_TextureFinalize},
    {"nvnTextureFlushTexels", (nvn_fn)nvn_TextureFlushTexels},
    {"nvnTextureGetDebugID", (nvn_fn)nvn_TextureGetDebugID},
    {"nvnTextureGetDepth", (nvn_fn)nvn_TextureGetDepth},
    {"nvnTextureGetDepthStencilMode", (nvn_fn)nvn_TextureGetDepthStencilMode},
    {"nvnTextureGetFlags", (nvn_fn)nvn_TextureGetFlags},
    {"nvnTextureGetFormat", (nvn_fn)nvn_TextureGetFormat},
    {"nvnTextureGetHeight", (nvn_fn)nvn_TextureGetHeight},
    {"nvnTextureGetLevels", (nvn_fn)nvn_TextureGetLevels},
    {"nvnTextureGetMemoryOffset", (nvn_fn)nvn_TextureGetMemoryOffset},
    {"nvnTextureGetMemoryPool", (nvn_fn)nvn_TextureGetMemoryPool},
    {"nvnTextureGetSamples", (nvn_fn)nvn_TextureGetSamples},
    {"nvnTextureGetSparseTileLayout", (nvn_fn)nvn_TextureGetSparseTileLayout},
    {"nvnTextureGetStorageClass", (nvn_fn)nvn_TextureGetStorageClass},
    {"nvnTextureGetStorageSize", (nvn_fn)nvn_TextureGetStorageSize},
    {"nvnTextureGetStride", (nvn_fn)nvn_TextureGetStride},
    {"nvnTextureGetSwizzle", (nvn_fn)nvn_TextureGetSwizzle},
    {"nvnTextureGetTarget", (nvn_fn)nvn_TextureGetTarget},
    {"nvnTextureGetTextureAddress", (nvn_fn)nvn_TextureGetTextureAddress},
    {"nvnTextureGetViewOffset", (nvn_fn)nvn_TextureGetViewOffset},
    {"nvnTextureGetWidth", (nvn_fn)nvn_TextureGetWidth},
    {"nvnTextureGetZCullStorageSize", (nvn_fn)nvn_TextureGetZCullStorageSize},
    {"nvnTextureInitialize", (nvn_fn)nvn_TextureInitialize},
    {"nvnTextureInvalidateTexels", (nvn_fn)nvn_TextureInvalidateTexels},
    {"nvnTexturePoolFinalize", (nvn_fn)nvn_TexturePoolFinalize},
    {"nvnTexturePoolGetMemoryOffset", (nvn_fn)nvn_TexturePoolGetMemoryOffset},
    {"nvnTexturePoolGetMemoryPool", (nvn_fn)nvn_TexturePoolGetMemoryPool},
    {"nvnTexturePoolGetSize", (nvn_fn)nvn_TexturePoolGetSize},
    {"nvnTexturePoolInitialize", (nvn_fn)nvn_TexturePoolInitialize},
    {"nvnTexturePoolRegisterImage", (nvn_fn)nvn_TexturePoolRegisterImage},
    {"nvnTexturePoolRegisterTexture", (nvn_fn)nvn_TexturePoolRegisterTexture},
    {"nvnTexturePoolSetDebugLabel", (nvn_fn)nvn_TexturePoolSetDebugLabel},
    {"nvnTextureReadTexels", (nvn_fn)nvn_TextureReadTexels},
    {"nvnTextureReadTexelsStrided", (nvn_fn)nvn_TextureReadTexelsStrided},
    {"nvnTextureSetDebugLabel", (nvn_fn)nvn_TextureSetDebugLabel},
    {"nvnTextureViewCompare", (nvn_fn)nvn_TextureViewCompare},
    {"nvnTextureViewGetDepthStencilMode", (nvn_fn)nvn_TextureViewGetDepthStencilMode},
    {"nvnTextureViewGetFormat", (nvn_fn)nvn_TextureViewGetFormat},
    {"nvnTextureViewGetLayers", (nvn_fn)nvn_TextureViewGetLayers},
    {"nvnTextureViewGetLevels", (nvn_fn)nvn_TextureViewGetLevels},
    {"nvnTextureViewGetSwizzle", (nvn_fn)nvn_TextureViewGetSwizzle},
    {"nvnTextureViewGetTarget", (nvn_fn)nvn_TextureViewGetTarget},
    {"nvnTextureViewSetDefaults", (nvn_fn)nvn_TextureViewSetDefaults},
    {"nvnTextureViewSetDepthStencilMode", (nvn_fn)nvn_TextureViewSetDepthStencilMode},
    {"nvnTextureViewSetFormat", (nvn_fn)nvn_TextureViewSetFormat},
    {"nvnTextureViewSetLayers", (nvn_fn)nvn_TextureViewSetLayers},
    {"nvnTextureViewSetLevels", (nvn_fn)nvn_TextureViewSetLevels},
    {"nvnTextureViewSetSwizzle", (nvn_fn)nvn_TextureViewSetSwizzle},
    {"nvnTextureViewSetTarget", (nvn_fn)nvn_TextureViewSetTarget},
    {"nvnTextureWriteTexels", (nvn_fn)nvn_TextureWriteTexels},
    {"nvnTextureWriteTexelsStrided", (nvn_fn)nvn_TextureWriteTexelsStrided},
    {"nvnVertexAttribStateGetFormat", (nvn_fn)nvn_VertexAttribStateGetFormat},
    {"nvnVertexAttribStateGetStreamIndex", (nvn_fn)nvn_VertexAttribStateGetStreamIndex},
    {"nvnVertexAttribStateSetDefaults", (nvn_fn)nvn_VertexAttribStateSetDefaults},
    {"nvnVertexAttribStateSetFormat", (nvn_fn)nvn_VertexAttribStateSetFormat},
    {"nvnVertexAttribStateSetStreamIndex", (nvn_fn)nvn_VertexAttribStateSetStreamIndex},
    {"nvnVertexStreamStateGetDivisor", (nvn_fn)nvn_VertexStreamStateGetDivisor},
    {"nvnVertexStreamStateGetStride", (nvn_fn)nvn_VertexStreamStateGetStride},
    {"nvnVertexStreamStateSetDefaults", (nvn_fn)nvn_VertexStreamStateSetDefaults},
    {"nvnVertexStreamStateSetDivisor", (nvn_fn)nvn_VertexStreamStateSetDivisor},
    {"nvnVertexStreamStateSetStride", (nvn_fn)nvn_VertexStreamStateSetStride},
    {"nvnWindowAcquireTexture", (nvn_fn)nvn_WindowAcquireTexture},
    {"nvnWindowBuilderGetNativeWindow", (nvn_fn)nvn_WindowBuilderGetNativeWindow},
    {"nvnWindowBuilderGetPresentInterval", (nvn_fn)nvn_WindowBuilderGetPresentInterval},
    {"nvnWindowBuilderSetDefaults", (nvn_fn)nvn_WindowBuilderSetDefaults},
    {"nvnWindowBuilderSetDevice", (nvn_fn)nvn_WindowBuilderSetDevice},
    {"nvnWindowBuilderSetNativeWindow", (nvn_fn)nvn_WindowBuilderSetNativeWindow},
    {"nvnWindowBuilderSetPresentInterval", (nvn_fn)nvn_WindowBuilderSetPresentInterval},
    {"nvnWindowBuilderSetTextures", (nvn_fn)nvn_WindowBuilderSetTextures},
    {"nvnWindowFinalize", (nvn_fn)nvn_WindowFinalize},
    {"nvnWindowGetCrop", (nvn_fn)nvn_WindowGetCrop},
    {"nvnWindowGetNativeWindow", (nvn_fn)nvn_WindowGetNativeWindow},
    {"nvnWindowGetPresentInterval", (nvn_fn)nvn_WindowGetPresentInterval},
    {"nvnWindowInitialize", (nvn_fn)nvn_WindowInitialize},
    {"nvnWindowSetCrop", (nvn_fn)nvn_WindowSetCrop},
    {"nvnWindowSetDebugLabel", (nvn_fn)nvn_WindowSetDebugLabel},
    {"nvnWindowSetPresentInterval", (nvn_fn)nvn_WindowSetPresentInterval},
};
const unsigned g_nvn_table_n = 469;
const unsigned g_nvn_impl_n = 378;
