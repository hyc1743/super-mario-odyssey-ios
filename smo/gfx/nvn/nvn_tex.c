// 纹理块线性（block-linear）布局：尺寸计算 + 逐 texel 地址。
//
// 对应参考项目的 dm/gfx/nvn/nvn_tex.c。**尺寸算法移植自 deko3d**（devkitPro，zlib 许可，
// 见 smo/third_party/README.md 的来源与许可声明），函数一一对位，便于两边对照：
//
//   deko3d                          本文件
//   pickTileSize                    tex_pick_tile_size
//   adjustTileSize                  tex_adjust_tile_size
//   adjustMipSize / adjustBlockSize tex_mip_size / tex_div_ceil
//   alignLayerSize                  tex_align_layer_size
//   DkImageLayout::calcLevelOffset   nvn_tex_level_offset
//
// ---------------------------------------------------------------- 为什么需要这一层
//
// Switch 的 GPU（Maxwell）贴图不是行优先排布，而是「块线性」：以 GOB（group of bytes）
// 为单位重排。苹果的 Metal 只认行优先（或它自己的私有排布），所以上传前必须：
//   ① 算出这张贴图在客体内存里占多大、每个 mip 在哪      ← 本文件（纯算术，本机可测）
//   ② 把块线性的字节解交错成行优先                      ← 本文件 nvn_tex_detile
//   ③ BC 压缩的还要在 CPU 侧解码成 RGBA（苹果 GPU 不支持 BC，它用 ASTC）← bcdec，另一层
//
// 实测（smo/gfx/tools/bntx_survey.py 扫全部 4335 个 .szs）：游戏的贴图 **97.4% 是 BC 系列**，
// 全部是 2D、全部块线性，block height 覆盖 1/2/4/8/16 GOB 五档。所以 ①②③ 三步都躲不开。
//
// ---------------------------------------------------------------- GOB 的几何
//
// 一个 GOB 固定是 **64 字节宽 × 8 行 = 512 字节**。GOB 内部的 512 字节也是重排过的，
// 不是简单的「8 行 × 64 字节」—— 见 nvn_tex_gob_offset 的注释。
//
// 贴图按「tile」分块，一个 tile = 1 个 GOB 宽 × (1<<block_h_log2) 个 GOB 高 × (1<<block_d_log2) 深。
// block_h_log2 就是 deko3d 的 m_tileH、BNTX 里 layout 字段的低 3 位。
#include "nvn_tex.h"

#include <string.h>

// ---------------------------------------------------------------- 小工具（对位 deko3d）

uint32_t tex_div_ceil(uint32_t a, uint32_t b) {
    return b ? (a + b - 1) / b : a;                  // deko3d: adjustBlockSize
}

uint32_t tex_mip_size(uint32_t size, unsigned level) {
    // deko3d: adjustMipSize。多一个 level >= 32 的护栏：C 里对 u32 右移 >= 32 位是
    // **未定义行为**（x86 实际会按 level%32 移，于是 tex_mip_size(128,99) 返回 16 而不是 1）。
    // deko3d 不会遇到是因为它的 mip 数受 DkImageMaker 校验；我们的 mip 数来自客体，
    // 一个坏值不该变成未定义行为。
    if (level >= 32) return 1;
    size >>= level;
    return size ? size : 1;                          // mip 链最小是 1，不是 0
}

static uint32_t tex_adjust_size(uint32_t size, unsigned level, uint32_t block) {
    return tex_div_ceil(tex_mip_size(size, level), block);   // deko3d: adjustSize
}

// deko3d: pickTileSize —— 按「高度（含 1.5 倍余量）折合多少个 GOB」选 block height。
uint8_t tex_pick_tile_size(uint32_t gobs) {
    if (gobs >= 16) return 4;                        // 16 GOB
    if (gobs >= 8)  return 3;
    if (gobs >= 4)  return 2;
    if (gobs >= 2)  return 1;
    return 0;                                        // 1 GOB
}

// deko3d: adjustTileSize —— mip 变小时 block height 要跟着缩，否则小 mip 会浪费整块。
// 逐级减半，直到这一档不再「大于等于」该维度。
uint8_t tex_adjust_tile_size(uint8_t shift, uint8_t unit_factor, uint32_t dimension) {
    if (!shift) return 0;
    uint32_t x = (uint32_t)unit_factor << (shift - 1);
    if (x >= dimension) {
        while (--shift) {
            x >>= 1;
            if (x < dimension) break;
        }
    }
    return shift;
}

// deko3d: alignLayerSize —— 数组贴图的每层要对齐到一个完整 tile，否则下一层会错位。
uint64_t tex_align_layer_size(uint64_t layer_size, uint32_t height, uint32_t depth,
                              uint32_t block_h, uint8_t log2_tile_h, uint8_t log2_tile_d) {
    height = tex_div_ceil(height, block_h);
    while (log2_tile_h != 0 && height <= (8U << (log2_tile_h - 1))) --log2_tile_h;
    while (log2_tile_d != 0 && depth  <= (1U << (log2_tile_d - 1))) --log2_tile_d;

    uint32_t gobs_shift = (uint32_t)log2_tile_h + log2_tile_d + 9;   // 9 = log2(512B per GOB)
    uint64_t in_gobs = layer_size >> gobs_shift;
    if (layer_size != in_gobs << gobs_shift) return (in_gobs + 1) << gobs_shift;
    return layer_size;
}

// ---------------------------------------------------------------- mip 偏移与总大小

// deko3d: DkImageLayout::calcLevelOffset。
// 传 level = mip 数就得到「所有 mip 加起来多大」= 一层的大小。
uint64_t nvn_tex_level_offset(const nvn_tex_layout *L, unsigned level) {
    uint64_t offset = 0;
    for (unsigned i = 0; i < level; i++) {
        uint32_t lw = tex_adjust_size(L->width * L->samples_x, i, L->block_w);
        uint32_t lh = L->dims >= 2 ? tex_adjust_size(L->height * L->samples_y, i, L->block_h) : 1;
        uint32_t ld = L->dims >= 3 ? tex_mip_size(L->depth, i) : 1;
        uint32_t lw_bytes = lw * L->bytes_per_block;

        // 每个 mip 各自缩 block height/depth（小 mip 用不满大块）
        uint8_t sw = tex_adjust_tile_size(0,            64, lw_bytes);  // 非稀疏贴图 tile 宽恒为 0
        uint8_t sh = tex_adjust_tile_size(L->tile_h_log2, 8, lh);
        uint8_t sd = tex_adjust_tile_size(L->tile_d_log2, 1, ld);

        uint32_t w_gobs = tex_div_ceil(lw_bytes, 64);        // GOB 宽 64 字节
        uint32_t h_gobs = tex_div_ceil(lh, 8);               // GOB 高 8 行
        uint32_t w_tiles = tex_div_ceil(w_gobs, 1U << sw);
        uint32_t h_tiles = tex_div_ceil(h_gobs, 1U << sh);
        uint32_t d_tiles = tex_div_ceil(ld, 1U << sd);

        offset += (uint64_t)(w_tiles * h_tiles * d_tiles) << (9 + sw + sh + sd);
    }
    return offset;
}

uint64_t nvn_tex_storage_size(const nvn_tex_layout *L) {
    if (L->linear) {                                  // 线性 pitch：没有 tile 这回事
        uint32_t stride = L->stride ? L->stride : L->width * L->bytes_per_block;
        return (uint64_t)stride * L->height * (L->layers ? L->layers : 1);
    }
    uint64_t layer = nvn_tex_level_offset(L, L->mip_levels ? L->mip_levels : 1);
    if (L->layers > 1) {
        layer = tex_align_layer_size(layer, L->height, L->depth,
                                     L->block_h, L->tile_h_log2, L->tile_d_log2);
        return layer * L->layers;
    }
    return layer;
}

// deko3d: 2D 情形按「实际高度 ×1.5 折合多少 GOB」挑 block height。
uint8_t nvn_tex_default_tile_h(uint32_t height, uint32_t samples_y, uint32_t block_h) {
    uint32_t h = height * samples_y;
    if (block_h > 1) h = tex_div_ceil(h, block_h);
    uint32_t h_and_half = h + h / 2;
    return tex_pick_tile_size(tex_div_ceil(h_and_half, 8));
}

// ---------------------------------------------------------------- 逐 texel 地址（解交错用）

// 一个 GOB 内部的 512 字节也是重排过的。位域含义（x 已经是**字节**偏移，不是 texel）：
//
//   bit 偏移        来自
//   +256            x 的 bit 5       ((x % 64) / 32)
//   +64 ×(0..3)     y 的 bit 1..2    ((y % 8) / 2)
//   +32             x 的 bit 4       ((x % 32) / 16)
//   +16             y 的 bit 0       (y % 2)
//   +0..15          x 的 bit 0..3    (x % 16)
//
// 这个公式 deko3d 里**没有** —— 它把解交错交给 GPU 做（dkCmdBufCopyImage 走 2D 引擎）。
// 我们要在 CPU 侧解，所以公式取自 aboood40091/BNTX-Extractor 的 swizzle.py
// （getAddrBlockLinear），并用 nvn_tex_selftest.c 的往返测试与边界枚举核对过。
uint64_t nvn_tex_gob_offset(uint32_t x_bytes, uint32_t y) {
    return ((x_bytes % 64) / 32) * 256
         + ((y % 8) / 2) * 64
         + ((x_bytes % 32) / 16) * 32
         + (y % 2) * 16
         + (x_bytes % 16);
}

// 块线性里「第 (x_blk, y_blk) 个块」在这一 mip 内的字节偏移。
// x/y 以**块**为单位（BC 贴图一个块是 4×4 texel；未压缩就是 1×1 = texel）。
uint64_t nvn_tex_block_offset(uint32_t x_blk, uint32_t y_blk,
                              uint32_t width_blks, uint32_t bytes_per_block,
                              uint8_t tile_h_log2) {
    uint32_t block_height = 1U << tile_h_log2;                  // 以 GOB 为单位
    uint32_t width_gobs = tex_div_ceil(width_blks * bytes_per_block, 64);
    uint32_t x_bytes = x_blk * bytes_per_block;

    // 先定位到所属 GOB 的起点，再加 GOB 内偏移。
    uint64_t gob = (uint64_t)(y_blk / (8 * block_height)) * 512 * block_height * width_gobs
                 + (uint64_t)(x_bytes / 64) * 512 * block_height
                 + (uint64_t)((y_blk % (8 * block_height)) / 8) * 512;
    return gob + nvn_tex_gob_offset(x_bytes, y_blk);
}

// 3D：一个 tile 是 1 GOB 宽 × 2^h GOB 高 × 2^d 片深，tile 内先按片（z）排 2^h 个 GOB 一组，
// tile 之间按 x → y → z 排。与 nvn_texture_transfer.c 的 byte_offset 同一公式（deko3d / Ryujinx BlockLinearLayout）。
uint64_t nvn_tex_block_offset3d(uint32_t x_blk, uint32_t y_blk, uint32_t z,
                                uint32_t width_blks, uint32_t height_blks, uint32_t bytes_per_block,
                                uint8_t tile_h_log2, uint8_t tile_d_log2) {
    uint32_t x_bytes = x_blk * bytes_per_block;
    uint32_t width_gobs = tex_div_ceil(width_blks * bytes_per_block, 64);
    uint32_t tile_rows = tex_div_ceil(height_blks, 8U << tile_h_log2);
    uint64_t tile = UINT64_C(512) << (tile_h_log2 + tile_d_log2);
    return ((uint64_t)(z >> tile_d_log2) * tile_rows + y_blk / (8U << tile_h_log2)) * width_gobs * tile
         + (uint64_t)(x_bytes / 64) * tile
         + ((uint64_t)(z & ((1U << tile_d_log2) - 1)) << (9 + tile_h_log2))
         + (uint64_t)((y_blk % (8U << tile_h_log2)) / 8) * 512
         + nvn_tex_gob_offset(x_bytes, y_blk);
}

size_t nvn_tex_detile3d(void *dst, size_t dst_cap, const void *src, size_t src_size,
                        uint32_t width_blks, uint32_t height_blks, uint32_t depth,
                        uint32_t bytes_per_block, uint8_t tile_h_log2, uint8_t tile_d_log2) {
    if (!dst || !src || !width_blks || !height_blks || !depth || !bytes_per_block) return 0;
    uint64_t row = (uint64_t)width_blks * bytes_per_block, image = row * height_blks;
    if (image * depth > dst_cap) return 0;
    uint8_t *d = (uint8_t *)dst;
    const uint8_t *s = (const uint8_t *)src;
    for (uint32_t z = 0; z < depth; z++)
        for (uint32_t y = 0; y < height_blks; y++)
            for (uint32_t x = 0; x < width_blks; x++) {
                uint64_t off = nvn_tex_block_offset3d(x, y, z, width_blks, height_blks, bytes_per_block,
                                                      tile_h_log2, tile_d_log2);
                if (off + bytes_per_block > src_size) return 0;
                memcpy(d + z * image + y * row + (uint64_t)x * bytes_per_block, s + off, bytes_per_block);
            }
    return (size_t)(image * depth);
}

// 把一个 mip 从块线性解交错成行优先。dst_stride = 0 表示紧密排布。
// 返回写出的字节数；src_size 不够就返回 0（宁可不解也不越界读客体内存）。
size_t nvn_tex_detile(void *dst, size_t dst_cap, uint32_t dst_stride,
                      const void *src, size_t src_size,
                      uint32_t width_blks, uint32_t height_blks,
                      uint32_t bytes_per_block, uint8_t tile_h_log2) {
    if (!dst || !src || !width_blks || !height_blks || !bytes_per_block) return 0;
    uint32_t row = dst_stride ? dst_stride : width_blks * bytes_per_block;
    if ((uint64_t)row * height_blks > dst_cap) return 0;

    uint8_t *d = (uint8_t *)dst;
    const uint8_t *s = (const uint8_t *)src;
    for (uint32_t y = 0; y < height_blks; y++) {
        for (uint32_t x = 0; x < width_blks; x++) {
            uint64_t off = nvn_tex_block_offset(x, y, width_blks, bytes_per_block, tile_h_log2);
            if (off + bytes_per_block > src_size) return 0;   // 源不够 → 整体失败，别写半张
            memcpy(d + (size_t)y * row + (size_t)x * bytes_per_block,
                   s + off, bytes_per_block);
        }
    }
    return (size_t)row * height_blks;
}
