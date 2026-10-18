// 纹理块线性布局：尺寸计算 + 逐 texel 地址。实现与来源见 nvn_tex.c 的文件头注释。
#ifndef SMO_NVN_TEX_H
#define SMO_NVN_TEX_H

#include <stddef.h>
#include <stdint.h>

/* Texture snapshot words 12..14 hold immutable base sampling/layout state.
 * Presence bits distinguish an explicit all-zero swizzle/layout from defaults. */
enum { NVN_TEX_SWIZZLE_WORD=12, NVN_TEX_DEPTH_WORD=13, NVN_TEX_PACKAGE_WORD=14 };
#define NVN_TEX_HAS_SWIZZLE (UINT64_C(1)<<32)
#define NVN_TEX_HAS_PACKAGE (UINT64_C(1)<<33)
/* Reference d2r-mobile: packaged layout byte 0 is the block-height exponent. */
static inline int nvn_tex_package_tile_h(const uint64_t *words, uint8_t *height) {
    if (!(words[NVN_TEX_SWIZZLE_WORD]&NVN_TEX_HAS_PACKAGE)) return 1;
    unsigned h=(unsigned)(words[NVN_TEX_PACKAGE_WORD]&255);
    if(h>5)return 0;
    *height=(uint8_t)h;
    return 1;
}

// 一张贴图的布局参数。字段对位 deko3d 的 DkImageLayout，命名保持可对照。
//
// 块（block）在这里指**压缩块**：BC 贴图一个块是 4×4 texel、8 或 16 字节；
// 未压缩格式 block_w = block_h = 1、bytes_per_block = 每 texel 字节数。
// 别和「tile」（= 1 GOB 宽 × 1<<tile_h_log2 GOB 高）混起来。
typedef struct {
    uint32_t width, height, depth;      // texel 为单位
    uint32_t layers;                    // 数组层数（1 = 非数组）
    uint32_t mip_levels;
    uint32_t bytes_per_block;
    uint32_t block_w, block_h;          // 压缩块尺寸（texel），未压缩是 1×1
    uint32_t samples_x, samples_y;      // MSAA 展开系数，非 MSAA 是 1×1
    uint8_t  dims;                      // 1/2/3 维
    uint8_t  tile_h_log2;               // = deko3d m_tileH，BNTX layout 低 3 位
    uint8_t  tile_d_log2;               // = deko3d m_tileD
    uint8_t  linear;                    // 非 0 = 线性 pitch，不走块线性
    uint32_t stride;                    // linear 时的行跨距；0 = 紧密
} nvn_tex_layout;

// 小工具（导出是为了单测能直接打；对位 deko3d 的同名函数）
uint32_t tex_div_ceil(uint32_t a, uint32_t b);
uint32_t tex_mip_size(uint32_t size, unsigned level);
uint8_t  tex_pick_tile_size(uint32_t gobs);
uint8_t  tex_adjust_tile_size(uint8_t shift, uint8_t unit_factor, uint32_t dimension);
uint64_t tex_align_layer_size(uint64_t layer_size, uint32_t height, uint32_t depth,
                              uint32_t block_h, uint8_t log2_tile_h, uint8_t log2_tile_d);

// 第 level 个 mip 在一层内的字节偏移；传 mip_levels 得到一层总大小。
uint64_t nvn_tex_level_offset(const nvn_tex_layout *L, unsigned level);
// 整张贴图（含所有层与 mip）占多少字节。
uint64_t nvn_tex_storage_size(const nvn_tex_layout *L);
// 按 deko3d 的规则给 2D 贴图挑默认 block height。
uint8_t  nvn_tex_default_tile_h(uint32_t height, uint32_t samples_y, uint32_t block_h);

// GOB 内部 512 字节的重排偏移（x_bytes 是字节、不是 texel）。
uint64_t nvn_tex_gob_offset(uint32_t x_bytes, uint32_t y);
// 第 (x_blk, y_blk) 个块在这一 mip 内的字节偏移。x/y 以**块**为单位。
uint64_t nvn_tex_block_offset(uint32_t x_blk, uint32_t y_blk,
                              uint32_t width_blks, uint32_t bytes_per_block,
                              uint8_t tile_h_log2);
// 把一个 mip 从块线性解交错成行优先；dst_stride = 0 表示紧密。
// 返回写出字节数，0 = 失败（容量不足或源不够，不会写半张）。
size_t nvn_tex_detile(void *dst, size_t dst_cap, uint32_t dst_stride,
                      const void *src, size_t src_size,
                      uint32_t width_blks, uint32_t height_blks,
                      uint32_t bytes_per_block, uint8_t tile_h_log2);
// 3D 块线性第 (x,y,z) 个块在这一 mip 内的字节偏移（tile = 1 GOB 宽 × 2^h GOB 高 × 2^d 片深）。
uint64_t nvn_tex_block_offset3d(uint32_t x_blk, uint32_t y_blk, uint32_t z,
                                uint32_t width_blks, uint32_t height_blks, uint32_t bytes_per_block,
                                uint8_t tile_h_log2, uint8_t tile_d_log2);
// 把一个 3D mip 解交错成 z → y → x 紧密排列；返回写出字节数，0 = 失败。
size_t nvn_tex_detile3d(void *dst, size_t dst_cap, const void *src, size_t src_size,
                        uint32_t width_blks, uint32_t height_blks, uint32_t depth,
                        uint32_t bytes_per_block, uint8_t tile_h_log2, uint8_t tile_d_log2);

#endif
