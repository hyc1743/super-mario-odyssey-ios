// 纹理块线性布局的单测。不需要游戏文件、不需要 Metal —— 纯算术。
//
// 这一组测试的判据不是「和实现一致」（那是同义反复），而是三类**独立性质**：
//   ① GOB 内偏移必须是 0..511 的**双射** —— 512 个 (x,y) 一一映射到 512 个字节，不重不漏。
//      这条能抓住任何位域写错：漏一位就会碰撞，多一位就会越界。
//   ② 解交错必须可逆 —— 按公式填入、再解出来，应当得到行优先的原图。
//   ③ 尺寸算法要满足单调性与整块对齐等结构性质，并与手算的已知值对上。
#include "nvn_tex.h"

#include <stdio.h>
#include <string.h>

static int g_fail;
static int g_pass;

#define CHECK(cond, ...) do {                                             \
    int ok_ = (cond);                       /* 只求值一次 */              \
    if (ok_) { g_pass++; printf("  ✅ "); } else { g_fail++; printf("  ✗ "); } \
    printf(__VA_ARGS__); printf("\n");                                    \
} while (0)

// ---------------------------------------------------------------- ① GOB 双射

static void test_gob_bijection(void) {
    printf("== 1. GOB 内偏移是 0..511 的双射（位域写错必然碰撞或越界）==\n");
    unsigned char seen[512];
    memset(seen, 0, sizeof seen);
    int oob = 0, dup = 0;
    for (uint32_t y = 0; y < 8; y++) {
        for (uint32_t xb = 0; xb < 64; xb++) {
            uint64_t o = nvn_tex_gob_offset(xb, y);
            if (o >= 512) { oob++; continue; }
            if (seen[o]++) dup++;
        }
    }
    CHECK(oob == 0, "512 个 (x,y) 全部落在 0..511 内（越界 %d）", oob);
    CHECK(dup == 0, "没有两个 (x,y) 映到同一字节（碰撞 %d）", dup);
    int miss = 0;
    for (int i = 0; i < 512; i++) if (!seen[i]) miss++;
    CHECK(miss == 0, "512 个字节全部被覆盖（漏 %d）", miss);

    // 几个手算的定点，防止「整体平移」这种能保持双射的错误
    CHECK(nvn_tex_gob_offset(0, 0) == 0, "(0,0) → 0");
    CHECK(nvn_tex_gob_offset(15, 0) == 15, "(15,0) → 15（x 低 4 位直通）");
    CHECK(nvn_tex_gob_offset(0, 1) == 16, "(0,1) → 16（y bit0 = +16）");
    CHECK(nvn_tex_gob_offset(16, 0) == 32, "(16,0) → 32（x bit4 = +32）");
    CHECK(nvn_tex_gob_offset(0, 2) == 64, "(0,2) → 64（y bit1 = +64）");
    CHECK(nvn_tex_gob_offset(32, 0) == 256, "(32,0) → 256（x bit5 = +256）");
    CHECK(nvn_tex_gob_offset(63, 7) == 511, "(63,7) → 511（全高位）");
}

// ---------------------------------------------------------------- ② 解交错可逆

// 独立实现一遍「块线性地址」用作对照：直接照 BNTX-Extractor 的 getAddrBlockLinear 写，
// 不复用被测函数 —— 否则就是拿实现验自己。
static uint64_t ref_addr(uint32_t x, uint32_t y, uint32_t w_blks, uint32_t bpb, uint32_t bh) {
    uint32_t w_gobs = (w_blks * bpb + 63) / 64;
    uint32_t xb = x * bpb;
    return (uint64_t)(y / (8 * bh)) * 512 * bh * w_gobs
         + (uint64_t)(xb / 64) * 512 * bh
         + (uint64_t)((y % (8 * bh)) / 8) * 512
         + ((xb % 64) / 32) * 256
         + ((y % 8) / 2) * 64
         + ((xb % 32) / 16) * 32
         + (y % 2) * 16
         + (xb % 16);
}

static void test_block_offset_matches_ref(void) {
    printf("== 2. 块线性地址与独立实现（BNTX-Extractor 公式）逐点一致 ==\n");
    const uint32_t cases[][3] = {          // {w_blks, bpb, tile_h_log2}
        {32, 8, 0}, {32, 8, 4}, {128, 16, 3}, {7, 16, 2}, {1, 8, 0}, {64, 4, 1},
    };
    int bad = 0, n = 0;
    for (unsigned c = 0; c < sizeof cases / sizeof cases[0]; c++) {
        uint32_t w = cases[c][0], bpb = cases[c][1];
        uint8_t shift = (uint8_t)cases[c][2];
        for (uint32_t y = 0; y < 40; y++)
            for (uint32_t x = 0; x < w; x++, n++)
                if (nvn_tex_block_offset(x, y, w, bpb, shift)
                    != ref_addr(x, y, w, bpb, 1U << shift)) bad++;
    }
    CHECK(bad == 0, "%d 个坐标全部一致（不一致 %d）", n, bad);
}

static void test_detile_roundtrip(void) {
    printf("== 3. 解交错可逆：按公式填入 → 解出来应当是行优先原图 ==\n");
    // BC1 风格：8 字节一个块，32×32 块（= 128×128 texel），block height 8 GOB
    enum { W = 32, H = 32, BPB = 8, SH = 3 };
    static uint8_t tiled[W * H * BPB * 4];      // 给足余量（块线性有填充）
    static uint8_t out[W * H * BPB];
    static uint8_t want[W * H * BPB];
    memset(tiled, 0xCD, sizeof tiled);

    // 每个块填一个可识别的签名，同时构造期望的行优先图
    for (uint32_t y = 0; y < H; y++) {
        for (uint32_t x = 0; x < W; x++) {
            uint8_t sig[BPB];
            for (int i = 0; i < BPB; i++) sig[i] = (uint8_t)(x * 7 + y * 31 + i * 3);
            uint64_t off = ref_addr(x, y, W, BPB, 1U << SH);
            memcpy(tiled + off, sig, BPB);
            memcpy(want + ((size_t)y * W + x) * BPB, sig, BPB);
        }
    }
    size_t wrote = nvn_tex_detile(out, sizeof out, 0, tiled, sizeof tiled, W, H, BPB, SH);
    CHECK(wrote == sizeof out, "写出 %zu 字节（期望 %zu）", wrote, sizeof out);
    CHECK(memcmp(out, want, sizeof out) == 0, "解出来与行优先原图逐字节一致");

    // 带 stride 的目标（Metal 上传常有行对齐要求）
    enum { STRIDE = W * BPB + 64 };
    static uint8_t out2[STRIDE * H];
    size_t w2 = nvn_tex_detile(out2, sizeof out2, STRIDE, tiled, sizeof tiled, W, H, BPB, SH);
    CHECK(w2 == (size_t)STRIDE * H, "带 stride 时写出 %zu 字节", w2);
    int rows_ok = 1;
    for (uint32_t y = 0; y < H; y++)
        if (memcmp(out2 + (size_t)y * STRIDE, want + (size_t)y * W * BPB, W * BPB)) rows_ok = 0;
    CHECK(rows_ok, "每一行的有效部分都对（填充字节不校验）");
}

static void test_detile_guards(void) {
    printf("== 4. 解交错的边界：宁可不解，也不越界读客体内存 ==\n");
    uint8_t small[16], dst[4096];
    memset(small, 0, sizeof small);
    CHECK(nvn_tex_detile(dst, sizeof dst, 0, small, sizeof small, 32, 32, 8, 3) == 0,
          "源不够 → 返回 0（不读越界）");
    CHECK(nvn_tex_detile(dst, 8, 0, small, sizeof small, 32, 32, 8, 3) == 0,
          "目标容量不够 → 返回 0（不写越界）");
    CHECK(nvn_tex_detile(NULL, 4096, 0, small, 16, 1, 1, 8, 0) == 0, "dst 为 NULL → 0");
    CHECK(nvn_tex_detile(dst, 4096, 0, NULL, 16, 1, 1, 8, 0) == 0, "src 为 NULL → 0");
    CHECK(nvn_tex_detile(dst, 4096, 0, small, 16, 0, 1, 8, 0) == 0, "宽度 0 → 0");
    CHECK(nvn_tex_detile(dst, 4096, 0, small, 16, 1, 1, 0, 0) == 0, "每块 0 字节 → 0");
}

// ---------------------------------------------------------------- ③ 尺寸算法

static void test_helpers(void) {
    printf("== 5. 小工具（对位 deko3d 的同名函数）==\n");
    CHECK(tex_div_ceil(0, 4) == 0 && tex_div_ceil(1, 4) == 1 && tex_div_ceil(4, 4) == 1
          && tex_div_ceil(5, 4) == 2, "向上取整除");
    CHECK(tex_mip_size(128, 0) == 128 && tex_mip_size(128, 7) == 1
          && tex_mip_size(128, 99) == 1, "mip 尺寸下限是 1，不是 0");
    CHECK(tex_pick_tile_size(1) == 0 && tex_pick_tile_size(2) == 1
          && tex_pick_tile_size(4) == 2 && tex_pick_tile_size(8) == 3
          && tex_pick_tile_size(16) == 4 && tex_pick_tile_size(999) == 4,
          "block height 按 GOB 数分档，上限 16 GOB");
    // adjustTileSize：维度缩小时档位要跟着降
    CHECK(tex_adjust_tile_size(0, 8, 1) == 0, "shift 0 恒为 0");
    CHECK(tex_adjust_tile_size(4, 8, 1024) == 4, "维度够大 → 档位不变");
    CHECK(tex_adjust_tile_size(4, 8, 1) < 4, "维度变小 → 档位下降");
}

static void test_storage_size(void) {
    printf("== 6. 尺寸：结构性质 + 手算定点 ==\n");
    // 128×128 的 BC1（4×4 块、8 字节），8 个 mip —— 实测 CoinCollectM 的真实形状
    nvn_tex_layout L;
    memset(&L, 0, sizeof L);
    L.width = 128; L.height = 128; L.depth = 1; L.layers = 1;
    L.mip_levels = 8; L.bytes_per_block = 8; L.block_w = 4; L.block_h = 4;
    L.samples_x = 1; L.samples_y = 1; L.dims = 2;
    L.tile_h_log2 = nvn_tex_default_tile_h(L.height, L.samples_y, L.block_h);

    // 128 texel / 4 = 32 块行；32×1.5 = 48 → /8 = 6 GOB → 档位 2（4 GOB）
    CHECK(L.tile_h_log2 == 2, "128 高的 BC 贴图 → block height 4 GOB（实得 %u）",
          L.tile_h_log2);

    uint64_t total = nvn_tex_storage_size(&L);
    // mip0：32×32 块 = 256 字节宽 × 32 行 → 4 GOB 宽 × 4 GOB 高，tile 高 4 GOB
    //   → 4×1 个 tile，每个 tile 4 GOB = 2048 字节 → 8192 字节
    CHECK(nvn_tex_level_offset(&L, 1) == 8192,
          "mip0 占 8192 字节（实得 %llu）", (unsigned long long)nvn_tex_level_offset(&L, 1));
    CHECK(total > 8192, "含 mip 链的总大小 %llu > 单 mip0", (unsigned long long)total);
    CHECK(total % 512 == 0, "总大小是 GOB(512B) 的整数倍（%llu）", (unsigned long long)total);

    // 单调性：mip 偏移必须严格递增
    int mono = 1;
    for (unsigned i = 1; i <= L.mip_levels; i++)
        if (nvn_tex_level_offset(&L, i) <= nvn_tex_level_offset(&L, i - 1)) mono = 0;
    CHECK(mono, "mip 偏移严格递增");

    // 数组层：每层对齐到整 tile，总大小 = 层数 × 层大小
    nvn_tex_layout A = L;
    A.layers = 6;                                  // cubemap
    uint64_t a_total = nvn_tex_storage_size(&A);
    CHECK(a_total >= 6 * total, "6 层的总大小 %llu >= 6×单层（层要对齐到整 tile）",
          (unsigned long long)a_total);
    CHECK(a_total % 6 == 0, "6 层平分（每层等大）");

    // 线性 pitch 那条路不走 tile
    nvn_tex_layout P;
    memset(&P, 0, sizeof P);
    P.width = 64; P.height = 32; P.layers = 1; P.mip_levels = 1;
    P.bytes_per_block = 4; P.block_w = 1; P.block_h = 1;
    P.samples_x = 1; P.samples_y = 1; P.dims = 2; P.linear = 1; P.stride = 320;
    CHECK(nvn_tex_storage_size(&P) == 320 * 32, "线性：stride × 高 = %llu",
          (unsigned long long)nvn_tex_storage_size(&P));
}

static void test_real_shapes(void) {
    printf("== 7. 实测形状（bntx_survey.py 扫出来的真实尺寸都算得通）==\n");
    // survey 的前几名尺寸 × 真实格式组合
    const struct { uint32_t w, h, bpb, mips; const char *tag; } cs[] = {
        { 512, 512,  8, 10, "512² BC1/BC4" },
        { 256, 256, 16,  9, "256² BC5" },
        { 128, 128,  8,  8, "128² BC4" },
        {1024,1024, 16, 11, "1024² BC3" },
        { 640, 352,  8, 10, "640×352 BC1（非 2 的幂）" },
    };
    int all_ok = 1;
    for (unsigned i = 0; i < sizeof cs / sizeof cs[0]; i++) {
        nvn_tex_layout L;
        memset(&L, 0, sizeof L);
        L.width = cs[i].w; L.height = cs[i].h; L.depth = 1; L.layers = 1;
        L.mip_levels = cs[i].mips; L.bytes_per_block = cs[i].bpb;
        L.block_w = 4; L.block_h = 4; L.samples_x = 1; L.samples_y = 1; L.dims = 2;
        L.tile_h_log2 = nvn_tex_default_tile_h(L.height, 1, L.block_h);
        uint64_t sz = nvn_tex_storage_size(&L);
        // 下界：mip0 的裸数据量（块数 × 每块字节），布局只会更大不会更小
        uint64_t raw = (uint64_t)tex_div_ceil(cs[i].w, 4) * tex_div_ceil(cs[i].h, 4) * cs[i].bpb;
        int ok = sz >= raw && sz % 512 == 0;
        if (!ok) all_ok = 0;
        printf("     %-26s tile_h=%u  大小 %8llu  裸数据 %8llu  %s\n",
               cs[i].tag, L.tile_h_log2, (unsigned long long)sz,
               (unsigned long long)raw, ok ? "ok" : "BAD");
    }
    CHECK(all_ok, "全部 >= 裸数据量且按 GOB 对齐");
}

// ---------------------------------------------------------------- ④ 3D 块线性
// 判据：(x,y,z) → 偏移在整张 3D mip 的 tile 对齐存储内是单射（不碰撞、不越界），
// 且解交错与按公式写入互逆。存储大小取 nvn_tex_level_offset 的 3D 结果（deko3d 口径）。
static void test_3d(void) {
    printf("== 7. 3D 块线性：单射 + 解交错可逆 ==\n");
    static const struct { uint32_t w, h, d, bpb; } shapes[] = {
        {32, 32, 32, 1}, {64, 32, 16, 4}, {17, 9, 5, 1}, {128, 8, 3, 4},
    };
    for (unsigned i = 0; i < sizeof shapes / sizeof shapes[0]; i++) {
        nvn_tex_layout L = {0};
        L.width = shapes[i].w; L.height = shapes[i].h; L.depth = shapes[i].d;
        L.layers = 1; L.mip_levels = 1; L.bytes_per_block = shapes[i].bpb;
        L.block_w = L.block_h = 1; L.samples_x = L.samples_y = 1; L.dims = 3;
        L.tile_h_log2 = nvn_tex_default_tile_h(L.height, 1, 1);
        L.tile_d_log2 = tex_pick_tile_size(L.depth + L.depth / 2);
        uint8_t h = tex_adjust_tile_size(L.tile_h_log2, 8, L.height);
        uint8_t d = tex_adjust_tile_size(L.tile_d_log2, 1, L.depth);
        uint64_t storage = nvn_tex_level_offset(&L, 1);
        static uint8_t src[1 << 20], dst[1 << 20], seen[1 << 20];
        CHECK(storage <= sizeof src, "形状 %ux%ux%u×%u：存储 %llu 字节", L.width, L.height, L.depth,
              L.bytes_per_block, (unsigned long long)storage);
        memset(seen, 0, sizeof seen);
        int oob = 0, dup = 0;
        for (uint32_t z = 0; z < L.depth; z++)
            for (uint32_t y = 0; y < L.height; y++)
                for (uint32_t x = 0; x < L.width; x++) {
                    uint64_t o = nvn_tex_block_offset3d(x, y, z, L.width, L.height, L.bytes_per_block, h, d);
                    if (o + L.bytes_per_block > storage) { oob++; continue; }
                    if (seen[o]++) dup++;
                    for (uint32_t b = 0; b < L.bytes_per_block; b++)
                        src[o + b] = (uint8_t)(x * 7 + y * 13 + z * 29 + b);
                }
        CHECK(oob == 0 && dup == 0, "  偏移不越界（%d）、不碰撞（%d）", oob, dup);
        size_t got = nvn_tex_detile3d(dst, sizeof dst, src, (size_t)storage, L.width, L.height, L.depth,
                                      L.bytes_per_block, h, d);
        int bad = 0;
        uint64_t row = (uint64_t)L.width * L.bytes_per_block, image = row * L.height;
        for (uint32_t z = 0; z < L.depth; z++)
            for (uint32_t y = 0; y < L.height; y++)
                for (uint32_t x = 0; x < L.width; x++)
                    for (uint32_t b = 0; b < L.bytes_per_block; b++)
                        if (dst[z * image + y * row + x * L.bytes_per_block + b] != (uint8_t)(x * 7 + y * 13 + z * 29 + b)) bad++;
        CHECK(got == image * L.depth && bad == 0, "  解交错还原（错 %d 字节）", bad);
        /* 只截掉 tile 尾部的填充不影响；截到最后一个真正用到的字节以内必须整体失败 */
        uint64_t used = 0;
        for (uint64_t o = 0; o < storage; o++) if (seen[o]) used = o + L.bytes_per_block;
        CHECK(!nvn_tex_detile3d(dst, sizeof dst, src, (size_t)used - 1, L.width, L.height, L.depth,
                                L.bytes_per_block, h, d), "  源截到最后一个用到的字节以内 → 整体失败");
    }
}

int main(void) {
    test_3d();
    test_gob_bijection();
    test_block_offset_matches_ref();
    test_detile_roundtrip();
    test_detile_guards();
    test_helpers();
    test_storage_size();
    test_real_shapes();

    printf("\n");
    if (g_fail) { printf("%d 条失败（通过 %d）\n", g_fail, g_pass); return 1; }
    printf("全部通过（%d 条断言）\n", g_pass);
    return 0;
}
