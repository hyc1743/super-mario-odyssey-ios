/* Independently authored test shaders exercise the same guest command backend.
 * They are test inputs, never substitutes for a missing game shader. */
#import "../nvn_metal_private.h"
#import "../nvn_metal_resources.h"
#include "../nvn_host.h"
#include "../nvn_state.h"
#include "../nvn_shader.h"
#include "../nvn_gpu.h"
#include "../nvn_render_state.h"
#include <assert.h>
#include <unistd.h>
#include <pthread.h>
#define P(x) ((uint64_t)(uintptr_t)(x))
#define API(n,t) ((t)(uintptr_t)nvn_lookup("nvn" #n))
static uint64_t call(const char *name,void *obj,uint64_t a,uint64_t b,uint64_t c,uint64_t d,uint64_t f) {
    nvn_fn fn=nvn_lookup(name);assert(fn&&fn!=nvn_unimplemented&&!nvn_is_missing_command(fn));
    return fn(P(obj),a,b,c,d,f,0,0);
}
#define C(n,o,a,b,c,d,f) call("nvn" #n,o,a,b,c,d,f)
typedef struct { NVNqueue *queue;NVNsync *sync;uint64_t handle;NVNwindow *window;int index; } small_stack_submission;
static void *submit_small_stack(void *context) {
    small_stack_submission *s=context;
    C(QueueSubmitCommands,s->queue,1,P(&s->handle),0,0,0);
    C(QueuePresentTexture,s->queue,P(s->window),s->index,0,0,0);
    C(QueueFenceSync,s->queue,P(s->sync),0,0,0,0);
    return NULL;
}
static void write_shader(NSString *root,FILE *index,uint8_t *code,unsigned seed,int stage,NSString *source,NSArray *args,NSArray *inputs,NSString *depthClipSource) {
    for(unsigned i=0;i<256;i++)code[i]=(uint8_t)(i*13+seed);
    uint64_t key=nvn_shader_key(code,256);
    NSString *name=[NSString stringWithFormat:@"%016llx",(unsigned long long)key];
    fprintf(index,"%016llx\t%d\t%s.metal\t256\t%016llx\t%016llx\t%016llx\n",
        (unsigned long long)key,stage,name.UTF8String,(unsigned long long)nvn_shader_key(code,64),
        (unsigned long long)nvn_shader_key(code+0x50,256-0x50),(unsigned long long)nvn_shader_key(code+0x50,64));
    assert([source writeToFile:[root stringByAppendingPathComponent:[name stringByAppendingString:@".metal"]]
        atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
    NSMutableDictionary *bindings=[@{@"version":@1,@"key":name,@"stage":@(stage),@"entry":@"main0",@"argument_buffer":@0,
        @"arguments":args,@"unsupported_arguments":@[],@"vertex_inputs":inputs,@"constant_data":@"0000803e"} mutableCopy];
    if(depthClipSource){
        bindings[@"depth_clip_source"]=[name stringByAppendingString:@".clip.metal"];
        assert([depthClipSource writeToFile:[root stringByAppendingPathComponent:bindings[@"depth_clip_source"]]
            atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
    }
    NSData *data=[NSJSONSerialization dataWithJSONObject:bindings options:0 error:NULL];assert(data);
    assert([data writeToFile:[root stringByAppendingPathComponent:[name stringByAppendingString:@".bindings.json"]] atomically:YES]);
}
int main(void) {
    @autoreleasepool {
        size_t page=(size_t)sysconf(_SC_PAGESIZE);uint8_t *memory=NULL;assert(!posix_memalign((void **)&memory,page,page*9));memset(memory,0,page*9);
        NVNmemoryPool pool;NVNcommandBuffer cb;NVNqueue q;NVNqueueBuilder qb;NVNsync sync;
        NVNtexture target,target2,sample;NVNsampler sampler;NVNsamplerBuilder sb;NVNprogram program;NVNtexturePool tp;NVNsamplerPool sp;
        NVNwindow window;NVNwindowBuilder wb;
        nvn_st_ent *p=nvn_st_new(&pool,4);p->v[1]=P(memory);p->v[2]=page*9;
        nvn_st_ent *t=nvn_st_new(&target,12);uint64_t words[16]={0,16,16,1,1,37,16,1,1,P(&pool),page*3,64,0,0,0,1};memcpy(t->v,words,sizeof words);
        nvn_st_ent *t2=nvn_st_new(&target2,12);memcpy(t2->v,words,sizeof words);t2->v[10]=page*8;t2->v[15]=3;
        nvn_st_ent *st=nvn_st_new(&sample,12);words[1]=words[2]=1;words[10]=page*4;words[11]=32;words[15]=2;memcpy(st->v,words,sizeof words);
        memset(memory+page*4,255,4);
        float vertices[6]={-1,-1,3,-1,-1,3};uint16_t indices[3]={0,1,2};float color[4]={1,0,0,1};
        memcpy(memory+page*2,vertices,sizeof vertices);memcpy(memory+page*2+128,indices,sizeof indices);memcpy(memory+page*5,color,sizeof color);
        float storageFactor=4;memcpy(memory+page*5+64,&storageFactor,sizeof storageFactor);
        NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        assert([[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL]);
        setenv("SMO_SHADER_DIR",root.UTF8String,1);NSString *idx=[root stringByAppendingPathComponent:@"shaders.idx"];
        setenv("SMO_FRAME_CAPTURE_DIR",root.UTF8String,1);
        NSLock *deliveryLock=[NSLock new];
        NSMutableDictionary<NSNumber *,id<MTLTexture>> *delivered=[NSMutableDictionary new];
        nvn_metal_set_frame_sink(^(id<MTLTexture> texture,int interval,uint64_t ordinal){
            assert(interval==1);[deliveryLock lock];delivered[@(ordinal)]=texture;[deliveryLock unlock];
        });
        FILE *index=fopen(idx.fileSystemRepresentation,"wb");assert(index);
        NSString *vs=@"#include <metal_stdlib>\nusing namespace metal;\nstruct Input{float2 p[[attribute(0)]];};\nvertex float4 main0(Input v[[stage_in]]){return float4(v.p,-0.5,1);}\n";
        NSString *depthClipVS=@"#include <metal_stdlib>\nusing namespace metal;\nstruct Input{float2 p[[attribute(0)]];};\nvertex float4 main0(Input v[[stage_in]]){return float4(v.p,0.25,1);}\n";
        NSString *fs=@"#include <metal_stdlib>\nusing namespace metal;\nstruct S{float4 _m0;float4 _m1[8];float4 _m2;float4 _m3;int _m4;float4 _m5[73];};\nstruct A{constant float4 *color[[id(0)]];texture2d<float> image[[id(1)]];sampler smp[[id(2)]];constant float *scale[[id(3)]];device float *factor[[id(4)]];constant float4 *c1[[id(5)]];constant S *sup[[id(6)]];};\nfragment float4 main0(constant A &a[[buffer(0)]]){return (*a.color)*a.image.sample(a.smp,float2(0.5))*(*a.scale)*(*a.factor)*(*a.sup)._m5[0].x+a.c1[1].x;}\n";
        write_shader(root,index,memory+page*7,7,1,vs,@[],@[@{@"location":@0,@"type":@"vec2"}],depthClipVS);
        write_shader(root,index,memory+page*7+512,19,5,fs,@[
            @{@"id":@0,@"kind":@"cbuf",@"nvn_slot":@0},
            @{@"id":@1,@"kind":@"texture",@"nvn_slot":@0,@"array":@1,@"separate":@NO},
            @{@"id":@2,@"kind":@"sampler",@"nvn_slot":@0,@"array":@1,@"separate":@NO},
            @{@"id":@3,@"kind":@"constant"},@{@"id":@4,@"kind":@"sbuf",@"nvn_slot":@0},
            @{@"id":@5,@"kind":@"cbuf",@"slot":@1},@{@"id":@6,@"kind":@"support"}],@[],nil);
        fclose(index);nvn_shader_reset();assert(nvn_shader_load(idx.fileSystemRepresentation)==2);
        uint64_t guestDevice[8]={0};assert(nvn_st_new(guestDevice,1));
        C(ProgramInitialize,&program,P(guestDevice),0,0,0,0);nvn_shader_data shaders[2]={{P(memory+page*7),NULL},{P(memory+page*7+512),NULL}};
        assert(C(ProgramSetShaders,&program,2,P(shaders),0,0,0));
        C(SamplerBuilderSetDefaults,&sb,0,0,0,0,0);assert(C(SamplerInitialize,&sampler,P(&sb),0,0,0,0));
        assert(C(TexturePoolInitialize,&tp,P(&pool),page*6,16,0,0));assert(C(SamplerPoolInitialize,&sp,P(&pool),page*6+512,16,0,0));
        C(TexturePoolRegisterTexture,&tp,1,P(&sample),0,0,0);C(SamplerPoolRegisterSampler,&sp,1,P(&sampler),0,0,0);
        NVNvertexAttribState attribute;nvn_VertexAttribStateSetDefaults(&attribute);nvn_VertexAttribStateSetFormat(&attribute,NVN_FORMAT_RG32F,0);
        NVNvertexStreamState stream;nvn_VertexStreamStateSetDefaults(&stream);nvn_VertexStreamStateSetStride(&stream,8);
        assert(C(CommandBufferInitialize,&cb,0,0,0,0,0));C(CommandBufferAddCommandMemory,&cb,P(&pool),0,page*2,0,0);
        C(CommandBufferBeginRecording,&cb,0,0,0,0,0);const NVNtexture *targets[1]={&target};
        C(CommandBufferSetRenderTargets,&cb,1,P(targets),0,0,0);float clear[4]={0,0,1,1};C(CommandBufferClearColor,&cb,0,P(clear),15,0,0);
        C(CommandBufferSetViewport,&cb,0,0,16,16,0);C(CommandBufferSetScissor,&cb,4,4,8,8,0);
        C(CommandBufferBindVertexAttribState,&cb,1,P(&attribute),0,0,0);C(CommandBufferBindVertexStreamState,&cb,1,P(&stream),0,0,0);
        C(CommandBufferBindVertexBuffer,&cb,0,P(memory+page*2),sizeof vertices,0,0);
        C(CommandBufferBindUniformBuffer,&cb,1,0,P(memory+page*5),16,0);C(CommandBufferBindProgram,&cb,P(&program),3,0,0,0);
        C(CommandBufferBindStorageBuffer,&cb,1,0,P(memory+page*5+64),4,0);
        C(CommandBufferSetTexturePool,&cb,P(&tp),0,0,0,0);C(CommandBufferSetSamplerPool,&cb,P(&sp),0,0,0,0);
        C(CommandBufferBindTexture,&cb,1,0,1|UINT64_C(1)<<20,0,0);
        C(CommandBufferDrawElements,&cb,NVN_DRAW_PRIMITIVE_TRIANGLES,NVN_INDEX_TYPE_UNSIGNED_SHORT,3,P(memory+page*2+128),0);
        C(CommandBufferReportCounter,&cb,0,P(memory+page*5+128),0,0,0);
        uint64_t handle=C(CommandBufferEndRecording,&cb,0,0,0,0,0);
        C(QueueBuilderSetDefaults,&qb,0,0,0,0,0);assert(C(QueueInitialize,&q,P(&qb),0,0,0,0));assert(C(SyncInitialize,&sync,0,0,0,0,0));
        C(WindowBuilderSetDefaults,&wb,0,0,0,0,0);NVNtexture *windowTextures[2]={&target,&target2};
        C(WindowBuilderSetTextures,&wb,2,P(windowTextures),0,0,0);
        C(WindowBuilderSetNativeWindow,&wb,1,0,0,0,0);assert(C(WindowInitialize,&window,P(&wb),0,0,0,0));
        C(WindowSetCrop,&window,2,2,12,12,0);int acquired=-1;
        assert(!C(QueueAcquireTexture,&q,P(&window),P(&acquired),0,0,0)&&acquired==0);
        small_stack_submission submission={&q,&sync,handle,&window,acquired};
        pthread_attr_t attr;pthread_t thread;assert(!pthread_attr_init(&attr));
        size_t stack=16384;if(stack<PTHREAD_STACK_MIN)stack=PTHREAD_STACK_MIN;
        assert(!pthread_attr_setstacksize(&attr,stack));
        assert(!pthread_create(&thread,&attr,submit_small_stack,&submission));
        assert(!pthread_attr_destroy(&attr));assert(!pthread_join(thread,NULL));
        uint64_t wait=C(SyncWait,&sync,UINT64_C(5000000000),0,0,0,0);assert(wait<2);
        nvn_resource_snapshot snapshot;assert(nvn_resources_snapshot(&target,12,&snapshot));
        id<MTLTexture> tex=nvn_metal_texture(nvn_metal_device(),&snapshot,NULL,0);assert(tex);
        uint8_t pixels[16*16*4];[tex getBytes:pixels bytesPerRow:64 fromRegion:MTLRegionMake2D(0,0,16,16) mipmapLevel:0];
        for(int y=0;y<16;y++)for(int x=0;x<16;x++){
            uint8_t *pixel=pixels+(y*16+x)*4;int inside=x>=4&&x<12&&y>=4&&y<12;
            assert(pixel[0]==(inside?255:0)&&pixel[1]==0&&pixel[2]==(inside?0:255)&&pixel[3]==255);
        }
        NVNcounterData timestamp;memcpy(&timestamp,memory+page*5+128,sizeof timestamp);assert(timestamp.timestamp>0);
        assert(API(DeviceGetTimestampInNanoseconds,PFNNVNDEVICEGETTIMESTAMPINNANOSECONDSPROC)(NULL,&timestamp)==timestamp.timestamp);
        NSString *frame=[root stringByAppendingPathComponent:@"frame-1.ppm"];
        for(unsigned retry=0;retry<5000 && ![[NSFileManager defaultManager] fileExistsAtPath:frame];retry++)usleep(1000);
        NSData *image=[NSData dataWithContentsOfFile:frame];NSData *header=[@"P6\n12 12\n255\n" dataUsingEncoding:NSASCIIStringEncoding];
        assert(image.length==header.length+12*12*3 && !memcmp(image.bytes,header.bytes,header.length));
        const uint8_t *rgb=(const uint8_t *)image.bytes+header.length;
        for(int y=0;y<12;y++)for(int x=0;x<12;x++){
            BOOL inside=x>=2&&x<10&&y>=2&&y<10;const uint8_t *pixel=rgb+(y*12+x)*3;
            assert(pixel[0]==(inside?255:0)&&pixel[1]==0&&pixel[2]==(inside?0:255));
        }
        assert(nvn_metal_offscreen_frames()==1);
        /* Reuse/mutation of the guest source cannot alter the delivered frame. */
        [deliveryLock lock];id<MTLTexture> immutable=delivered[@1];[deliveryLock unlock];assert(immutable);
        uint8_t green[16*16*4];for(unsigned i=0;i<16*16;i++){green[i*4]=0;green[i*4+1]=255;green[i*4+2]=0;green[i*4+3]=255;}
        [tex replaceRegion:MTLRegionMake2D(0,0,16,16) mipmapLevel:0 withBytes:green bytesPerRow:64];
        uint8_t preserved[12*12*4];[immutable getBytes:preserved bytesPerRow:48 fromRegion:MTLRegionMake2D(0,0,12,12) mipmapLevel:0];
        for(unsigned i=0;i<12*12;i++)assert(!memcmp(preserved+i*4,rgb+i*3,3));
        /* A second request for the same unchanged draw cannot count as a new
         * game frame. It still copies actual pixels and completes on the GPU. */
        nvn_present_request repeat={snapshot,{2,2,12,12},1};
        uint64_t repeated=nvn_gpu_present_queue(&q,&repeat);assert(repeated);
        int status=0;for(unsigned retry=0;retry<5000 && !(status=nvn_gpu_poll(repeated));retry++)usleep(1000);assert(status==1);
        NSString *second=[root stringByAppendingPathComponent:@"frame-2.ppm"];
        for(unsigned retry=0;retry<5000 && ![[NSFileManager defaultManager] fileExistsAtPath:second];retry++)usleep(1000);
        NSData *secondImage=[NSData dataWithContentsOfFile:second];assert(secondImage.length==image.length);
        const uint8_t *secondRGB=(const uint8_t *)secondImage.bytes+header.length;
        for(unsigned i=0;i<12*12;i++)assert(secondRGB[i*3]==0&&secondRGB[i*3+1]==255&&secondRGB[i*3+2]==0);
        assert(nvn_metal_offscreen_frames()==1);nvn_metal_set_frame_sink(nil);
        /* The same bound program must change clip convention immediately when
         * the device changes, and pipeline caches must distinguish variants. */
        C(CommandBufferBeginRecording,&cb,0,0,0,0,0);
        C(CommandBufferSetScissor,&cb,0,0,16,16,0);C(CommandBufferClearColor,&cb,0,P(clear),15,0,0);
        C(CommandBufferSetScissor,&cb,4,4,8,8,0);
        C(CommandBufferDrawElements,&cb,NVN_DRAW_PRIMITIVE_TRIANGLES,NVN_INDEX_TYPE_UNSIGNED_SHORT,3,P(memory+page*2+128),0);
        uint64_t depthHandle=C(CommandBufferEndRecording,&cb,0,0,0,0,0);
        for(int mode=1;mode>=0;mode--){
            C(DeviceSetDepthMode,guestDevice,mode,0,0,0,0);
            C(QueueSubmitCommands,&q,1,P(&depthHandle),0,0,0);C(QueueFenceSync,&q,P(&sync),0,0,0,0);
            assert(C(SyncWait,&sync,UINT64_C(5000000000),0,0,0,0)<2);
            [tex getBytes:pixels bytesPerRow:64 fromRegion:MTLRegionMake2D(0,0,16,16) mipmapLevel:0];
            for(int y=0;y<16;y++)for(int x=0;x<16;x++){
                const uint8_t *pixel=pixels+(y*16+x)*4;int inside=!mode&&x>=4&&x<12&&y>=4&&y<12;
                assert(pixel[0]==(inside?255:0)&&pixel[1]==0&&pixel[2]==(inside?0:255)&&pixel[3]==255);
            }
        }
        /* 深度附件格式守卫（真机 v0.6.19 SIGABRT 回归）：RG11B10F 被游戏当深度目标绑定。
         * 以前任何非 Stencil8 格式都进 depthAttachmentPixelFormat → Metal 校验断言
         * 「not depth renderable」→ 进程被收走。守卫后：附件被丢、颜色照画。 */
        NVNtexture badDepth,goodDepth;
        uint64_t depthWords[16]={0,16,16,1,1,63,16,1,1,P(&pool),page*3+2048,64,0,0,0,5};
        nvn_st_ent *bd=nvn_st_new(&badDepth,12);memcpy(bd->v,depthWords,sizeof depthWords);
        depthWords[5]=52;depthWords[15]=6;
        nvn_st_ent *gd=nvn_st_new(&goodDepth,12);memcpy(gd->v,depthWords,sizeof depthWords);
        for(int depthCase=0;depthCase<2;depthCase++){
            NVNtexture *depthTexture=depthCase?&goodDepth:&badDepth;
            C(CommandBufferBeginRecording,&cb,0,0,0,0,0);
            C(CommandBufferSetRenderTargets,&cb,1,P(targets),0,P(depthTexture),0);
            C(CommandBufferSetViewport,&cb,0,0,16,16,0);C(CommandBufferSetScissor,&cb,0,0,16,16,0);
            C(CommandBufferClearColor,&cb,0,P(clear),15,0,0);
            if(depthCase){uint32_t bits;float half=0.5f;memcpy(&bits,&half,4);
                C(CommandBufferClearDepthStencil,&cb,(uint64_t)bits,1,0,0xff,0);}
            C(CommandBufferSetScissor,&cb,4,4,8,8,0);
            C(CommandBufferDrawElements,&cb,NVN_DRAW_PRIMITIVE_TRIANGLES,NVN_INDEX_TYPE_UNSIGNED_SHORT,3,P(memory+page*2+128),0);
            uint64_t guarded=C(CommandBufferEndRecording,&cb,0,0,0,0,0);
            C(QueueSubmitCommands,&q,1,P(&guarded),0,0,0);C(QueueFenceSync,&q,P(&sync),0,0,0,0);
            assert(C(SyncWait,&sync,UINT64_C(5000000000),0,0,0,0)<2);
            [tex getBytes:pixels bytesPerRow:64 fromRegion:MTLRegionMake2D(0,0,16,16) mipmapLevel:0];
            for(int y=0;y<16;y++)for(int x=0;x<16;x++){
                uint8_t *pixel=pixels+(y*16+x)*4;int inside=x>=4&&x<12&&y>=4&&y<12;
                assert(pixel[0]==(inside?255:0)&&pixel[1]==0&&pixel[2]==(inside?0:255)&&pixel[3]==255);
            }
        }
        C(WindowFinalize,&window,0,0,0,0,0);
        C(QueueFinalize,&q,0,0,0,0,0);C(SyncFinalize,&sync,0,0,0,0,0);C(CommandBufferFinalize,&cb,0,0,0,0,0);
        C(TexturePoolFinalize,&tp,0,0,0,0,0);C(SamplerPoolFinalize,&sp,0,0,0,0,0);
        nvn_metal_resources_reset();nvn_shader_reset();nvn_st_reset();free(memory);
        assert([[NSFileManager defaultManager] removeItemAtPath:root error:NULL]);
        puts("METAL_RENDER_PASS: guest indexed draw, shader bindings, scissor, GPU timestamp/fence, cropped window snapshot on 16KiB stack, stale-frame exclusion and non-depth depth-target guard");
    }
    return 0;
}
