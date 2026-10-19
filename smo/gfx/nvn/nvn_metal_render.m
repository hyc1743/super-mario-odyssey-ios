/* Guest command rendering. Every unsupported state fails with a diagnostic;
 * no replacement game shaders, dummy bindings or synthetic frames. */
#import "nvn_metal_private.h"
#import "nvn_metal_resources.h"
#include "nvn_cmd_render.h"
#include "nvn_render_state.h"
#include "nvn_shader.h"
#include "nvn_shader_archive.h"
#include "nvn_state.h"
#include "nvn_host.h"
#include <math.h>
#include <limits.h>
#include <stdatomic.h>

static _Atomic uint64_t metal_shader_cache_hits;
static _Atomic uint64_t metal_shader_cache_misses;
static _Atomic uint64_t metal_pipeline_cache_hits;
static _Atomic uint64_t metal_pipeline_cache_misses;

static void log_cache_stats_if_due(void) {
    uint64_t total=atomic_load(&metal_shader_cache_hits)+atomic_load(&metal_shader_cache_misses)+
                   atomic_load(&metal_pipeline_cache_hits)+atomic_load(&metal_pipeline_cache_misses);
    if(total && (total==1 || total%120==0))
        NVN_LOG("NVN_METAL_CACHE shader_hit=%llu shader_miss=%llu pipeline_hit=%llu pipeline_miss=%llu",
            (unsigned long long)atomic_load(&metal_shader_cache_hits),
            (unsigned long long)atomic_load(&metal_shader_cache_misses),
            (unsigned long long)atomic_load(&metal_pipeline_cache_hits),
            (unsigned long long)atomic_load(&metal_pipeline_cache_misses));
}

@interface SMOMetalShader : NSObject
@property(nonatomic,strong) id<MTLFunction> function;
@property(nonatomic,strong) NSDictionary *bindings;
@property(nonatomic,strong) id<MTLArgumentEncoder> arguments;
@property(nonatomic,strong) id<MTLBuffer> constants;
@property(nonatomic,copy) NSString *cacheKey;
@property(nonatomic) int depthMode;
@property(nonatomic) nvn_shader_ent sourceEntry;
@end
@implementation SMOMetalShader
@end

@interface SMORenderState : NSObject {
@public
    nvn_cmd_targets targets;
    nvn_blend_state blends[8];
    nvn_color_state color;
    nvn_channel_state channel;
    nvn_depth_state depth;
    nvn_polygon_state polygon;
    nvn_multisample_state multisample;
    nvn_vertex_attrib_state attributes[16];
    nvn_vertex_stream_state streams[16];
    NVNbufferRange vertex[32],uniforms[6][32],storage[6][32];
    uint64_t handles[4][6][128];
    uint64_t texture_pool,sampler_pool;
    uint64_t programDevice,computeDevice;
    float viewports[16][4],depth_ranges[16][2],blend_color[4];
    int32_t scissors[16][4];
    unsigned viewport_count,scissor_count;
}
@property(nonatomic,strong) SMOMetalShader *vs;
@property(nonatomic,strong) SMOMetalShader *fs;
@property(nonatomic,strong) SMOMetalShader *cs;
@property(nonatomic,strong) NSMutableDictionary<NSString *,id<MTLComputePipelineState>> *computePipelines;
@property(nonatomic,strong) NSMutableDictionary<NSString *,SMOMetalShader *> *shaders;
@property(nonatomic,strong) NSMutableDictionary<NSString *,id<MTLRenderPipelineState>> *pipelines;
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSNumber *> *drawGenerations;
@property(nonatomic,strong) NSMutableSet<NSString *> *diagnosedDrawStates;
@property(nonatomic) uint64_t nextDrawGeneration;
@end
@implementation SMORenderState
@end

NSObject *nvn_metal_render_state(void) {
    SMORenderState *s=[SMORenderState new];
    NVNblendState b;nvn_BlendStateSetDefaults(&b);
    for(unsigned i=0;i<8;i++)s->blends[i]=nvn_blend_snapshot(&b);
    NVNcolorState c;nvn_ColorStateSetDefaults(&c);s->color=nvn_color_snapshot(&c);
    NVNchannelMaskState m;nvn_ChannelMaskStateSetDefaults(&m);s->channel=nvn_channel_snapshot(&m);
    NVNdepthStencilState d;nvn_DepthStencilStateSetDefaults(&d);s->depth=nvn_depth_snapshot(&d);
    NVNpolygonState p;nvn_PolygonStateSetDefaults(&p);s->polygon=nvn_polygon_snapshot(&p);
    for(unsigned i=0;i<16;i++)s->depth_ranges[i][1]=1;
    s.shaders=[NSMutableDictionary new];s.pipelines=[NSMutableDictionary new];s.computePipelines=[NSMutableDictionary new];
    s.drawGenerations=[NSMutableDictionary new];
    s.diagnosedDrawStates=[NSMutableSet new];
    return s;
}
void nvn_metal_render_end(SMOGuestEncoder *e) { [e.render endEncoding];e.render=nil; }
static NSString *target_identity(const nvn_resource_snapshot *r) {
    return [NSString stringWithFormat:@"%llx:%llu",(unsigned long long)r->object,
        (unsigned long long)r->words[15]];
}
static int depth_pixel_format(MTLPixelFormat f) {
    switch(f){
    case MTLPixelFormatDepth16Unorm:case MTLPixelFormatDepth32Float:
    case MTLPixelFormatDepth32Float_Stencil8:return 1;
#if !defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    case MTLPixelFormatDepth24Unorm_Stencil8:return 1;   /* iOS 无 D24S8 */
#endif
    default:return 0;
    }
}
static int stencil_pixel_format(MTLPixelFormat f) {
    switch(f){
    case MTLPixelFormatStencil8:case MTLPixelFormatX32_Stencil8:
    case MTLPixelFormatDepth32Float_Stencil8:return 1;
#if !defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    case MTLPixelFormatX24_Stencil8:case MTLPixelFormatDepth24Unorm_Stencil8:return 1;   /* iOS 无 D24S8 */
#endif
    default:return 0;
    }
}
/* Ryujinx 翻译器给着色器注入的合成常量缓冲（support_buffer，参考实现 NVN_RB_SUPPORT 同款）。
 * 布局照参考实现实测：alpha_test u32@0、is_bgra u32[8]@16、viewport_inverse f4@144、
 * viewport_size f4@160、frag_scale_count i32@176、render_scale float4[73]@192（取 .x）。
 * SMO 全库只读 render_scale[0].x（本地 134 处），按参考默认填：缩放 1.0、BGRA 互换 0、其余 0。 */
static id<MTLBuffer> support_buffer_for(id<MTLDevice> device) {
    static __strong id<MTLBuffer> buffer;
    if(!buffer){
        buffer=[device newBufferWithLength:65536 options:MTLResourceStorageModeShared];
        if(buffer)for(int i=0;i<73;i++)*((float *)buffer.contents+48+4*i)=1.0f;   /* offset 192 字节 */
    }
    return buffer;
}
/* c1 = 着色器自带常数段；游戏没提供（c1.bin 长 0）时读全 0 —— 参考实现的 zero_bank。 */
static id<MTLBuffer> zero_bank_for(id<MTLDevice> device) {
    static __strong id<MTLBuffer> buffer;
    if(!buffer)buffer=[device newBufferWithLength:65536 options:MTLResourceStorageModeShared];
    return buffer;
}
uint64_t nvn_metal_render_generation(NSObject *state,const nvn_resource_snapshot *r) {
    return ((SMORenderState *)state).drawGenerations[target_identity(r)].unsignedLongLongValue;
}
static void mark_draw(SMORenderState *s) {
    uint64_t generation=++s.nextDrawGeneration;
    for(int i=0;i<s->targets.count;i++)if(s->targets.colors[i].resource.object)
        s.drawGenerations[target_identity(&s->targets.colors[i].resource)]=@(generation);
}
static int reject(const char *what) { NVN_LOG("NVN_METAL_RENDER_UNSUPPORTED %s",what);return 0; }
static void private_metal_error(NSString *key,NSError *error) {
    /* Metal descriptions can embed source excerpts. Only domain/code are public. */
    const char *directory=getenv("SMO_SHADER_CAPTURE_DIR");
    if(!directory || !error)return;
    NSString *detail=error.localizedDescription;
    if(detail.length>16000)detail=[detail substringToIndex:16000];
    NSString *path=[[NSString stringWithUTF8String:directory] stringByAppendingPathComponent:
        [NSString stringWithFormat:@"metal-error-%@.txt",key]];
    [detail writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}
static id<MTLTexture> attachment_texture(SMOGuestEncoder *e,const nvn_attachment *a) {
    if(!a->resource.object)return nil;
    return nvn_metal_texture(e.device,&a->resource,a->has_view?&a->view:NULL,1);
}
static MTLRenderPassDescriptor *pass_for(SMOGuestEncoder *e) {
    SMORenderState *s=(SMORenderState *)e.renderState;
    MTLRenderPassDescriptor *p=[MTLRenderPassDescriptor renderPassDescriptor];
    unsigned active=0;
    for(int i=0;i<s->targets.count;i++)if(s->targets.colors[i].resource.object){
        id<MTLTexture> t=attachment_texture(e,&s->targets.colors[i]);if(!t)return nil;
        if(t.arrayLength!=1 || t.textureType==MTLTextureTypeCube)return nil;
        p.colorAttachments[i].texture=t;p.colorAttachments[i].loadAction=MTLLoadActionLoad;
        p.colorAttachments[i].storeAction=MTLStoreActionStore;active++;
    }
    if(s->targets.depth.resource.object){
        id<MTLTexture> t=attachment_texture(e,&s->targets.depth);if(!t || t.arrayLength!=1)return nil;
        MTLPixelFormat f=t.pixelFormat;
        /* 真机 v0.6.19：游戏把一个 RG11B10Float 贴图当深度目标绑定。以前任何非 Stencil8
         * 格式都进 depthAttachment → Metal 校验断言「not depth renderable」→ SIGABRT。
         * 深度附件格式不合法时：记一次完整证据（贴图描述字 + 视图状态 + 生效格式），
         * 丢这个深度附件继续画颜色（绝不进 Metal 描述符）。 */
        if(!depth_pixel_format(f)){
            static NSMutableSet<NSString *> *reported;
            NSString *identity=[target_identity(&s->targets.depth.resource) stringByAppendingFormat:@":%lu",(unsigned long)f];
            @synchronized([SMORenderState class]){
                if(!reported)reported=[NSMutableSet new];
                if(![reported containsObject:identity]&&reported.count<8){
                    [reported addObject:identity];
                    const uint64_t *w=s->targets.depth.resource.words;
                    nvn_view_state v={0};if(s->targets.depth.has_view)v=s->targets.depth.view;
                    NVN_LOG("NVN_METAL_DEPTH_TARGET_BAD object=%#llx serial=%llu words=%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx view=%u,%d,%d,%d,%d,%d,%d,%u,%u,%u,%u,%d texture=%lu/%lu/%lu/%lu",
                        (unsigned long long)s->targets.depth.resource.object,(unsigned long long)w[15],
                        (unsigned long long)w[0],(unsigned long long)w[1],(unsigned long long)w[2],(unsigned long long)w[3],
                        (unsigned long long)w[4],(unsigned long long)w[5],(unsigned long long)w[6],(unsigned long long)w[7],
                        (unsigned long long)w[8],(unsigned long long)w[9],(unsigned long long)w[10],(unsigned long long)w[11],
                        (unsigned long long)w[12],(unsigned long long)w[13],(unsigned long long)w[14],(unsigned long long)w[15],
                        s->targets.depth.has_view!=0,v.flags,v.base_level,v.level_count,v.base_layer,v.layer_count,
                        v.format,v.target,v.swizzle[0],v.swizzle[1],v.swizzle[2],v.swizzle[3],v.depth_stencil,
                        (unsigned long)f,(unsigned long)t.textureType,(unsigned long)t.arrayLength,(unsigned long)t.sampleCount);
                }
            }
        }else{
            p.depthAttachment.texture=t;p.depthAttachment.loadAction=MTLLoadActionLoad;p.depthAttachment.storeAction=MTLStoreActionStore;
        }
        if(stencil_pixel_format(f)){
            p.stencilAttachment.texture=t;p.stencilAttachment.loadAction=MTLLoadActionLoad;p.stencilAttachment.storeAction=MTLStoreActionStore;
        }
        if(p.depthAttachment.texture||p.stencilAttachment.texture)active++;
    }
    if(active&&getenv("SMO_FRAME_CAPTURE_DIR")){
        if(!e.visibilityBuffer)e.visibilityBuffer=[e.device newBufferWithLength:4096 options:MTLResourceStorageModeShared];
        p.visibilityResultBuffer=e.visibilityBuffer;
    }
    return active?p:nil;
}
static int full_scissor(SMORenderState *s,id<MTLTexture> t) {
    return !s->scissor_count || (s->scissor_count==1 && s->scissors[0][0]<=0 && s->scissors[0][1]<=0 &&
        (int64_t)s->scissors[0][0]+s->scissors[0][2]>=(int64_t)t.width &&
        (int64_t)s->scissors[0][1]+s->scissors[0][3]>=(int64_t)t.height);
}
static int guest_depth_mode(SMORenderState *s) {
    nvn_st_ent *device=nvn_st_get((void *)(uintptr_t)s->programDevice,1);
    return device?(int)device->v[5]:1; /* synthetic host shaders already use Metal depth */
}
static NSData *shader_data(NSString *root,NSString *name) {
    if(nvn_shader_archive_active()){
        size_t length=0;void *bytes=nvn_shader_archive_read(name.UTF8String,&length);
        if(!bytes)return nil;
        return [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:YES];
    }
    return [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:name]];
}
static NSString *shader_source(NSString *root,NSString *name) {
    NSData *data=shader_data(root,name);
    return data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:nil;
}
static SMOMetalShader *load_shader(SMOGuestEncoder *e,const nvn_shader_ent *entry,int depthMode) {
    SMORenderState *s=(SMORenderState *)e.renderState;
    NSString *filename=[NSString stringWithUTF8String:entry->msl];
    NSString *key=filename.stringByDeletingPathExtension;
    if(entry->stage!=1)depthMode=1;  /* depth variants exist only for vertex shaders */
    if(depthMode!=0&&depthMode!=1){reject("device depth mode");return nil;}
    NSString *cacheKey=[NSString stringWithFormat:@"%@:%d",key,depthMode];
    SMOMetalShader *cached=s.shaders[cacheKey];
    if(cached){atomic_fetch_add(&metal_shader_cache_hits,1);log_cache_stats_if_due();return cached;}
    atomic_fetch_add(&metal_shader_cache_misses,1);log_cache_stats_if_due();
    const char *directory=getenv("SMO_SHADER_DIR");
    if(!directory){reject("SMO_SHADER_DIR missing");return nil;}
    NSString *root=[NSString stringWithUTF8String:directory];
    if(![filename.lastPathComponent isEqualToString:filename])return nil;
    NSError *error=nil;
    NSString *source=shader_source(root,filename);
    NSData *data=shader_data(root,[key stringByAppendingString:@".bindings.json"]);
    NSDictionary *bindings=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:&error]:nil;
    if(!source || ![bindings isKindOfClass:[NSDictionary class]] || [bindings[@"version"] intValue]!=1 ||
       ![bindings[@"key"] isEqualToString:key] || [bindings[@"stage"] intValue]!=entry->stage ||
       ![bindings[@"arguments"] isKindOfClass:[NSArray class]] || [bindings[@"unsupported_arguments"] count]){
        NVN_LOG("NVN_METAL_SHADER_MISSING key=%s stage=%u",key.UTF8String,entry->stage);return nil;
    }
    if(entry->stage==1&&depthMode==0){
        NSString *variant=bindings[@"depth_clip_source"];
        if(![variant isKindOfClass:NSString.class]||![variant.lastPathComponent isEqualToString:variant]){
            NVN_LOG("NVN_METAL_SHADER_DEPTH_VARIANT_MISSING key=%s",key.UTF8String);return nil;
        }
        source=shader_source(root,variant);
        if(!source)return nil;
    }
    MTLCompileOptions *options=[MTLCompileOptions new];
    if(@available(macOS 15.0,iOS 18.0,*)){
        options.mathMode=MTLMathModeSafe;options.mathFloatingPointFunctions=MTLMathFloatingPointFunctionsPrecise;
    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        options.fastMathEnabled=NO;
#pragma clang diagnostic pop
    }
    id<MTLLibrary> library=[e.device newLibraryWithSource:source options:options error:&error];
    id<MTLFunction> function=[library newFunctionWithName:bindings[@"entry"]];
    if(!function){
        NVN_LOG("NVN_METAL_SHADER_COMPILE_FAILED key=%s domain=%s code=%ld",key.UTF8String,
            error.domain.UTF8String ?: "missing entry",(long)error.code);
        private_metal_error(key,error);return nil;
    }
    SMOMetalShader *result=[SMOMetalShader new];result.function=function;result.bindings=bindings;
    result.cacheKey=cacheKey;result.depthMode=depthMode;result.sourceEntry=*entry;
    for(NSDictionary *arg in bindings[@"arguments"])
        if([arg[@"kind"] isEqualToString:@"constant"] ||
           ([arg[@"kind"] isEqualToString:@"cbuf"] && [arg[@"slot"] intValue]==1)){
        NSString *hex=bindings[@"constant_data"];
        if(hex!=nil && (![hex isKindOfClass:NSString.class] || hex.length>131072 || hex.length%2))return nil;
        result.constants=[e.device newBufferWithLength:65536 options:MTLResourceStorageModeShared];
        if(!result.constants)return nil;
        if(hex){
            uint8_t *bytes=result.constants.contents;
            for(NSUInteger i=0;i<hex.length/2;i++){
                unsigned value=0;
                for(unsigned j=0;j<2;j++){
                    unichar c=[hex characterAtIndex:i*2+j];unsigned n=c>='0'&&c<='9'?c-'0':c>='a'&&c<='f'?c-'a'+10:16;
                    if(n>15)return nil;value=value*16+n;
                }
                bytes[i]=(uint8_t)value;
            }
        }
        break;
    }
    if([bindings[@"arguments"] count]){
        result.arguments=[function newArgumentEncoderWithBufferIndex:[bindings[@"argument_buffer"] unsignedIntegerValue]];
        if(!result.arguments)return nil;
    }
    s.shaders[cacheKey]=result;
    NVN_LOG("NVN_METAL_SHADER_READY key=%s stage=%u depth=%d",key.UTF8String,entry->stage,depthMode);
    return result;
}
static MTLVertexFormat vertex_format(unsigned fmt) {
    switch(fmt){
#define V(n,f) case n:return MTLVertexFormat##f
    V(1,UCharNormalized);V(2,CharNormalized);V(3,UChar);V(4,Char);
    V(5,Half);V(6,UShortNormalized);V(7,ShortNormalized);V(8,UShort);V(9,Short);
    V(10,Float);V(11,UInt);V(12,Int);
    V(13,UChar2Normalized);V(14,Char2Normalized);V(15,UChar2);V(16,Char2);
    V(17,Half2);V(18,UShort2Normalized);V(19,Short2Normalized);V(20,UShort2);V(21,Short2);
    V(22,Float2);V(23,UInt2);V(24,Int2);
    V(25,UChar3Normalized);V(26,Char3Normalized);V(27,UChar3);V(28,Char3);
    V(29,Half3);V(30,UShort3Normalized);V(31,Short3Normalized);V(32,UShort3);V(33,Short3);
    V(34,Float3);V(35,UInt3);V(36,Int3);
    V(37,UChar4Normalized);V(38,Char4Normalized);V(39,UChar4);V(40,Char4);
    V(41,Half4);V(42,UShort4Normalized);V(43,Short4Normalized);V(44,UShort4);V(45,Short4);
    V(46,Float4);V(47,UInt4);V(48,Int4);
    V(61,UInt1010102Normalized);
    V(63,FloatRG11B10);
    /* NVN 0x69 (decimal 105) is the signed 10:10:10:2 vertex format.
     * Odyssey uses it for packed normals/tangents.  Treating it as an
     * unknown format made every pipeline using those meshes get dropped. */
    V(105,Int1010102Normalized);
    V(154,UChar4Normalized_BGRA);
#undef V
    default:return MTLVertexFormatInvalid;
    }
}
static MTLBlendFactor blend_factor(unsigned factor) {
    switch(factor){
#define B(n,f) case n:return MTLBlendFactor##f
    B(1,Zero);B(2,One);B(3,SourceColor);B(4,OneMinusSourceColor);B(5,SourceAlpha);B(6,OneMinusSourceAlpha);
    B(7,DestinationAlpha);B(8,OneMinusDestinationAlpha);B(9,DestinationColor);B(10,OneMinusDestinationColor);
    B(11,SourceAlphaSaturated);B(16,Source1Color);B(17,OneMinusSource1Color);B(18,Source1Alpha);B(19,OneMinusSource1Alpha);
    B(97,BlendColor);B(98,OneMinusBlendColor);B(99,BlendAlpha);B(100,OneMinusBlendAlpha);
#undef B
    default:return (MTLBlendFactor)NSUIntegerMax;
    }
}
static MTLColorWriteMask write_mask(unsigned m) {
    return (m&1?MTLColorWriteMaskRed:0)|(m&2?MTLColorWriteMaskGreen:0)|
           (m&4?MTLColorWriteMaskBlue:0)|(m&8?MTLColorWriteMaskAlpha:0);
}
/* NVN 的清除受裁剪矩形、通道掩码、模板掩码约束；Metal 的 loadAction 只能清整张附件。
 * 不满足「整张清」时画一个被裁剪的全屏三角形来清。真机 v0.6.15：Start 后每帧
 * 「scissored clear depth」→ 整条命令缓冲失败 ×851 → 黑屏。 */
static int integer_format(MTLPixelFormat f) {
    switch(f){
    case MTLPixelFormatR8Uint:case MTLPixelFormatR16Uint:case MTLPixelFormatR32Uint:case MTLPixelFormatRG8Uint:
    case MTLPixelFormatRG16Uint:case MTLPixelFormatRG32Uint:case MTLPixelFormatRGBA8Uint:case MTLPixelFormatRGBA16Uint:
    case MTLPixelFormatRGBA32Uint:case MTLPixelFormatRGB10A2Uint:return 1;
    case MTLPixelFormatR8Sint:case MTLPixelFormatR16Sint:case MTLPixelFormatR32Sint:case MTLPixelFormatRG8Sint:
    case MTLPixelFormatRG16Sint:case MTLPixelFormatRG32Sint:case MTLPixelFormatRGBA8Sint:case MTLPixelFormatRGBA16Sint:
    case MTLPixelFormatRGBA32Sint:return 2;
    default:return 0;
    }
}
static id<MTLRenderPipelineState> clear_pipeline(SMOGuestEncoder *e,MTLRenderPassDescriptor *pass,int index,unsigned mask) {
    static NSMutableDictionary<NSString *,id<MTLRenderPipelineState>> *cache;
    NSMutableString *key=[NSMutableString stringWithFormat:@"%d:%u",index,mask];
    NSUInteger samples=1;
    for(unsigned i=0;i<8;i++){id<MTLTexture> t=pass.colorAttachments[i].texture;
        [key appendFormat:@":%lu",(unsigned long)t.pixelFormat];if(t)samples=t.sampleCount;}
    id<MTLTexture> depth=pass.depthAttachment.texture,stencil=pass.stencilAttachment.texture;
    if(depth||stencil)samples=(depth?:stencil).sampleCount;
    MTLPixelFormat depth_fmt=depth.pixelFormat,stencil_fmt=stencil.pixelFormat;
    if(!depth_pixel_format(depth_fmt))depth_fmt=MTLPixelFormatInvalid;
    if(!stencil_pixel_format(stencil_fmt))stencil_fmt=MTLPixelFormatInvalid;
    [key appendFormat:@":%lu:%lu:%lu",(unsigned long)depth_fmt,(unsigned long)stencil_fmt,(unsigned long)samples];
    @synchronized([SMORenderState class]){
        if(!cache)cache=[NSMutableDictionary new];
        id<MTLRenderPipelineState> cached=cache[key];if(cached)return cached;
        NSString *fragment=@"";
        if(index>=0){
            int kind=integer_format(pass.colorAttachments[index].texture.pixelFormat);
            NSString *type=kind==1?@"uint4":kind==2?@"int4":@"float4";
            fragment=[NSString stringWithFormat:@"struct F{%@ c [[color(%d)]];};\n"
                "fragment F clear_fs(constant float4 &v [[buffer(0)]]){F o;o.c=%@(v);return o;}\n",type,index,type];
        }
        NSString *source=[NSString stringWithFormat:@"#include <metal_stdlib>\nusing namespace metal;\n"
            "struct V{float4 p [[position]];};\n"
            "vertex V clear_vs(uint id [[vertex_id]],constant float &z [[buffer(0)]]){"
            "V o;float2 uv=float2((id<<1)&2,id&2);o.p=float4(uv*2-1,z,1);return o;}\n%@",fragment];
        NSError *error=nil;id<MTLLibrary> library=[e.device newLibraryWithSource:source options:nil error:&error];
        if(!library){NVN_LOG("NVN_METAL_CLEAR_PIPELINE_FAILED stage=library code=%ld",(long)error.code);return nil;}
        MTLRenderPipelineDescriptor *d=[MTLRenderPipelineDescriptor new];
        d.vertexFunction=[library newFunctionWithName:@"clear_vs"];
        if(index>=0)d.fragmentFunction=[library newFunctionWithName:@"clear_fs"];
        for(unsigned i=0;i<8;i++){id<MTLTexture> t=pass.colorAttachments[i].texture;if(!t)continue;
            d.colorAttachments[i].pixelFormat=t.pixelFormat;
            d.colorAttachments[i].writeMask=(int)i==index?write_mask(mask):MTLColorWriteMaskNone;}
        d.depthAttachmentPixelFormat=depth_fmt;d.stencilAttachmentPixelFormat=stencil_fmt;
        d.rasterSampleCount=samples;
        cached=[e.device newRenderPipelineStateWithDescriptor:d error:&error];
        if(!cached){NVN_LOG("NVN_METAL_CLEAR_PIPELINE_FAILED stage=pipeline code=%ld",(long)error.code);return nil;}
        cache[key]=cached;return cached;
    }
}
static int scissored_clear(SMOGuestEncoder *e,MTLRenderPassDescriptor *pass,id<MTLTexture> target,int index,unsigned mask,
                           const float *color,int clear_depth,float depth,unsigned stencil_mask,int stencil) {
    SMORenderState *s=(SMORenderState *)e.renderState;
    int64_t x=0,y=0,right=target.width,bottom=target.height;
    if(s->scissor_count){int32_t *r=s->scissors[0];x=MAX(0,r[0]);y=MAX(0,r[1]);
        right=MIN(right,(int64_t)r[0]+r[2]);bottom=MIN(bottom,(int64_t)r[1]+r[3]);}
    if(right<=x||bottom<=y)return 1;
    id<MTLRenderPipelineState> pipeline=clear_pipeline(e,pass,index,mask);if(!pipeline)return 0;
    MTLDepthStencilDescriptor *dd=[MTLDepthStencilDescriptor new];
    dd.depthCompareFunction=MTLCompareFunctionAlways;dd.depthWriteEnabled=clear_depth&&pass.depthAttachment.texture;
    if(stencil_mask&&pass.stencilAttachment.texture){
        MTLStencilDescriptor *st=[MTLStencilDescriptor new];st.stencilCompareFunction=MTLCompareFunctionAlways;
        st.depthStencilPassOperation=MTLStencilOperationReplace;st.writeMask=stencil_mask&255;
        dd.frontFaceStencil=st;dd.backFaceStencil=st;
    }
    id<MTLDepthStencilState> state=[e.device newDepthStencilStateWithDescriptor:dd];
    id<MTLRenderCommandEncoder> r=[e.command renderCommandEncoderWithDescriptor:pass];
    if(!state||!r){[r endEncoding];return 0;}
    [r setRenderPipelineState:pipeline];[r setDepthStencilState:state];[r setStencilReferenceValue:(uint32_t)stencil&255];
    [r setCullMode:MTLCullModeNone];
    [r setViewport:(MTLViewport){0,0,(double)target.width,(double)target.height,0,1}];
    [r setScissorRect:(MTLScissorRect){(NSUInteger)x,(NSUInteger)y,(NSUInteger)(right-x),(NSUInteger)(bottom-y)}];
    [r setVertexBytes:&depth length:sizeof depth atIndex:0];
    if(index>=0)[r setFragmentBytes:color length:4*sizeof(float) atIndex:0];
    [r drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [r endEncoding];return 1;
}
/* 之前管线早退全部静默 → 真机日志只有 235 条「render pipeline」不知道原因。
 * 每个原因记一次（限条数），下一轮日志直接给出黑色画面的出处。 */
static id pipeline_skip(NSString *reason) {
    static NSMutableSet<NSString *> *seen;
    @synchronized([SMORenderState class]){
        if(!seen)seen=[NSMutableSet new];
        if(![seen containsObject:reason]&&seen.count<64){
            [seen addObject:reason];
            NVN_LOG("NVN_METAL_PIPELINE_SKIP %s",reason.UTF8String);
        }
    }
    return nil;
}
static id<MTLRenderPipelineState> pipeline_for(SMOGuestEncoder *e,MTLRenderPassDescriptor *pass) {
    SMORenderState *s=(SMORenderState *)e.renderState;
    if(!s.vs)return nil;
    if(s->color.logic_op!=NVN_LOGIC_OP_COPY || s->color.alpha_func!=NVN_ALPHA_FUNC_ALWAYS){reject("logic/alpha test");return nil;}
    MTLRenderPipelineDescriptor *d=[MTLRenderPipelineDescriptor new];d.vertexFunction=s.vs.function;d.fragmentFunction=s.fs.function;
    NSMutableString *key=[NSMutableString stringWithFormat:@"%@:%@",s.vs.cacheKey,s.fs.cacheKey ?: @"depth"];
    NSUInteger samples=0;
    for(unsigned i=0;i<8;i++){
        id<MTLTexture> tex=pass.colorAttachments[i].texture;
        if(!tex)continue;
        if(samples && samples!=tex.sampleCount)
            return pipeline_skip([NSString stringWithFormat:@"color sample mismatch %lu/%lu",(unsigned long)samples,(unsigned long)tex.sampleCount]);
        samples=tex.sampleCount;
        MTLRenderPipelineColorAttachmentDescriptor *a=d.colorAttachments[i];a.pixelFormat=tex.pixelFormat;
        a.writeMask=write_mask((s->channel.mask>>(4*i))&15);a.blendingEnabled=(s->color.blend_en>>i)&1;
        nvn_blend_state b=s->blends[i];
        if(a.blendingEnabled){
            /* NVN 语义：混合关闭时方程与因子不参与硬件，不因未支持的因子丢绘制。
             * （真机 v0.6.19：×235 render pipeline 静默丢弃，混合因子嫌疑最大。） */
            if(b.advanced_mode || b.eq_rgb<1 || b.eq_rgb>5 || b.eq_a<1 || b.eq_a>5)
                return pipeline_skip([NSString stringWithFormat:@"blend equation advanced=%u rgb=%u alpha=%u",b.advanced_mode,b.eq_rgb,b.eq_a]);
            a.sourceRGBBlendFactor=blend_factor(b.src_rgb);a.destinationRGBBlendFactor=blend_factor(b.dst_rgb);
            a.sourceAlphaBlendFactor=blend_factor(b.src_a);a.destinationAlphaBlendFactor=blend_factor(b.dst_a);
            if(a.sourceRGBBlendFactor==(MTLBlendFactor)NSUIntegerMax || a.destinationRGBBlendFactor==(MTLBlendFactor)NSUIntegerMax ||
               a.sourceAlphaBlendFactor==(MTLBlendFactor)NSUIntegerMax || a.destinationAlphaBlendFactor==(MTLBlendFactor)NSUIntegerMax)
                return pipeline_skip([NSString stringWithFormat:@"blend factor src_rgb=%u dst_rgb=%u src_a=%u dst_a=%u",b.src_rgb,b.dst_rgb,b.src_a,b.dst_a]);
            a.rgbBlendOperation=(MTLBlendOperation)(b.eq_rgb-1);a.alphaBlendOperation=(MTLBlendOperation)(b.eq_a-1);
        }
        [key appendFormat:@":%u:%lu:%u:%u:%u:%u:%u:%u:%u",i,(unsigned long)tex.pixelFormat,(s->channel.mask>>(4*i))&15,
            a.blendingEnabled,(unsigned)b.src_rgb,(unsigned)b.dst_rgb,(unsigned)b.src_a,(unsigned)b.dst_a,(unsigned)(b.eq_rgb|(b.eq_a<<4))];
    }
    id<MTLTexture> depth=pass.depthAttachment.texture ?: pass.stencilAttachment.texture;
    if(depth){if(samples && samples!=depth.sampleCount)
        return pipeline_skip([NSString stringWithFormat:@"depth sample mismatch %lu/%lu",(unsigned long)samples,(unsigned long)depth.sampleCount]);
        samples=depth.sampleCount;}
    d.rasterSampleCount=samples?:1;
    nvn_multisample_state ms=s->multisample;
    if((ms.samples&&ms.samples!=d.rasterSampleCount)||
       (d.rasterSampleCount>1&&!ms.enabled)||(ms.alpha_to_coverage&&ms.dither))
        return pipeline_skip([NSString stringWithFormat:@"multisample state samples=%u enabled=%u a2c=%u dither=%u raster=%lu",ms.samples,ms.enabled,ms.alpha_to_coverage,ms.dither,(unsigned long)d.rasterSampleCount]);
    d.alphaToCoverageEnabled=ms.alpha_to_coverage!=0;
    [key appendFormat:@":a2c%u",ms.alpha_to_coverage];
    MTLPixelFormat depth_fmt=pass.depthAttachment.texture.pixelFormat;
    MTLPixelFormat stencil_fmt=pass.stencilAttachment.texture.pixelFormat;
    if(!depth_pixel_format(depth_fmt))depth_fmt=MTLPixelFormatInvalid;
    if(!stencil_pixel_format(stencil_fmt))stencil_fmt=MTLPixelFormatInvalid;
    d.depthAttachmentPixelFormat=depth_fmt;d.stencilAttachmentPixelFormat=stencil_fmt;
    [key appendFormat:@":%lu:%lu:%lu",(unsigned long)d.rasterSampleCount,(unsigned long)depth_fmt,(unsigned long)stencil_fmt];
    MTLVertexDescriptor *vd=[MTLVertexDescriptor vertexDescriptor];
    for(NSDictionary *input in s.vs.bindings[@"vertex_inputs"]){
        unsigned location=[input[@"location"] unsignedIntValue];if(location>=16)return pipeline_skip(@"vertex location >= 16");
        nvn_vertex_attrib_state a=s->attributes[location];if(a.stream>=16)return pipeline_skip(@"vertex stream >= 16");
        nvn_vertex_stream_state stream=s->streams[a.stream];
        MTLVertexFormat fmt=vertex_format(a.fmt);
        if(!fmt)return pipeline_skip([NSString stringWithFormat:@"vertex format %u",(unsigned)a.fmt]);
        if(!stream.stride)return pipeline_skip(@"vertex stream stride 0");
        vd.attributes[location].format=fmt;vd.attributes[location].offset=a.offset;vd.attributes[location].bufferIndex=1+a.stream;
        vd.layouts[1+a.stream].stride=stream.stride;vd.layouts[1+a.stream].stepFunction=stream.divisor?MTLVertexStepFunctionPerInstance:MTLVertexStepFunctionPerVertex;
        vd.layouts[1+a.stream].stepRate=stream.divisor?:1;
        [key appendFormat:@":v%u:%u:%u:%u:%u:%u",location,(unsigned)a.fmt,(unsigned)a.offset,(unsigned)a.stream,stream.stride,stream.divisor];
    }
    d.vertexDescriptor=vd;
    id<MTLRenderPipelineState> cached=s.pipelines[key];
    if(cached){atomic_fetch_add(&metal_pipeline_cache_hits,1);log_cache_stats_if_due();return cached;}
    atomic_fetch_add(&metal_pipeline_cache_misses,1);log_cache_stats_if_due();
    NSError *error=nil;cached=[e.device newRenderPipelineStateWithDescriptor:d error:&error];
    if(!cached){
        NVN_LOG("NVN_METAL_PIPELINE_FAILED domain=%s code=%ld",error.domain.UTF8String ?: "unknown",(long)error.code);
        private_metal_error(@"pipeline",error);return nil;
    }
    s.pipelines[key]=cached;return cached;
}

static int arguments_for(SMOGuestEncoder *e,SMOMetalShader *shader,unsigned stage) {
    if(!shader || !shader.arguments)return 1;
    SMORenderState *s=(SMORenderState *)e.renderState;
    id<MTLArgumentEncoder> encoder=shader.arguments;
    id<MTLBuffer> args=[e.device newBufferWithLength:encoder.encodedLength options:MTLResourceStorageModeShared];
    if(!args)return 0;
    [encoder setArgumentBuffer:args offset:0];
    for(NSDictionary *arg in shader.bindings[@"arguments"]){
        unsigned aid=[arg[@"id"] unsignedIntValue];NSString *kind=arg[@"kind"];
        if([kind isEqualToString:@"constant"]){
            if(!shader.constants)return reject("missing shader constant segment");
            [encoder setBuffer:shader.constants offset:0 atIndex:aid];
            [e.render useResource:shader.constants usage:MTLResourceUsageRead stages:stage==0?MTLRenderStageVertex:MTLRenderStageFragment];
            continue;
        }
        if([kind isEqualToString:@"support"]){
            /* 合成 support_buffer（见 support_buffer_for）：不来自游戏绑定，宿主填默认值。
             * 真机 v0.6.19：×457 NVN_METAL_BINDING_UNRESOLVED name=support_buffer —— 整类绘制被丢。 */
            id<MTLBuffer> buffer=support_buffer_for(e.device);
            if(!buffer)return reject("support buffer allocation");
            [encoder setBuffer:buffer offset:0 atIndex:aid];
            [e.render useResource:buffer usage:MTLResourceUsageRead stages:stage==0?MTLRenderStageVertex:MTLRenderStageFragment];
            continue;
        }
        if([kind isEqualToString:@"cbuf"] && [arg[@"slot"] intValue]==1){
            /* c1 = 着色器常数段（参考实现 NVN_RB_C1）：有 c1.bin 用真数据，没有读全 0。
             * 真机 v0.6.19：×44 fp_c1 / ×14 vp_c1 未解析 —— 全部走「读 0」。 */
            id<MTLBuffer> buffer=shader.constants ?: zero_bank_for(e.device);
            if(!buffer)return reject("shader constant bank");
            [encoder setBuffer:buffer offset:0 atIndex:aid];
            [e.render useResource:buffer usage:MTLResourceUsageRead stages:stage==0?MTLRenderStageVertex:MTLRenderStageFragment];
            continue;
        }
        /* Maxwell bank numbers and texture instruction immediates are not NVN
         * binding slots. Metadata must carry a verified conversion explicitly. */
        if(!arg[@"nvn_slot"]){
            NVN_LOG("NVN_METAL_BINDING_UNRESOLVED stage=%u name=%s",stage,[arg[@"name"] UTF8String]);return 0;
        }
        int slot=[arg[@"nvn_slot"] intValue];
        if([kind isEqualToString:@"cbuf"] || [kind isEqualToString:@"sbuf"]){
            if(slot<0 || slot>=32)return 0;
            int storage=[kind isEqualToString:@"sbuf"];
            NVNbufferRange range=storage?s->storage[stage][slot]:s->uniforms[stage][slot];
            if(!range.size)return reject("unbound shader buffer");
            NSUInteger offset=0;id<MTLBuffer> buffer=nvn_metal_buffer(e,range.address,range.size,&offset);
            if(!buffer)return 0;
            [encoder setBuffer:buffer offset:offset atIndex:aid];
            [e.render useResource:buffer usage:storage?MTLResourceUsageRead|MTLResourceUsageWrite:MTLResourceUsageRead
                stages:stage==0?MTLRenderStageVertex:MTLRenderStageFragment];
        }else if([kind isEqualToString:@"texture"] || [kind isEqualToString:@"sampler"]){
            if(slot<0 || slot>=128 || (arg[@"array"] && [arg[@"array"] intValue]!=1))return reject("texture argument array");
            int sampler=[kind isEqualToString:@"sampler"];
            int separate=[arg[@"separate"] boolValue];
            uint64_t handle=s->handles[sampler&&separate?NVN_BIND_SAMPLER:NVN_BIND_TEXTURE][stage][slot];
            nvn_resource_snapshot resource;
            if(sampler){
                if(!nvn_resources_sampler((void *)(uintptr_t)s->sampler_pool,(uint32_t)(handle>>20),&resource))return reject("unregistered sampler descriptor");
                id<MTLSamplerState> state=nvn_metal_sampler(e.device,&resource);if(!state)return 0;
                [encoder setSamplerState:state atIndex:aid];
            }else{
                nvn_view_state view;
                if(!nvn_resources_texture((void *)(uintptr_t)s->texture_pool,(uint32_t)(handle&0xfffff),0,&resource,&view))return reject("unregistered texture descriptor");
                id<MTLTexture> texture=nvn_metal_texture(e.device,&resource,&view,0);if(!texture)return 0;
                [encoder setTexture:texture atIndex:aid];[e.render useResource:texture usage:MTLResourceUsageRead
                    stages:stage==0?MTLRenderStageVertex:MTLRenderStageFragment];
            }
        }else return reject("shader support/driver/image argument");
    }
    NSUInteger index=[shader.bindings[@"argument_buffer"] unsignedIntegerValue];
    if(stage==0)[e.render setVertexBuffer:args offset:0 atIndex:index];
    else [e.render setFragmentBuffer:args offset:0 atIndex:index];
    return 1;
}
static int set_depth_state(SMOGuestEncoder *e,MTLRenderPassDescriptor *pass) {
    SMORenderState *s=(SMORenderState *)e.renderState;nvn_depth_state d=s->depth;
    if(d.df<1 || d.df>8)return 0;
    MTLDepthStencilDescriptor *desc=[MTLDepthStencilDescriptor new];
    desc.depthCompareFunction=d.dt?(MTLCompareFunction)(d.df-1):MTLCompareFunctionAlways;
    /* 深度附件被守卫丢弃（格式不合法）时不能再开深度写：Metal 校验会报
     * 「depth write enabled without depth attachment」。 */
    desc.depthWriteEnabled=d.dt&&d.dw&&pass.depthAttachment.texture!=nil;
    if(d.st){
        unsigned funcs[]={d.sf_f,d.sf_b},fail[]={d.fail_f,d.fail_b},zfail[]={d.zfail_f,d.zfail_b},zpass[]={d.zpass_f,d.zpass_b};
        for(unsigned i=0;i<2;i++){
            if(funcs[i]<1||funcs[i]>8||fail[i]<1||fail[i]>8||zfail[i]<1||zfail[i]>8||zpass[i]<1||zpass[i]>8)return 0;
            MTLStencilDescriptor *st=[MTLStencilDescriptor new];st.stencilCompareFunction=(MTLCompareFunction)(funcs[i]-1);
            st.stencilFailureOperation=(MTLStencilOperation)(fail[i]-1);st.depthFailureOperation=(MTLStencilOperation)(zfail[i]-1);
            st.depthStencilPassOperation=(MTLStencilOperation)(zpass[i]-1);
            if(i)desc.backFaceStencil=st;else desc.frontFaceStencil=st;
        }
    }
    id<MTLDepthStencilState> state=[e.device newDepthStencilStateWithDescriptor:desc];if(!state)return 0;
    [e.render setDepthStencilState:state];return 1;
}
/* 单条绘制用到了还没实现的特性：只丢这一条（返回 2），不让整条命令缓冲失败。
 * 以前 reject() 一路返回 0 → 整个命令缓冲（通常就是整帧）被跳过 → Start 后全黑。 */
static int skip_draw(const char *what) {
    static NSMutableSet<NSString *> *seen;
    @synchronized([SMORenderState class]){
        if(!seen)seen=[NSMutableSet new];
        NSString *k=[NSString stringWithUTF8String:what];
        if(![seen containsObject:k]){[seen addObject:k];NVN_LOG("NVN_METAL_DRAW_SKIPPED %s（只丢这一条绘制）",what);}
    }
    return 2;
}
static int prepare_draw(SMOGuestEncoder *e) {
    SMORenderState *s=(SMORenderState *)e.renderState;
    if(!s.vs)return skip_draw("no matched vertex shader");
    if(!s.fs){
        int color=0;for(int i=0;i<s->targets.count;i++)color|=s->targets.colors[i].resource.object!=0;
        if(color)return skip_draw("no matched fragment shader");
    }
    int depthMode=guest_depth_mode(s);
    if(s.vs&&s.vs.depthMode!=depthMode){
        nvn_shader_ent entry=s.vs.sourceEntry;
        s.vs=load_shader(e,&entry,depthMode);if(!s.vs)return 0;
    }
    MTLRenderPassDescriptor *pass=pass_for(e);
    if(!pass){
        /* 附件解析不出来（典型：场景切换时游戏重建了纹理，而录下的命令还引用旧的）：
         * 放弃这一遍绘制、继续跑，而不是让整帧提交失败（那会 NVN_DIE → 闪退）。
         * 真机上 NVN 按地址访问、不校验生命周期，我们也不该因为生命周期而杀进程。 */
        if(!e.skipPass){
            static unsigned logged;
            if(logged<16){logged++;NVN_LOG("NVN_RENDER_PASS_SKIPPED attachments（本遍绘制丢弃，继续运行）");}
        }
        e.skipPass=1;
        nvn_metal_render_end(e);
        return 1;
    }
    id<MTLRenderPipelineState> pipeline=pipeline_for(e,pass);if(!pipeline)return reject("render pipeline");
    if(!e.render){
        [e.blit endEncoding];e.blit=nil;
        e.render=[e.command renderCommandEncoderWithDescriptor:pass];if(!e.render)return 0;
    }
    [e.render setRenderPipelineState:pipeline];
    if(!set_depth_state(e,pass))return 0;
    if(s->polygon.cull==NVN_FACE_FRONT_AND_BACK)return 2;  /* 两面都剔除：本来就什么都不画 */
    [e.render setCullMode:s->polygon.cull==NVN_FACE_FRONT?MTLCullModeFront:s->polygon.cull==NVN_FACE_BACK?MTLCullModeBack:MTLCullModeNone];
    [e.render setFrontFacingWinding:s->polygon.front?MTLWindingCounterClockwise:MTLWindingClockwise];
    if(s->polygon.mode==NVN_POLYGON_MODE_POINT)return skip_draw("polygon mode point");
    /* 深度偏移的系数走 SetPolygonOffsetClamp（尚未录制）：先按无偏移画，最坏是贴花/阴影 z-fighting，
     * 远好过整帧丢弃。 */
    if(s->polygon.offset_en)skip_draw("polygon offset ignored");
    [e.render setTriangleFillMode:s->polygon.mode==NVN_POLYGON_MODE_LINE?MTLTriangleFillModeLines:MTLTriangleFillModeFill];
    [e.render setBlendColorRed:s->blend_color[0] green:s->blend_color[1] blue:s->blend_color[2] alpha:s->blend_color[3]];
    id<MTLTexture> target=pass.depthAttachment.texture;
    for(unsigned i=0;i<8 && !target;i++)target=pass.colorAttachments[i].texture;
    if(s->viewport_count>1 || s->scissor_count>1)return reject("multiple viewports/scissors");
    float *v=s->viewports[0],*z=s->depth_ranges[0];
    if(s->viewport_count && (!isfinite(v[0])||!isfinite(v[1])||!isfinite(v[2])||!isfinite(v[3])||v[2]<0||v[3]<0))return 0;
    MTLViewport viewport={0,0,target.width,target.height,z[0],z[1]};
    if(s->viewport_count){viewport.originX=v[0];viewport.originY=v[1];viewport.width=v[2];viewport.height=v[3];}
    [e.render setViewport:viewport];
    int64_t x=0,y=0,right=target.width,bottom=target.height;
    if(s->scissor_count){int32_t *r=s->scissors[0];x=MAX(0,r[0]);y=MAX(0,r[1]);right=MIN(right,(int64_t)r[0]+r[2]);bottom=MIN(bottom,(int64_t)r[1]+r[3]);}
    if(x>=(int64_t)target.width||y>=(int64_t)target.height||right<=x||bottom<=y)return 2;
    [e.render setScissorRect:(MTLScissorRect){(NSUInteger)x,(NSUInteger)y,(NSUInteger)(right-x),(NSUInteger)(bottom-y)}];
    for(NSDictionary *input in s.vs.bindings[@"vertex_inputs"]){
        unsigned a=[input[@"location"] unsignedIntValue];if(a>=16)return 0;
        unsigned stream=s->attributes[a].stream;if(stream>=16)return 0;
        NVNbufferRange range=s->vertex[stream];NSUInteger offset=0;
        id<MTLBuffer> buffer=range.size?nvn_metal_buffer(e,range.address,range.size,&offset):nil;
        if(!buffer)return reject("unbound vertex buffer");
        [e.render setVertexBuffer:buffer offset:offset atIndex:stream+1];
    }
    if(!arguments_for(e,s.vs,0)||!arguments_for(e,s.fs,1))return 0;
    if(getenv("SMO_FRAME_CAPTURE_DIR")&&s.diagnosedDrawStates.count<32){
        NSString *identity=[NSString stringWithFormat:@"%@:%@:%u:%u:%u:%u:%u",s.vs.bindings[@"key"],
            s.fs.bindings[@"key"]?:@"depth",s->polygon.cull,s->polygon.front,s->channel.mask,s->color.blend_en,s->depth.dt];
        if(![s.diagnosedDrawStates containsObject:identity]){
            [s.diagnosedDrawStates addObject:identity];
            NVN_LOG("NVN_METAL_DRAW_STATE vs=%s fs=%s target=%lux%lu mask=%#x blend=%u cull=%u front=%u depth=%u/%u viewport=%.1f,%.1f,%.1f,%.1f scissor=%lld,%lld,%lld,%lld",
                [s.vs.bindings[@"key"] UTF8String],[s.fs.bindings[@"key"] UTF8String]?:"depth",
                (unsigned long)target.width,(unsigned long)target.height,s->channel.mask,s->color.blend_en,
                s->polygon.cull,s->polygon.front,s->depth.dt,s->depth.df,
                viewport.originX,viewport.originY,viewport.width,viewport.height,
                (long long)x,(long long)y,(long long)(right-x),(long long)(bottom-y));
            if(e.visibilityBuffer&&e.visibilityCursor<512){
                NSUInteger offset=8*e.visibilityCursor++;id<MTLBuffer> results=e.visibilityBuffer;
                NSString *vs=s.vs.bindings[@"key"],*fs=s.fs.bindings[@"key"]?:@"depth";
                [e.render setVisibilityResultMode:MTLVisibilityResultModeBoolean offset:offset];
                [e.command addCompletedHandler:^(id<MTLCommandBuffer> command){
                    if(command.status==MTLCommandBufferStatusCompleted){
                        uint64_t visible=0;memcpy(&visible,(const uint8_t *)results.contents+offset,8);
                        NVN_LOG("NVN_METAL_DRAW_VISIBILITY vs=%s fs=%s visible=%u",vs.UTF8String,fs.UTF8String,visible!=0);
                    }
                }];
            }
        }
    }
    return 1;
}
static int primitive_type(int primitive,MTLPrimitiveType *out) {
    switch(primitive){
    case NVN_DRAW_PRIMITIVE_POINTS:*out=MTLPrimitiveTypePoint;return 1;
    case NVN_DRAW_PRIMITIVE_LINES:*out=MTLPrimitiveTypeLine;return 1;
    case NVN_DRAW_PRIMITIVE_LINE_STRIP:*out=MTLPrimitiveTypeLineStrip;return 1;
    case NVN_DRAW_PRIMITIVE_TRIANGLES:*out=MTLPrimitiveTypeTriangle;return 1;
    case NVN_DRAW_PRIMITIVE_TRIANGLE_STRIP:*out=MTLPrimitiveTypeTriangleStrip;return 1;
    default:return reject("primitive topology");
    }
}
static int copied_array(const void *payload,size_t size,size_t element,int limit,nvn_cmd_array *header,const void **values) {
    if(size<sizeof *header)return 0;memcpy(header,payload,sizeof *header);
    if(header->first<0||header->count<0||header->first>limit||header->count>limit-header->first||
       size!=((sizeof *header+(size_t)header->count*element+7)&~(size_t)7))return 0;
    *values=(const uint8_t *)payload+sizeof *header;return 1;
}
/* Compute dispatch. Bindings follow the fixture metadata written by
 * smo/gfx/tools/compute/compute_fixture.py:
 *   cbuf r → uniform buffer r of the compute stage; sbuf r → storage buffer r;
 *   constant → shader c1 bank; image r → image handle r (texture pool, image registration);
 *   driver → NVN driver bank c0: storage table at 0x310 + 16 r ({address u64, size u32})
 *            and the dispatch grid size at 0x200 (gl_NumWorkGroups).
 * Indirect dispatch reads its group counts on the GPU: Metal's indirect dispatch takes
 * them from the same buffer, but c0 needs them too, so they are copied into c0 by a blit. */
/* Driver bank c0, filled before the compute encoder opens: an indirect dispatch copies its
 * group counts in with a blit, and Metal allows only one active encoder per command buffer
 * (a blit opened while the compute encoder was active hung the GPU on CI). */
static id<MTLBuffer> compute_driver_bank(SMOGuestEncoder *e,const uint32_t *groups,uint64_t indirect) {
    SMORenderState *s=(SMORenderState *)e.renderState;
    id<MTLBuffer> driver=[e.device newBufferWithLength:65536 options:MTLResourceStorageModeShared];
    if(!driver)return nil;
    uint8_t *bank=driver.contents;memset(bank,0,0x410);
    for(unsigned r=0;r<16;r++){
        NVNbufferRange range=s->storage[NVN_SHADER_STAGE_COMPUTE][r];uint32_t length=(uint32_t)MIN(range.size,(uint64_t)UINT32_MAX);
        memcpy(bank+0x310+16*r,&range.address,8);memcpy(bank+0x310+16*r+8,&length,4);
    }
    if(groups)memcpy(bank+0x200,groups,12);
    else{
        NSUInteger offset=0;id<MTLBuffer> source=nvn_metal_buffer(e,indirect,12,&offset);if(!source)return nil;
        id<MTLBlitCommandEncoder> blit=[e.command blitCommandEncoder];if(!blit)return nil;
        [blit copyFromBuffer:source sourceOffset:offset toBuffer:driver destinationOffset:0x200 size:12];[blit endEncoding];
    }
    return driver;
}
static int compute_arguments(SMOGuestEncoder *e,id<MTLComputeCommandEncoder> encoder,SMOMetalShader *shader,id<MTLBuffer> driver) {
    SMORenderState *s=(SMORenderState *)e.renderState;
    const unsigned stage=NVN_SHADER_STAGE_COMPUTE;
    id<MTLArgumentEncoder> arguments=shader.arguments;
    if(!arguments)return 1;
    id<MTLBuffer> args=[e.device newBufferWithLength:arguments.encodedLength options:MTLResourceStorageModeShared];
    if(!args)return 0;
    [arguments setArgumentBuffer:args offset:0];
    for(NSDictionary *arg in shader.bindings[@"arguments"]){
        unsigned aid=[arg[@"id"] unsignedIntValue];NSString *kind=arg[@"kind"];
        if([kind isEqualToString:@"constant"]){
            if(!shader.constants)return reject("missing compute constant segment");
            [arguments setBuffer:shader.constants offset:0 atIndex:aid];
            [encoder useResource:shader.constants usage:MTLResourceUsageRead];
        }else if([kind isEqualToString:@"driver"]){
            if(!driver)return reject("compute driver bank");
            [arguments setBuffer:driver offset:0 atIndex:aid];
            [encoder useResource:driver usage:MTLResourceUsageRead];
        }else if([kind isEqualToString:@"support"]){
            id<MTLBuffer> buffer=support_buffer_for(e.device);
            if(!buffer)return reject("compute support buffer");
            [arguments setBuffer:buffer offset:0 atIndex:aid];
            [encoder useResource:buffer usage:MTLResourceUsageRead];
        }else if([kind isEqualToString:@"cbuf"] || [kind isEqualToString:@"sbuf"]){
            int slot=[arg[@"nvn_slot"] intValue];if(!arg[@"nvn_slot"] || slot<0 || slot>=32)return reject("compute buffer slot");
            int storage=[kind isEqualToString:@"sbuf"];
            NVNbufferRange range=storage?s->storage[stage][slot]:s->uniforms[stage][slot];
            if(!range.size)return reject("unbound compute buffer");
            NSUInteger offset=0;id<MTLBuffer> buffer=nvn_metal_buffer(e,range.address,range.size,&offset);if(!buffer)return 0;
            [arguments setBuffer:buffer offset:offset atIndex:aid];
            [encoder useResource:buffer usage:storage?MTLResourceUsageRead|MTLResourceUsageWrite:MTLResourceUsageRead];
        }else if([kind isEqualToString:@"image"]){
            int slot=[arg[@"nvn_slot"] intValue];if(!arg[@"nvn_slot"] || slot<0 || slot>=128)return reject("compute image slot");
            uint64_t handle=s->handles[NVN_BIND_IMAGE][stage][slot];
            nvn_resource_snapshot resource;nvn_view_state view;
            if(!nvn_resources_texture((void *)(uintptr_t)s->texture_pool,(uint32_t)(handle&0xfffff),1,&resource,&view))
                return reject("unregistered compute image descriptor");
            id<MTLTexture> texture=nvn_metal_texture(e.device,&resource,&view,0);if(!texture)return 0;
            if(!(texture.usage&MTLTextureUsageShaderWrite))return reject("compute image without NVN_TEXTURE_FLAGS_IMAGE");
            [arguments setTexture:texture atIndex:aid];
            [encoder useResource:texture usage:MTLResourceUsageRead|MTLResourceUsageWrite];
        }else return reject("compute argument kind");
    }
    [encoder setBuffer:args offset:0 atIndex:[shader.bindings[@"argument_buffer"] unsignedIntegerValue]];
    return 1;
}
static int dispatch_compute(SMOGuestEncoder *e,const uint32_t *groups,uint64_t indirect) {
    SMORenderState *s=(SMORenderState *)e.renderState;
    SMOMetalShader *cs=s.cs;
    if(!cs){skip_draw("compute dispatch without a matched compute shader");return 1;}
    NSArray *size=cs.bindings[@"threadgroup_size"];
    if(![size isKindOfClass:NSArray.class] || size.count!=3)return reject("compute threadgroup size");
    MTLSize threads=MTLSizeMake([size[0] unsignedIntegerValue],[size[1] unsignedIntegerValue],[size[2] unsignedIntegerValue]);
    id<MTLComputePipelineState> pipeline=s.computePipelines[cs.cacheKey];
    if(!pipeline){
        NSError *error=nil;pipeline=[e.device newComputePipelineStateWithFunction:cs.function error:&error];
        if(!pipeline){NVN_LOG("NVN_METAL_COMPUTE_PIPELINE_FAILED domain=%s code=%ld",error.domain.UTF8String?:"unknown",(long)error.code);return 0;}
        s.computePipelines[cs.cacheKey]=pipeline;
    }
    /* Maxwell lane ids are 0..31; spirv-cross maps them to thread_index_in_simdgroup. */
    if(pipeline.threadExecutionWidth!=32)return reject("compute SIMD width is not 32");
    if(threads.width*threads.height*threads.depth>pipeline.maxTotalThreadsPerThreadgroup)return reject("compute threadgroup exceeds device limit");
    nvn_metal_render_end(e);[e.blit endEncoding];e.blit=nil;
    id<MTLBuffer> driver=nil;
    for(NSDictionary *arg in cs.bindings[@"arguments"])if([arg[@"kind"] isEqualToString:@"driver"]){
        driver=compute_driver_bank(e,groups,indirect);if(!driver)return 0;break;
    }
    id<MTLComputeCommandEncoder> encoder=[e.command computeCommandEncoder];if(!encoder)return 0;
    [encoder setComputePipelineState:pipeline];
    int ok=compute_arguments(e,encoder,cs,driver);
    if(ok){
        if(groups)[encoder dispatchThreadgroups:MTLSizeMake(groups[0],groups[1],groups[2]) threadsPerThreadgroup:threads];
        else{
            NSUInteger offset=0;id<MTLBuffer> buffer=nvn_metal_buffer(e,indirect,12,&offset);
            if(buffer)[encoder dispatchThreadgroupsWithIndirectBuffer:buffer indirectBufferOffset:offset threadsPerThreadgroup:threads];
            else ok=0;
        }
    }
    [encoder endEncoding];
    static unsigned logged;
    if(ok && logged<8){logged++;NVN_LOG("NVN_METAL_COMPUTE_DISPATCH key=%s threads=%lux%lux%lu groups=%s",
        cs.cacheKey.UTF8String,(unsigned long)threads.width,(unsigned long)threads.height,(unsigned long)threads.depth,groups?"direct":"indirect");}
    return ok;
}
int nvn_metal_render_encode(SMOGuestEncoder *e,uint32_t op,const void *payload,size_t size) {
    SMORenderState *s=(SMORenderState *)e.renderState;
#define READ(type,name) type name; if(size!=sizeof name)return 0;memcpy(&name,payload,sizeof name)
    switch(op){
    case NVN_CMD_SET_RT:{READ(nvn_cmd_targets,p);if(p.count<0||p.count>8)return 0;nvn_metal_render_end(e);s->targets=p;return 1;}
    case NVN_CMD_CLEAR_COLOR:{
        READ(nvn_cmd_color,c);if(c.index<0||c.index>=s->targets.count)return 0;if(!c.mask)return 1;
        nvn_metal_render_end(e);[e.blit endEncoding];e.blit=nil;
        MTLRenderPassDescriptor *pass=pass_for(e);id<MTLTexture> target=pass.colorAttachments[c.index].texture;
        if(!target)return 1;  /* 附件解析不出来：同 RENDER_PASS_SKIPPED，只丢这次清除 */
        if(c.mask!=15||!full_scissor(s,target)){
            if(!scissored_clear(e,pass,target,c.index,(unsigned)c.mask,c.value,0,0,0,0))return 0;
            [s.drawGenerations removeObjectForKey:target_identity(&s->targets.colors[c.index].resource)];return 1;
        }
        pass.colorAttachments[c.index].loadAction=MTLLoadActionClear;
        pass.colorAttachments[c.index].clearColor=MTLClearColorMake(c.value[0],c.value[1],c.value[2],c.value[3]);
        id<MTLRenderCommandEncoder> clear=[e.command renderCommandEncoderWithDescriptor:pass];if(!clear)return 0;[clear endEncoding];
        [s.drawGenerations removeObjectForKey:target_identity(&s->targets.colors[c.index].resource)];return 1;
    }
    case NVN_CMD_CLEAR_DEPTH:{
        READ(nvn_cmd_depth,c);if(!c.depth_mask&&!c.stencil_mask)return 1;
        nvn_metal_render_end(e);[e.blit endEncoding];e.blit=nil;
        MTLRenderPassDescriptor *pass=pass_for(e);
        id<MTLTexture> tex=pass.depthAttachment.texture ?: pass.stencilAttachment.texture;
        if(!tex)return 1;  /* 没有可清的深度/模板附件：只丢这次清除 */
        unsigned stencil_mask=pass.stencilAttachment.texture?(unsigned)c.stencil_mask&255:0;
        int depth_mask=c.depth_mask&&pass.depthAttachment.texture;
        if(!depth_mask&&!stencil_mask)return 1;
        if(!full_scissor(s,tex)||(stencil_mask&&stencil_mask!=255))
            return scissored_clear(e,pass,tex,-1,0,NULL,depth_mask,c.depth,stencil_mask,c.stencil);
        if(depth_mask){pass.depthAttachment.loadAction=MTLLoadActionClear;pass.depthAttachment.clearDepth=c.depth;}
        if(stencil_mask){
            pass.stencilAttachment.loadAction=MTLLoadActionClear;pass.stencilAttachment.clearStencil=(uint32_t)c.stencil;}
        id<MTLRenderCommandEncoder> clear=[e.command renderCommandEncoderWithDescriptor:pass];if(!clear)return 0;[clear endEncoding];return 1;
    }
    case NVN_CMD_VIEWPORTS:case NVN_CMD_SCISSORS:case NVN_CMD_DEPTH_RANGES:case NVN_CMD_BIND_VATTR:case NVN_CMD_BIND_VSTREAM:{
        nvn_cmd_array a;const void *values;size_t element;
        if(op==NVN_CMD_DEPTH_RANGES)element=8;else if(op==NVN_CMD_BIND_VATTR)element=sizeof(nvn_vertex_attrib_state);
        else if(op==NVN_CMD_BIND_VSTREAM)element=sizeof(nvn_vertex_stream_state);else element=16;
        if(!copied_array(payload,size,element,16,&a,&values))return 0;
        void *dst=op==NVN_CMD_VIEWPORTS?(void *)s->viewports:op==NVN_CMD_SCISSORS?(void *)s->scissors:
            op==NVN_CMD_DEPTH_RANGES?(void *)s->depth_ranges:op==NVN_CMD_BIND_VATTR?(void *)s->attributes:(void *)s->streams;
        memcpy((uint8_t *)dst+(size_t)a.first*element,values,(size_t)a.count*element);
        if(op==NVN_CMD_VIEWPORTS)s->viewport_count=MAX(s->viewport_count,(unsigned)(a.first+a.count));
        if(op==NVN_CMD_SCISSORS)s->scissor_count=MAX(s->scissor_count,(unsigned)(a.first+a.count));return 1;
    }
    case NVN_CMD_BIND_STATE:{
        READ(nvn_cmd_state,p);size_t expected=0;void *dst=NULL;
        switch(p.kind){
        case NVN_STATE_BLEND:{if(p.size!=sizeof(nvn_blend_state))return 0;nvn_blend_state b=nvn_blend_snapshot(p.bytes);s->blends[b.target]=b;return 1;}
        case NVN_STATE_COLOR:dst=&s->color;expected=sizeof s->color;break;
        case NVN_STATE_CHANNEL:dst=&s->channel;expected=sizeof s->channel;break;
        case NVN_STATE_DEPTH:dst=&s->depth;expected=sizeof s->depth;break;
        case NVN_STATE_POLYGON:dst=&s->polygon;expected=sizeof s->polygon;break;
        case NVN_STATE_MULTISAMPLE:dst=&s->multisample;expected=sizeof s->multisample;break;
        default:return reject("multisample state");
        }
        if(p.size!=expected)return 0;memcpy(dst,p.bytes,expected);return 1;
    }
    case NVN_CMD_BIND_BUFFER:{
        nvn_cmd_buffers p;if(size<sizeof p)return 0;memcpy(&p,payload,sizeof p);
        if(p.kind<0||p.kind>2||p.stage<0||p.stage>=6||p.first<0||p.count<0||p.first>32||p.count>32-p.first||size-sizeof p!=(size_t)p.count*sizeof(NVNbufferRange))return 0;
        NVNbufferRange *dst=p.kind==NVN_BIND_VERTEX?s->vertex:p.kind==NVN_BIND_UNIFORM?s->uniforms[p.stage]:s->storage[p.stage];
        memcpy(dst+p.first,(const uint8_t *)payload+sizeof p,(size_t)p.count*sizeof *dst);return 1;
    }
    case NVN_CMD_BIND_PROGRAM:{
        READ(nvn_cmd_program,p);unsigned count=(unsigned)p.resource.words[1];if(count>6)return 0;
        /* NVN keeps compute and graphics bindings separate: binding a compute program
         * (stages=NVN_SHADER_STAGE_COMPUTE_BIT) leaves the current VS/FS untouched.
         * 真机 v0.6.15：×996 stages=32 candidates=0，每次都把图形着色器清空了。 */
        if(p.stages&NVN_SHADER_STAGE_COMPUTE_BIT){
            s.cs=nil;
            for(unsigned i=0;i<count;i++){
                nvn_shader_match match;const nvn_shader_ent *entry=nvn_shader_find_gpu(p.resource.words[2+i*2],&match);
                if(!entry){
                    NVN_LOG("NVN_SHADER_EXEC_MATCH_FAILED program=%llu index=%u stages=%llu candidates=%u matches=%u",
                        (unsigned long long)p.resource.words[15],i,(unsigned long long)p.stages,match.candidates,match.matches);
                    nvn_shader_capture_gpu(p.resource.words[2+i*2],p.resource.words[15],i);
                    continue;
                }
                if(entry->stage!=0)continue;
                s.cs=load_shader(e,entry,1);
                s->computeDevice=p.resource.words[0];
            }
            if(!(p.stages&NVN_SHADER_STAGE_ALL_GRAPHICS_BITS))return 1;
        }
        s->programDevice=p.resource.words[0];
        if(p.stages&1)s.vs=nil;if(p.stages&2)s.fs=nil;
        for(unsigned i=0;i<count;i++){
            nvn_shader_match match;const nvn_shader_ent *entry=nvn_shader_find_gpu(p.resource.words[2+i*2],&match);
            if(!entry){
                NVN_LOG("NVN_SHADER_EXEC_MATCH_FAILED program=%llu index=%u stages=%llu candidates=%u matches=%u",
                    (unsigned long long)p.resource.words[15],i,(unsigned long long)p.stages,match.candidates,match.matches);
                nvn_shader_capture_gpu(p.resource.words[2+i*2],p.resource.words[15],i);
                /* 程序匹配不上：已按 p.stages 清掉被替换的阶段，后续绘制在 prepare_draw 里逐条跳过 */
                continue;
            }
            if(entry->stage==0)continue;  /* compute stage handled above */
            unsigned stage=entry->stage==1?0:entry->stage==5?1:UINT_MAX;
            if(stage==UINT_MAX){s.vs=nil;s.fs=nil;skip_draw("geometry/tessellation shader");return 1;}
            if(!(p.stages&(1u<<stage)))continue;
            SMOMetalShader *shader=load_shader(e,entry,guest_depth_mode(s));if(!shader)return 0;
            if(stage==0)s.vs=shader;else s.fs=shader;
        }
        return 1;
    }
    case NVN_CMD_SET_POOL:{READ(nvn_cmd_pool,p);if(p.kind==0)s->texture_pool=p.pool;else if(p.kind==1)s->sampler_pool=p.pool;else return 0;return 1;}
    case NVN_CMD_BIND_HANDLES:{
        nvn_cmd_handles p;if(size<sizeof p)return 0;memcpy(&p,payload,sizeof p);
        if(p.kind<0||p.kind>=4||p.stage<0||p.stage>=6||p.first<0||p.first>128||p.count<0||p.count>128-p.first||size-sizeof p!=(size_t)p.count*8)return 0;
        memcpy(s->handles[p.kind][p.stage]+p.first,(const uint8_t *)payload+sizeof p,(size_t)p.count*8);return 1;
    }
    case NVN_CMD_BLEND_COLOR:if(size!=sizeof s->blend_color)return 0;memcpy(s->blend_color,payload,size);return 1;
    case NVN_CMD_SCRATCH:/* Register spilling is allocated by the Metal compiler/runtime. */return size==sizeof(nvn_cmd_scratch);
    case NVN_CMD_DISPATCH:{
        READ(nvn_cmd_dispatch,p);
        if(!p.groups[0]||!p.groups[1]||!p.groups[2])return 1;
        return dispatch_compute(e,p.groups,0)||skip_draw("compute dispatch (see preceding diagnostic)");
    }
    case NVN_CMD_DISPATCH_INDIRECT:{
        READ(nvn_cmd_dispatch_indirect,p);
        /* Group counts are read by the GPU (dispatchThreadgroupsWithIndirectBuffer); groups=NULL selects that path. */
        NSUInteger offset=0;id<MTLBuffer> buffer=nvn_metal_buffer(e,p.address,12,&offset);
        if(!buffer)return skip_draw("unmapped indirect dispatch buffer");
        return dispatch_compute(e,NULL,p.address)||skip_draw("compute dispatch (see preceding diagnostic)");
    }
    case NVN_CMD_DRAW:{
        READ(nvn_cmd_draw,p);if(p.count<0||p.first<0||p.instances<0||p.base_instance<0)return 0;if(!p.count||!p.instances)return 1;
        MTLPrimitiveType primitive;if(!primitive_type(p.primitive,&primitive))return skip_draw("primitive topology");
        int ready=prepare_draw(e);if(ready!=1)return ready==2 || skip_draw("draw state (see preceding diagnostic)");
        [e.render drawPrimitives:primitive vertexStart:p.first vertexCount:p.count instanceCount:p.instances baseInstance:p.base_instance];
        if(e.visibilityBuffer)[e.render setVisibilityResultMode:MTLVisibilityResultModeDisabled offset:0];
        mark_draw(s);return 1;
    }
    case NVN_CMD_DRAW_INDEXED:{
        READ(nvn_cmd_draw_indexed,p);if(p.count<0||p.instances<0||p.base_instance<0)return 0;if(!p.count||!p.instances)return 1;
        MTLPrimitiveType primitive;if(!primitive_type(p.primitive,&primitive))return skip_draw("primitive topology");
        if(p.index_type!=NVN_INDEX_TYPE_UNSIGNED_SHORT&&p.index_type!=NVN_INDEX_TYPE_UNSIGNED_INT)return skip_draw("8-bit indices");
        uint64_t stride=p.index_type==NVN_INDEX_TYPE_UNSIGNED_SHORT?2:4;if(p.address%stride)return 0;
        NSUInteger offset=0;id<MTLBuffer> buffer=nvn_metal_buffer(e,p.address,(uint64_t)p.count*stride,&offset);if(!buffer)return skip_draw("unmapped index buffer");
        int ready=prepare_draw(e);if(ready!=1)return ready==2 || skip_draw("draw state (see preceding diagnostic)");
        [e.render drawIndexedPrimitives:primitive indexCount:p.count indexType:stride==2?MTLIndexTypeUInt16:MTLIndexTypeUInt32
            indexBuffer:buffer indexBufferOffset:offset instanceCount:p.instances baseVertex:p.base_vertex baseInstance:p.base_instance];
        if(e.visibilityBuffer)[e.render setVisibilityResultMode:MTLVisibilityResultModeDisabled offset:0];
        mark_draw(s);return 1;
    }
    default:return reject("render opcode");
    }
#undef READ
}
