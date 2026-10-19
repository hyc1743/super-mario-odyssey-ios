/* NVN -> Metal resource bridge. Layout conventions and sampler conversion
 * adapted from d2r-mobile, Copyright (c) 2026 jhaizhou, MIT.
 * See third_party/d2r-mobile.LICENSE. Unsupported state fails explicitly. */
#import "nvn_metal_resources.h"
#import <Foundation/Foundation.h>
#include "nvn_host.h"
#include "nvn_state.h"
#include "nvn_tex.h"
#include "nvn_texread.h"
#include "nvn_texture_transfer.h"
#include "nvn_bcdec.h"
#include <math.h>
#include <pthread.h>
#include <dispatch/dispatch.h>
#include "nvn_format_info.inc"

@interface SMONVNMetalTexture : NSObject
@property(nonatomic,strong) id<MTLTexture> texture;
@property(nonatomic,strong) NSMutableDictionary<NSData *,id<MTLTexture>> *views;
@property(nonatomic) nvn_resource_snapshot resource;
@end
@implementation SMONVNMetalTexture
@end
static NSMutableDictionary<NSData *,SMONVNMetalTexture *> *textures;
static NSMutableDictionary<NSData *,id<MTLSamplerState>> *samplers;
static pthread_mutex_t cache_lock=PTHREAD_MUTEX_INITIALIZER;
static int flush_texture_region(const nvn_texture_transfer *transfer);

typedef struct { MTLPixelFormat metal; uint32_t bytes,bw,bh; int compressed,depth; } pixel_info;
static pixel_info pixel(uint32_t f) {
    pixel_info p={MTLPixelFormatInvalid,0,1,1,0,0};
    texture_fmt tf=texture_format((int)f); p.bytes=tf.bpb;
    uint32_t kind; int bpp;
    if(nvn_bc_unpacked(f,&kind,&bpp)) {
        static const MTLPixelFormat unpacked[]={MTLPixelFormatInvalid,MTLPixelFormatR8Unorm,
            MTLPixelFormatR8Snorm,MTLPixelFormatRG8Unorm,MTLPixelFormatRG8Snorm,
            MTLPixelFormatRGBA8Unorm,MTLPixelFormatRGBA8Unorm_sRGB,MTLPixelFormatRGBA16Float};
        p.metal=unpacked[kind];p.bytes=(uint32_t)bpp;p.compressed=1;return p;
    }
    if(f>=0x79 && f<=0x94) {
        static const MTLPixelFormat astc[]={MTLPixelFormatASTC_4x4_LDR,MTLPixelFormatASTC_5x4_LDR,
            MTLPixelFormatASTC_5x5_LDR,MTLPixelFormatASTC_6x5_LDR,MTLPixelFormatASTC_6x6_LDR,
            MTLPixelFormatASTC_8x5_LDR,MTLPixelFormatASTC_8x6_LDR,MTLPixelFormatASTC_8x8_LDR,
            MTLPixelFormatASTC_10x5_LDR,MTLPixelFormatASTC_10x6_LDR,MTLPixelFormatASTC_10x8_LDR,
            MTLPixelFormatASTC_10x10_LDR,MTLPixelFormatASTC_12x10_LDR,MTLPixelFormatASTC_12x12_LDR,
            MTLPixelFormatASTC_4x4_sRGB,MTLPixelFormatASTC_5x4_sRGB,MTLPixelFormatASTC_5x5_sRGB,
            MTLPixelFormatASTC_6x5_sRGB,MTLPixelFormatASTC_6x6_sRGB,MTLPixelFormatASTC_8x5_sRGB,
            MTLPixelFormatASTC_8x6_sRGB,MTLPixelFormatASTC_8x8_sRGB,MTLPixelFormatASTC_10x5_sRGB,
            MTLPixelFormatASTC_10x6_sRGB,MTLPixelFormatASTC_10x8_sRGB,MTLPixelFormatASTC_10x10_sRGB,
            MTLPixelFormatASTC_12x10_sRGB,MTLPixelFormatASTC_12x12_sRGB};
        p.metal=astc[f-0x79];p.bw=tf.bw;p.bh=tf.bh;p.compressed=2;return p;
    }
#define F(n,m) case n:p.metal=MTLPixelFormat##m;break
    switch(f) {
    F(1,R8Unorm);F(2,R8Snorm);F(3,R8Uint);F(4,R8Sint);
    F(5,R16Float);F(6,R16Unorm);F(7,R16Snorm);F(8,R16Uint);F(9,R16Sint);
    F(10,R32Float);F(11,R32Uint);F(12,R32Sint);
    F(13,RG8Unorm);F(14,RG8Snorm);F(15,RG8Uint);F(16,RG8Sint);
    F(17,RG16Float);F(18,RG16Unorm);F(19,RG16Snorm);F(20,RG16Uint);F(21,RG16Sint);
    F(22,RG32Float);F(23,RG32Uint);F(24,RG32Sint);
    F(0x25,RGBA8Unorm);F(0x26,RGBA8Snorm);F(0x27,RGBA8Uint);F(0x28,RGBA8Sint);
    F(0x29,RGBA16Float);F(0x2a,RGBA16Unorm);F(0x2b,RGBA16Snorm);F(0x2c,RGBA16Uint);F(0x2d,RGBA16Sint);
    F(0x2e,RGBA32Float);F(0x2f,RGBA32Uint);F(0x30,RGBA32Sint);
    F(0x31,Stencil8);F(0x32,Depth16Unorm);F(0x34,Depth32Float);F(0x36,Depth32Float_Stencil8);
    F(0x38,RGBA8Unorm_sRGB);F(0x3d,RGB10A2Unorm);F(0x3e,RGB10A2Uint);
    F(0x3f,RG11B10Float);F(0x40,RGB9E5Float);F(0x9a,BGRA8Unorm);F(0x9c,BGRA8Unorm_sRGB);
    default:break;
    }
#undef F
    p.depth=f>=0x31&&f<=0x36;return p;
}
static int texture_type(uint32_t target,MTLTextureType *out) {
    switch(target) {
    case 0:*out=MTLTextureType1D;return 1;
    case 1:*out=MTLTextureType2D;return 1;
    case 3:*out=MTLTextureType1DArray;return 1;
    case 4:*out=MTLTextureType2DArray;return 1;
    case 5:*out=MTLTextureType2DMultisample;return 1;
    case 6:*out=MTLTextureType2DMultisampleArray;return 1;
    case 8:*out=MTLTextureTypeCube;return 1;
    case 9:*out=MTLTextureTypeCubeArray;return 1;
    /* 真机 v0.6.18：Start 后 ×575 NVN_METAL_RESOURCE_UNSUPPORTED target=2（R8 与 RG11B10 的 3D 贴图，
     * 体积雾/调色表）→ 渲染目标解析失败 → 整遍跳过 → 黑屏。布局按 deko3d 的 3D 块线性规则。 */
    case 2:*out=MTLTextureType3D;return 1;
    default:return 0; /* rectangle/buffer require different proven layouts. */
    }
}
static NSData *resource_key(id<MTLDevice> device,const nvn_resource_snapshot *s) {
    struct { uint64_t device,object,words[16]; } key;
    key.device=(uintptr_t)(__bridge void *)device;key.object=s->object;
    memcpy(key.words,s->words,sizeof key.words);
    return [NSData dataWithBytes:&key length:sizeof key];
}
static int layout(const uint64_t *w,nvn_tex_layout *l,uint64_t *layer_stride,uint64_t *storage) {
    texture_fmt f=texture_format((int)w[5]);
    if(!f.bpb||!w[1]||!w[2]||!w[3]||!w[4]||w[4]>32||w[1]>16384||w[2]>16384||w[3]>2048)return 0;
    memset(l,0,sizeof *l);l->width=(uint32_t)w[1];l->height=(uint32_t)w[2];l->depth=1;
    l->layers=1;l->dims=2;l->mip_levels=(uint32_t)w[4];l->samples_x=l->samples_y=1;
    l->block_w=f.bw;l->block_h=f.bh;l->bytes_per_block=f.bpb;
    switch(w[7]) {
    case 0:l->dims=1;l->height=1;break;
    case 1:case 5:break;
    case 3:l->dims=1;l->layers=l->height;l->height=1;break;
    case 4:case 6:l->layers=(uint32_t)w[3];break;
    case 8:l->layers=6;break;
    case 9:l->layers=(uint32_t)w[3]*6;break;
    case 2:l->dims=3;l->depth=(uint32_t)w[3];break;
    default:return 0;
    }
    if(w[8]>1) { if(w[8]==2)l->samples_x=2;else if(w[8]==4)l->samples_x=l->samples_y=2;
        else if(w[8]==8){l->samples_x=4;l->samples_y=2;}else return 0; }
    l->linear=!!(w[6]&0x10);l->stride=(uint32_t)w[11];
    if(l->linear) {
        if(l->mip_levels!=1||w[8]>1||l->dims==3)return 0;
        if(!l->stride) {uint32_t a=w[6]&0x40?128:32;l->stride=(tex_div_ceil(l->width,f.bw)*f.bpb+a-1)&~(a-1);}
        if(l->stride<tex_div_ceil(l->width,f.bw)*f.bpb)return 0;
        *layer_stride=(uint64_t)l->stride*tex_div_ceil(l->height,f.bh);
    } else {
        if(l->dims>=2)l->tile_h_log2=nvn_tex_default_tile_h(l->height,l->samples_y,f.bh);
        if(l->dims==3)l->tile_d_log2=tex_pick_tile_size(l->depth+l->depth/2);
        if(!nvn_tex_package_tile_h(w,&l->tile_h_log2))return 0;
        *layer_stride=nvn_tex_level_offset(l,l->mip_levels);
        if(l->layers>1)*layer_stride=tex_align_layer_size(*layer_stride,l->height,1,f.bh,l->tile_h_log2,0);
    }
    uint32_t largest=l->width>l->height?l->width:l->height;
    if(l->dims==3&&l->depth>largest)largest=l->depth;
    unsigned max_levels=1;while(largest>1){largest>>=1;max_levels++;}
    if(l->mip_levels>max_levels)return 0;
    if((w[7]==8||w[7]==9)&&l->width!=l->height)return 0;
    if((w[7]==5||w[7]==6)&&(w[8]<=1||l->mip_levels!=1))return 0;
    if(w[7]!=5&&w[7]!=6&&w[8]>1)return 0;
    if(l->dims==3&&(w[8]>1||l->depth>2048))return 0;
    *storage=*layer_stride*l->layers;
    return *storage!=0;
}
static int upload3d(id<MTLTexture> tex,const uint64_t *w,pixel_info p,const nvn_tex_layout *l,
                    const uint8_t *source,uint64_t storage) {
    if(p.compressed)return 0;
    for(uint32_t level=0;level<l->mip_levels;level++){
        uint32_t width=tex_mip_size(l->width,level),height=tex_mip_size(l->height,level),depth=tex_mip_size(l->depth,level);
        uint64_t row=(uint64_t)width*p.bytes,image=row*height,size=image*depth;
        uint64_t offset=nvn_tex_level_offset(l,level);
        if(offset>=storage||size>SIZE_MAX)return 0;
        uint8_t *decoded=malloc((size_t)size);if(!decoded)return 0;
        if(!nvn_tex_detile3d(decoded,(size_t)size,source+offset,(size_t)(storage-offset),width,height,depth,
                p.bytes,tex_adjust_tile_size(l->tile_h_log2,8,height),tex_adjust_tile_size(l->tile_d_log2,1,depth))){
            free(decoded);return 0;
        }
        [tex replaceRegion:MTLRegionMake3D(0,0,0,width,height,depth) mipmapLevel:level slice:0
            withBytes:decoded bytesPerRow:(NSUInteger)row bytesPerImage:(NSUInteger)image];
        free(decoded);
    }
    (void)w;return 1;
}
static int upload(id<MTLTexture> tex,const uint64_t *w,pixel_info p,const nvn_tex_layout *l,
                  const uint8_t *source,uint64_t layer_stride,uint64_t storage) {
    if(l->dims==3)return upload3d(tex,w,p,l,source,storage);
    for(uint32_t layer=0;layer<l->layers;layer++)for(uint32_t level=0;level<l->mip_levels;level++) {
        nvn_tex_layout mip=*l;mip.width=tex_mip_size(l->width,level);mip.height=tex_mip_size(l->height,level);
        mip.layers=1;mip.mip_levels=1;
        mip.tile_h_log2=tex_adjust_tile_size(l->tile_h_log2,8,tex_div_ceil(mip.height,l->block_h));
        uint64_t offset=(uint64_t)layer*layer_stride+(l->linear?0:nvn_tex_level_offset(l,level));
        uint64_t row=(uint64_t)tex_div_ceil(mip.width,p.bw)*p.bytes;
        uint64_t size=row*tex_div_ceil(mip.height,p.bh);
        if(offset>=storage||size>SIZE_MAX||row>SIZE_MAX)return 0;
        uint8_t *decoded=malloc((size_t)size);if(!decoded)return 0;
        int64_t got=nvn_tex_decode(&mip,(uint32_t)w[5],source+offset,(size_t)(storage-offset),decoded,(size_t)size);
        if(got!=(int64_t)size){free(decoded);return 0;}
        [tex replaceRegion:MTLRegionMake2D(0,0,mip.width,mip.height) mipmapLevel:level slice:layer
            withBytes:decoded bytesPerRow:(NSUInteger)row bytesPerImage:(NSUInteger)size];
        free(decoded);
    }
    return 1;
}
static id<MTLTexture> texture_view(SMONVNMetalTexture *entry,const nvn_view_state *view) {
    id<MTLTexture> base=entry.texture;if(!view||!view->flags)return base;
    nvn_view_state v=*view;
    if(v.flags&~63u)return nil;
    NSUInteger level=0,levels=base.mipmapLevelCount,layer=0,layers=base.arrayLength;
    if(base.textureType==MTLTextureTypeCube||base.textureType==MTLTextureTypeCubeArray)layers*=6;
    if(v.flags&NVN_VIEW_LEVELS){if(v.base_level<0||v.level_count<=0)return nil;level=v.base_level;levels=v.level_count;}
    if(v.flags&NVN_VIEW_LAYERS){if(v.base_layer<0||v.layer_count<=0)return nil;layer=v.base_layer;layers=v.layer_count;}
    NSUInteger available=base.arrayLength;
    if(base.textureType==MTLTextureTypeCube||base.textureType==MTLTextureTypeCubeArray)available*=6;
    if(level>=base.mipmapLevelCount||levels>base.mipmapLevelCount-level||layer>=available||layers>available-layer)return nil;
    MTLPixelFormat format=base.pixelFormat;
    if(v.flags&NVN_VIEW_FORMAT){pixel_info p=pixel((uint32_t)v.format);if(p.metal==MTLPixelFormatInvalid)return nil;format=p.metal;}
    if(v.flags&NVN_VIEW_DEPTH_STENCIL){
        if(v.depth_stencil!=0&&v.depth_stencil!=1){NVN_LOG("NVN_METAL_VIEW_REJECT depth_stencil=%d",(int)v.depth_stencil);return nil;}
        if(v.depth_stencil==1&&base.pixelFormat==MTLPixelFormatDepth32Float_Stencil8)format=MTLPixelFormatX32_Stencil8;
        /* 纯深度格式（Depth32Float/Depth16Unorm/Stencil8）上的「取模板面」：NVN 允许我们按原格式用，
         * 以前这里直接返回 nil → 深度附件解析失败 → 每一遍渲染被跳过（真机第十轮的黑屏）。 */
    }
    MTLTextureType type=base.textureType;
    if((v.flags&NVN_VIEW_TARGET)&&!texture_type((uint32_t)v.target,&type))return nil;
    /* Metal asserts (abort, not nil) on invalid view shapes. 真机 v0.6.18 闪退：
     * `newSliceRange.length(1) must be a multiple of (6)` —— 游戏取立方体贴图的单个面当 2D 用，
     * 视图却仍按 Cube 类型请求。目标未指定时按层数推出等价的 2D / 2DArray。 */
    if(!(v.flags&NVN_VIEW_TARGET)&&(type==MTLTextureTypeCube||type==MTLTextureTypeCubeArray)&&layers%6)
        type=layers==1?MTLTextureType2D:MTLTextureType2DArray;
    if((type==MTLTextureTypeCube||type==MTLTextureTypeCubeArray)&&(layers%6||(type==MTLTextureTypeCube&&layers!=6)))return nil;
    if((type==MTLTextureType2D||type==MTLTextureType1D||type==MTLTextureType2DMultisample||type==MTLTextureType3D)&&layers!=1)return nil;
    if((type==MTLTextureType3D)!=(base.textureType==MTLTextureType3D))return nil;
    if((base.textureType==MTLTextureType2DMultisample||base.textureType==MTLTextureType2DMultisampleArray)!=
       (type==MTLTextureType2DMultisample||type==MTLTextureType2DMultisampleArray))return nil;
    MTLTextureSwizzleChannels sw=MTLTextureSwizzleChannelsMake(MTLTextureSwizzleRed,MTLTextureSwizzleGreen,MTLTextureSwizzleBlue,MTLTextureSwizzleAlpha);
    if(v.flags&NVN_VIEW_SWIZZLE){
        static const MTLTextureSwizzle map[]={MTLTextureSwizzleZero,MTLTextureSwizzleOne,MTLTextureSwizzleRed,MTLTextureSwizzleGreen,MTLTextureSwizzleBlue,MTLTextureSwizzleAlpha};
        for(int i=0;i<4;i++)if(v.swizzle[i]>5)return nil;
        sw=MTLTextureSwizzleChannelsMake(map[v.swizzle[0]],map[v.swizzle[1]],map[v.swizzle[2]],map[v.swizzle[3]]);
    }
    NSData *key=[NSData dataWithBytes:&v length:sizeof v];id<MTLTexture> result=entry.views[key];
    if(!result){result=[base newTextureViewWithPixelFormat:format textureType:type levels:NSMakeRange(level,levels)
        slices:NSMakeRange(layer,layers) swizzle:sw];if(result)entry.views[key]=result;}
    return result;
}
id<MTLTexture> nvn_metal_texture(id<MTLDevice> device,const nvn_resource_snapshot *s,const nvn_view_state *v,int render_target) {
    if(!device||!s)return nil;
    nvn_texture_set_flush_handler(flush_texture_region);
    pthread_mutex_lock(&cache_lock);
    if(!textures)textures=[NSMutableDictionary new];
    NSData *key=resource_key(device,s);SMONVNMetalTexture *entry=textures[key];
    if(!entry) {
        const uint64_t *w=s->words;pixel_info p=pixel((uint32_t)w[5]);MTLTextureType type;
        nvn_tex_layout l;uint64_t layer_stride=0,storage=0;
        nvn_st_ent *pool=nvn_st_get((const void *)(uintptr_t)w[9],4);
        /* 失败判据逐条拆开记原因：以前只有一个「UNSUPPORTED」，看不出是格式、布局还是存储池，
         * 真机上只能猜（第八/第九轮都卡在这里）。 */
        const char *why=NULL;
        if(p.metal==MTLPixelFormatInvalid)why="pixel format";
        else if(!texture_type((uint32_t)w[7],&type))why="texture type";
        else if(!layout(w,&l,&layer_stride,&storage))why="layout";
        else if(!pool)why="pool not registered";
        else if(!pool->v[1])why="pool has no memory";
        else if(w[10]>pool->v[2])why="offset beyond pool";
        else if(storage>pool->v[2]-w[10])why="storage beyond pool";
        else if(pool->v[1]>UINT64_MAX-pool->v[2])why="pool address overflow";
        else if(p.compressed&&render_target)why="compressed as render target";
        /* Depth textures are valid shader-read resources as well as render
         * targets.  The old guard rejected every non-render-target access to
         * Depth32Float (NVN format 0x34 / decimal 52).  Super Mario Odyssey
         * samples its depth buffer in post-processing passes, so that guard
         * turned an otherwise valid texture into nil, which then caused the
         * Metal render pipeline to be skipped and left the display black. */
        else if(w[8]>1&&(!render_target||![device supportsTextureSampleCount:(NSUInteger)w[8]]))why="sample count";
        else if(p.compressed==2&&(l.dims!=2||![device supportsFamily:MTLGPUFamilyApple1]))why="astc constraints";
        if(why){
            static unsigned rejected;
            if(rejected<24){rejected++;NVN_LOG("NVN_METAL_TEXTURE_REJECT %s format=%llu target=%llu samples=%llu render=%d pool=%u",
                why,(unsigned long long)w[5],(unsigned long long)w[7],(unsigned long long)w[8],render_target,pool?1:0);}
            goto failure;
        }
        MTLTextureDescriptor *d=[MTLTextureDescriptor new];d.textureType=type;d.pixelFormat=p.metal;
        d.width=l.width;d.height=l.height;d.depth=l.dims==3?l.depth:1;d.mipmapLevelCount=l.mip_levels;
        d.arrayLength=(type==MTLTextureTypeCubeArray)?l.layers/6:(type==MTLTextureTypeCube?1:l.layers);
        d.sampleCount=w[8]>1?(NSUInteger)w[8]:1;
        d.storageMode=(p.depth||w[8]>1)?MTLStorageModePrivate:MTLStorageModeShared;
        d.usage=MTLTextureUsageShaderRead|MTLTextureUsagePixelFormatView;
        if(!p.compressed)d.usage|=MTLTextureUsageRenderTarget;
        /* NVN_TEXTURE_FLAGS_IMAGE (0x4): the game writes it from compute shaders (imageStore). */
        if((w[6]&0x4)&&!p.compressed&&!p.depth&&w[8]<=1)d.usage|=MTLTextureUsageShaderWrite;
        id<MTLTexture> texture=[device newTextureWithDescriptor:d];if(!texture)goto failure;
        if(!p.depth&&w[8]<=1&&!upload(texture,w,p,&l,(const uint8_t *)(uintptr_t)(pool->v[1]+w[10]),layer_stride,storage))goto failure;
        entry=[SMONVNMetalTexture new];entry.texture=texture;entry.resource=*s;entry.views=[NSMutableDictionary new];textures[key]=entry;
    }
    {
        if(render_target&&pixel((uint32_t)s->words[5]).compressed)goto failure;
        nvn_view_state effective={0};if(v)effective=*v;
        const uint64_t *w=s->words;
        if(!render_target&&!(effective.flags&NVN_VIEW_SWIZZLE)&&(w[NVN_TEX_SWIZZLE_WORD]&NVN_TEX_HAS_SWIZZLE)){
            effective.flags|=NVN_VIEW_SWIZZLE;
            for(int i=0;i<4;i++)effective.swizzle[i]=(uint8_t)(w[NVN_TEX_SWIZZLE_WORD]>>(i*8));
        }
        if(!render_target&&!(effective.flags&NVN_VIEW_DEPTH_STENCIL)&&w[NVN_TEX_DEPTH_WORD]){
            effective.flags|=NVN_VIEW_DEPTH_STENCIL;effective.depth_stencil=(int32_t)w[NVN_TEX_DEPTH_WORD];
        }
        id<MTLTexture> result=texture_view(entry,&effective);
        if(!result&&render_target){
            /* 渲染目标的视图参数不满意时退回基础纹理：宁可这一帧用非视图纹理画，也别整遍跳过。
             * （真机第十轮：深度视图在 DEPTH32F 上被判失败 → 黑屏） */
            static unsigned fallback_logged;
            if(fallback_logged<8){fallback_logged++;NVN_LOG("NVN_METAL_VIEW_FALLBACK format=%llu target=%llu —— 用基础纹理当附件",
                (unsigned long long)s->words[5],(unsigned long long)s->words[7]);}
            result=entry.texture;
        }
        if(!result)goto failure;
        pthread_mutex_unlock(&cache_lock);return result;
    }
failure:
    NVN_LOG("NVN_METAL_RESOURCE_UNSUPPORTED texture=%#llx serial=%llu format=%llu target=%llu samples=%llu render=%d",
        (unsigned long long)s->object,(unsigned long long)s->words[15],(unsigned long long)s->words[5],
        (unsigned long long)s->words[7],(unsigned long long)s->words[8],render_target);
    pthread_mutex_unlock(&cache_lock);return nil;
}
static int upload_region(SMONVNMetalTexture *entry,const nvn_texture_transfer *t) {
    id<MTLTexture> tex=entry.texture;
    if(tex.storageMode!=MTLStorageModeShared||tex.sampleCount>1)return 0;
    pixel_info p=pixel((uint32_t)t->resource.words[5]);
    if(p.metal==MTLPixelFormatInvalid||p.depth)return 0;
    nvn_tex_layout mip=t->layout;
    mip.width=t->width;mip.height=t->height;mip.layers=1;mip.mip_levels=1;
    mip.tile_h_log2=tex_adjust_tile_size(t->layout.tile_h_log2,8,tex_div_ceil(mip.height,mip.block_h));
    uint64_t row=(uint64_t)tex_div_ceil(mip.width,p.bw)*p.bytes;
    uint64_t size=row*tex_div_ceil(mip.height,p.bh);
    if(!size||size>SIZE_MAX)return 0;
    uint8_t *decoded=malloc((size_t)size);if(!decoded)return 0;
    const NVNcopyRegion *r=&t->region;
    for(int z=0;z<r->depth;z++){
        uint64_t offset=(uint64_t)(r->zoffset+z)*t->layer_stride+t->mip_offset;
        if(offset>=t->storage_size||nvn_tex_decode(&mip,(uint32_t)t->resource.words[5],
                t->storage+offset,(size_t)(t->storage_size-offset),decoded,(size_t)size)!=(int64_t)size){free(decoded);return 0;}
        uint64_t first=(uint64_t)(r->yoffset/(int)p.bh)*row+(uint64_t)(r->xoffset/(int)p.bw)*p.bytes;
        [tex replaceRegion:MTLRegionMake2D(r->xoffset,r->yoffset,r->width,r->height)
            mipmapLevel:t->level slice:(NSUInteger)(r->zoffset+z) withBytes:decoded+first
            bytesPerRow:(NSUInteger)row bytesPerImage:(NSUInteger)size];
    }
    free(decoded);return 1;
}
static int flush_texture_region(const nvn_texture_transfer *transfer) {
    /* Metal/Foundation work must execute on a native stack, since NVN APIs can
     * be called from a 16 KiB guest stack. Never dispatch_sync from that stack. */
    nvn_texture_transfer t=*transfer;
    __block int result=1;
    dispatch_semaphore_t finished=dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        @autoreleasepool {
            pthread_mutex_lock(&cache_lock);
            for(SMONVNMetalTexture *entry in textures.allValues){
                nvn_resource_snapshot s=entry.resource;
                if(s.object==t.resource.object&&s.words[15]==t.resource.words[15]&&!upload_region(entry,&t)){
                    result=0;break;
                }
            }
            pthread_mutex_unlock(&cache_lock);
        }
        dispatch_semaphore_signal(finished);
    });
    dispatch_semaphore_wait(finished,DISPATCH_TIME_FOREVER);
    return result;
}
static float float_word(uint64_t w){uint32_t bits=(uint32_t)w;float f;memcpy(&f,&bits,4);return f;}
static int address_mode(uint64_t value,MTLSamplerAddressMode *out) {
    switch(value){
    case 1:*out=MTLSamplerAddressModeRepeat;return 1;
    case 3:*out=MTLSamplerAddressModeMirrorClampToEdge;return 1;
    case 5:*out=MTLSamplerAddressModeClampToBorderColor;return 1;
    case 6:*out=MTLSamplerAddressModeMirrorRepeat;return 1;
    case 7:*out=MTLSamplerAddressModeClampToEdge;return 1;
    default:return 0; /* Legacy clamp/mirror-clamp differ at the border. */
    }
}
id<MTLSamplerState> nvn_metal_sampler(id<MTLDevice> device,const nvn_resource_snapshot *s) {
    if(!device||!s)return nil;pthread_mutex_lock(&cache_lock);
    if(!samplers)samplers=[NSMutableDictionary new];
    NSData *key=resource_key(device,s);id<MTLSamplerState> result=samplers[key];
    if(result){pthread_mutex_unlock(&cache_lock);return result;}
    const uint64_t *w=s->words;uint32_t min=(uint32_t)w[1],mag=(uint32_t)(w[1]>>32);
    uint32_t mode=(uint32_t)w[7],func=(uint32_t)(w[7]>>32);
    float bias=float_word(w[5]),lo=float_word(w[13]),hi=float_word(w[14]),aniso=float_word(w[6]);
    MTLSamplerAddressMode ws,wt,wr;
    if(min>5||mag>1||mode>1||(mode&&(func<1||func>8))||w[8]||!isfinite(aniso)||aniso<1||aniso>16||floorf(aniso)!=aniso||
       !isfinite(bias)||!isfinite(lo)||!isfinite(hi)||hi<lo||
       !address_mode(w[2],&ws)||!address_mode(w[3],&wt)||!address_mode(w[4],&wr))goto failure;
    {
        MTLSamplerDescriptor *d=[MTLSamplerDescriptor new];
        d.minFilter=(min&1)?MTLSamplerMinMagFilterLinear:MTLSamplerMinMagFilterNearest;
        d.magFilter=mag?MTLSamplerMinMagFilterLinear:MTLSamplerMinMagFilterNearest;
        d.mipFilter=min<2?MTLSamplerMipFilterNotMipmapped:(min<4?MTLSamplerMipFilterNearest:MTLSamplerMipFilterLinear);
        d.sAddressMode=ws;d.tAddressMode=wt;d.rAddressMode=wr;
        d.maxAnisotropy=(NSUInteger)aniso;d.lodMinClamp=fmaxf(0,lo);d.lodMaxClamp=fmaxf(0,hi);
        d.compareFunction=mode?(MTLCompareFunction)(func-1):MTLCompareFunctionNever;
        d.supportArgumentBuffers=YES;
        if(bias!=0){
            if(![d respondsToSelector:NSSelectorFromString(@"setLodBias:")])goto failure;
            [d setValue:@(bias) forKey:@"lodBias"];
        }
        if(ws==MTLSamplerAddressModeClampToBorderColor||wt==MTLSamplerAddressModeClampToBorderColor||wr==MTLSamplerAddressModeClampToBorderColor){
            float r=float_word(w[9]),g=float_word(w[10]),b=float_word(w[11]),a=float_word(w[12]);
            if(w[9]>>32){r=(float)(uint32_t)w[9];g=(float)(uint32_t)w[10];b=(float)(uint32_t)w[11];a=(float)(uint32_t)w[12];}
            if(r==0&&g==0&&b==0&&a==0)d.borderColor=MTLSamplerBorderColorTransparentBlack;
            else if(r==0&&g==0&&b==0&&a==1)d.borderColor=MTLSamplerBorderColorOpaqueBlack;
            else if(r==1&&g==1&&b==1&&a==1)d.borderColor=MTLSamplerBorderColorOpaqueWhite;
            else goto failure;
        }
        result=[device newSamplerStateWithDescriptor:d];if(!result)goto failure;
        samplers[key]=result;pthread_mutex_unlock(&cache_lock);return result;
    }
failure:
    NVN_LOG("NVN_METAL_RESOURCE_UNSUPPORTED sampler=%#llx minmag=%#llx wrap=%llu/%llu/%llu reduction=%llu",
        (unsigned long long)s->object,(unsigned long long)s->words[1],(unsigned long long)s->words[2],
        (unsigned long long)s->words[3],(unsigned long long)s->words[4],(unsigned long long)s->words[8]);
    pthread_mutex_unlock(&cache_lock);return nil;
}
void nvn_metal_resources_reset(void) {
    nvn_texture_set_flush_handler(NULL);
    pthread_mutex_lock(&cache_lock);[textures removeAllObjects];[samplers removeAllObjects];pthread_mutex_unlock(&cache_lock);
}
