/* Actual guest submission backend. The separate nvn_mtl.m remains an offline
 * shader/rendering probe and is not used as evidence of game rendering. */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "nvn_cmd.h"
#include "nvn_gpu.h"
#include "nvn_host.h"
#include "nvn_state.h"
#include "nvn_cmd_render.h"
#import "nvn_metal_private.h"
#import "nvn_metal_resources.h"
#include <pthread.h>
#include <stdatomic.h>
#include <unistd.h>
#include <dispatch/dispatch.h>

static id<MTLDevice> device;
static id<MTLCommandQueue> metal_queue;
static NSObject *render_state;
static dispatch_queue_t encoding_worker;
id<MTLDevice> nvn_metal_device(void) { return device; }
static uint64_t submitted;
static _Atomic uint64_t completed;
static _Atomic uint64_t first_failure;
static _Atomic uint64_t offscreen_frames;
static NSMutableDictionary<NSString *,NSNumber *> *presented_generations;
static pthread_mutex_t sink_lock=PTHREAD_MUTEX_INITIALIZER;
static void (^frame_sink)(id<MTLTexture>,int,uint64_t);
static void (^frame_pacer)(int);
void nvn_metal_set_frame_pacer(void (^pacer)(int)) {
    pthread_mutex_lock(&sink_lock);frame_pacer=[pacer copy];pthread_mutex_unlock(&sink_lock);
}
void nvn_metal_set_frame_sink(void (^sink)(id<MTLTexture>,int,uint64_t)) {
    pthread_mutex_lock(&sink_lock);frame_sink=[sink copy];pthread_mutex_unlock(&sink_lock);
}
uint64_t nvn_metal_offscreen_frames(void) { return atomic_load(&offscreen_frames); }
typedef struct completion_node {
    uint64_t sequence;
    int done;
    void *delivery;
    struct completion_node *next;
} completion_node;
static completion_node *completion_head, *completion_tail;
static pthread_mutex_t completion_lock=PTHREAD_MUTEX_INITIALIZER;

@implementation SMOGuestEncoder
@end

id<MTLBuffer> nvn_metal_buffer(SMOGuestEncoder *e, uint64_t address,
                                uint64_t size, NSUInteger *offset) {
    uint64_t base, length;
    if (!nvn_st_pool_range(address, size, &base, &length)) {
        NVN_LOG("NVN_GPU_INVALID_RANGE address=0x%llx size=%llu",
                (unsigned long long)address, (unsigned long long)size);
        return nil;
    }
    uint64_t page = (uint64_t)sysconf(_SC_PAGESIZE);
    uint64_t aligned = base & ~(page - 1);
    if (length > UINT64_MAX - base || base + length > UINT64_MAX - (page - 1)) return nil;
    uint64_t bytes = ((base + length + page - 1) & ~(page - 1)) - aligned;
    if (!bytes || bytes > device.maxBufferLength) return nil;
    NSString *key = [NSString stringWithFormat:@"%llx:%llx",
                    (unsigned long long)aligned, (unsigned long long)bytes];
    id<MTLBuffer> buffer = e.buffers[key];
    if (!buffer) {
        buffer = [device newBufferWithBytesNoCopy:(void *)(uintptr_t)aligned
                                          length:(NSUInteger)bytes
                                         options:MTLResourceStorageModeShared
                                     deallocator:nil];
        if (!buffer) return nil;
        e.buffers[key] = buffer;
    }
    *offset = (NSUInteger)(address - aligned);
    return buffer;
}
static id<MTLBlitCommandEncoder> blit_for(SMOGuestEncoder *e) {
    nvn_metal_render_end(e);
    if (!e.blit) e.blit = [e.command blitCommandEncoder];
    return e.blit;
}
static int encode(void *context, uint32_t op, const void *payload, size_t size) {
    SMOGuestEncoder *e = (__bridge SMOGuestEncoder *)context;
    if (op == NVN_CMD_SET_RT) e.skipPass = 0;          /* 新目标：重新尝试 */
    else if (e.skipPass && op >= NVN_CMD_SET_RT) return 1;  /* 本遍已放弃：丢掉这条渲染命令 */
    if(op==NVN_CMD_UNSUPPORTED){
        if(size!=sizeof(nvn_cmd_missing))return 0;
        nvn_cmd_missing missing;memcpy(&missing,payload,sizeof missing);
        if(!nvn_cmd_missing_is_skippable(missing.name))return 0;
        return 1;
    }
    if (op == NVN_CMD_BARRIER) {
        if (size != 8) return 0;
        [e.blit endEncoding]; e.blit = nil;
        nvn_metal_render_end(e);
        return 1;
    }
    if(op==NVN_CMD_COUNTER){
        nvn_cmd_counter c;if(size!=sizeof c)return 0;memcpy(&c,payload,sizeof c);
        if(c.type!=0 && c.type!=16){NVN_LOG("NVN_GPU_COUNTER_UNSUPPORTED type=%llu",(unsigned long long)c.type);return 0;}
        uint64_t base,length;if(!nvn_st_pool_range(c.address,16,&base,&length))return 0;
        /* Conservative boundary: drain actual encoded GPU work and use its
         * GPU clock result. This serializes timestamp reports until counter
         * sample buffers are implemented; it never substitutes a CPU clock. */
        [e.blit endEncoding];e.blit=nil;nvn_metal_render_end(e);
        /* Empty command buffers need not have a GPU timing interval. An
         * internal ordered blit gives this boundary an actual GPU clock sample. */
        id<MTLBuffer> marker=[device newBufferWithLength:4 options:MTLResourceStorageModeShared];
        id<MTLBlitCommandEncoder> clock=[e.command blitCommandEncoder];
        if(!marker||!clock){[clock endEncoding];return 0;}
        [clock fillBuffer:marker range:NSMakeRange(0,4) value:0];[clock endEncoding];
        [e.command commit];[e.command waitUntilCompleted];
        if(e.command.status!=MTLCommandBufferStatusCompleted)return 0;
        double gpu=e.command.GPUEndTime;
        if(!(gpu>0) || gpu>(double)UINT64_MAX/1e9)return 0;
        NVNcounterData value={0,(uint64_t)(gpu*1e9)};
        memcpy((void *)(uintptr_t)c.address,&value,sizeof value);
        e.command=[metal_queue commandBuffer];return e.command!=nil;
    }
    if(op>=NVN_CMD_SET_RT){
        int ok=nvn_metal_render_encode(e,op,payload,size);
        if(!ok)NVN_LOG("NVN_GPU_RENDER_ENCODING_FAILED op=%u size=%zu",op,size);
        return ok;
    }
    if (op == NVN_CMD_COPY_BUFFER) {
        nvn_cmd_copy c;
        if (size != sizeof c) return 0;
        memcpy(&c, payload, sizeof c);
        if (!c.size) return 1;
        if ((c.src | c.dst | c.size) & 3) return 0;
        if ((c.src <= c.dst && c.dst - c.src < c.size) ||
            (c.dst < c.src && c.src - c.dst < c.size)) return 0;
        NSUInteger src_offset, dst_offset;
        id<MTLBuffer> src = nvn_metal_buffer(e,c.src,c.size,&src_offset);
        id<MTLBuffer> dst = nvn_metal_buffer(e,c.dst,c.size,&dst_offset);
        id<MTLBlitCommandEncoder> blit = blit_for(e);
        if (!src || !dst || !blit) return 0;
        [blit copyFromBuffer:src sourceOffset:src_offset toBuffer:dst
          destinationOffset:dst_offset size:(NSUInteger)c.size];
        return 1;
    }
    uint64_t address, bytes;
    id<MTLBuffer> staging;
    if (op == NVN_CMD_UPDATE_BUFFER) {
        nvn_cmd_update u;
        if (size < sizeof u) return 0;
        memcpy(&u,payload,sizeof u);
        if (u.size > size - sizeof u) return 0;
        address=u.dst; bytes=u.size;
        if (!bytes) return 1;
        if (bytes > device.maxBufferLength || ((address | bytes) & 3)) return 0;
        staging = [device newBufferWithBytes:(const uint8_t *)payload + sizeof u
                                      length:(NSUInteger)bytes options:MTLResourceStorageModeShared];
    } else if (op == NVN_CMD_CLEAR_BUFFER) {
        nvn_cmd_clear c;
        if (size != sizeof c) return 0;
        memcpy(&c,payload,sizeof c);
        address=c.dst; bytes=c.size;
        if (!bytes) return 1;
        if (bytes > device.maxBufferLength || ((address | bytes) & 3)) return 0;
        staging = [device newBufferWithLength:(NSUInteger)bytes options:MTLResourceStorageModeShared];
        if (staging) {
            uint32_t *p=staging.contents;
            for (uint64_t i=0;i<bytes/4;++i) p[i]=c.value;
        }
    } else {
        NVN_LOG("NVN_GPU_UNSUPPORTED_OPCODE op=%u",op);
        return 0;
    }
    NSUInteger offset;
    id<MTLBuffer> dst=nvn_metal_buffer(e,address,bytes,&offset);
    id<MTLBlitCommandEncoder> blit=blit_for(e);
    if (!staging || !dst || !blit) return 0;
    [blit copyFromBuffer:staging sourceOffset:0 toBuffer:dst destinationOffset:offset size:(NSUInteger)bytes];
    return 1;
}
static uint64_t commit_command(id<MTLCommandBuffer> command,void (^delivery)(void)) {
        uint64_t sequence=submitted+1;
        completion_node *node=calloc(1,sizeof *node);
        if (!node) return 0;
        submitted=sequence;
        node->sequence=sequence;
        if(delivery)node->delivery=(void *)CFBridgingRetain([delivery copy]);
        pthread_mutex_lock(&completion_lock);
        if (completion_tail) completion_tail->next=node;
        else completion_head=node;
        completion_tail=node;
        pthread_mutex_unlock(&completion_lock);
        command.label=[NSString stringWithFormat:@"SMO guest submit %llu",(unsigned long long)sequence];
        [command addCompletedHandler:^(id<MTLCommandBuffer> command) {
            NSMutableArray *deliveries=[NSMutableArray new];
            pthread_mutex_lock(&completion_lock);
            if (command.status != MTLCommandBufferStatusCompleted) {
                uint64_t old=atomic_load(&first_failure);
                while ((!old || sequence<old) && !atomic_compare_exchange_weak(&first_failure,&old,sequence)) {}
                NVN_LOG("NVN_GPU_ERROR sequence=%llu domain=%s code=%ld",(unsigned long long)sequence,
                        command.error.domain.UTF8String ?: "unknown",(long)command.error.code);
            }
            node->done=1;
            /* Handlers may run on different host threads. Publish only a
             * contiguous prefix, so a later success cannot hide an error in
             * an earlier submission whose handler has not run yet. */
            while (completion_head && completion_head->done) {
                completion_node *head=completion_head;
                atomic_store(&completed,head->sequence);
                completion_head=head->next;
                if(head->delivery){
                    id action=CFBridgingRelease(head->delivery);
                    uint64_t failure=atomic_load(&first_failure);
                    if(!failure || head->sequence<failure)[deliveries addObject:action];
                }
                free(head);
            }
            if (!completion_head) completion_tail=NULL;
            pthread_mutex_unlock(&completion_lock);
            for(void (^action)(void) in deliveries)action();
            if (sequence==1 || sequence%60==0)
                NVN_LOG("NVN_GPU_COMPLETED sequence=%llu status=%ld",(unsigned long long)sequence,(long)command.status);
        }];

        [command commit];
        if(sequence==1 || sequence%60==0)
            NVN_LOG("NVN_GPU_SUBMITTED sequence=%llu",(unsigned long long)sequence);
        return sequence;
}
static uint64_t submit_on_worker(int count, const uint64_t *handles) {
    @autoreleasepool {
        SMOGuestEncoder *e=[SMOGuestEncoder new];
        e.device=device;e.renderState=render_state;
        e.command=[metal_queue commandBuffer];
        e.buffers=[NSMutableDictionary new];
        if (!e.command) return 0;
        for (int i=0;i<count;++i) {
            if (!nvn_cmd_walk(handles[i],encode,(__bridge void *)e)) {
                [e.blit endEncoding];
                nvn_metal_render_end(e);
                /* 降级：跳过这一条命令缓冲继续提交。以前这里 return 0 → 上层 NVN_DIE → 闪退；
                 * 而失败往往只是某遍渲染的附件在场景切换时被重建过（一帧缺画面，不该杀进程）。 */
                static _Atomic unsigned failed;
                unsigned k=atomic_fetch_add(&failed,1);
                if(k<16)NVN_LOG("NVN_GPU_ENCODING_FAILED handle_index=%d（降级：跳过该命令缓冲，继续提交）",i);
            }
        }
        [e.blit endEncoding]; e.blit=nil;
        nvn_metal_render_end(e);
        return commit_command(e.command,nil);
    }
}
static uint64_t submit(int count,const uint64_t *handles) {
    /* Guest NVN callbacks run on guest-provided stacks, sometimes only 16 KiB.
     * Metal compilation/commit enters CoreFoundation and needs a native stack.
     * dispatch_sync may execute inline on the caller, so use async + a wait.
     * The caller keeps command memory alive until encoding has completed. */
    __block uint64_t sequence=0;
    dispatch_semaphore_t finished=dispatch_semaphore_create(0);
    dispatch_async(encoding_worker, ^{
        sequence=submit_on_worker(count,handles);
        dispatch_semaphore_signal(finished);
    });
    dispatch_semaphore_wait(finished,DISPATCH_TIME_FOREVER);
    return sequence;
}
static int poll(uint64_t sequence) {
    uint64_t done=atomic_load(&completed);
    uint64_t failed=atomic_load(&first_failure);
    if (failed && sequence>=failed) return -1;
    return done>=sequence;
}
/* Bounded private images use a simple lossless format, with no dependency on
 * UIKit/ImageIO in the headless runner. Never put these in public artifacts. */
static void capture_frame(id<MTLTexture> texture,uint64_t ordinal) {
    const char *directory=getenv("SMO_FRAME_CAPTURE_DIR");
    if(!directory || texture.width*texture.height>4194304)return;
    static pthread_mutex_t capture_lock=PTHREAD_MUTEX_INITIALIZER;
    static uint64_t latest;
    if(ordinal<=2)pthread_mutex_lock(&capture_lock);
    else if(pthread_mutex_trylock(&capture_lock))return;
    if(ordinal>2 && ordinal<=latest){pthread_mutex_unlock(&capture_lock);return;}
    @autoreleasepool {
        NSUInteger width=texture.width,height=texture.height;
        NSMutableData *rgba=[NSMutableData dataWithLength:width*height*4];
        [texture getBytes:rgba.mutableBytes bytesPerRow:width*4
            fromRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0];
        NSString *header=[NSString stringWithFormat:@"P6\n%lu %lu\n255\n",(unsigned long)width,(unsigned long)height];
        NSMutableData *ppm=[[header dataUsingEncoding:NSASCIIStringEncoding] mutableCopy];
        NSUInteger start=ppm.length;[ppm increaseLengthBy:width*height*3];
        const uint8_t *src=rgba.bytes;uint8_t *dst=(uint8_t *)ppm.mutableBytes+start;
        BOOL bgra=texture.pixelFormat==MTLPixelFormatBGRA8Unorm || texture.pixelFormat==MTLPixelFormatBGRA8Unorm_sRGB;
        for(NSUInteger i=0;i<width*height;i++){
            dst[i*3]=src[i*4+(bgra?2:0)];dst[i*3+1]=src[i*4+1];dst[i*3+2]=src[i*4+(bgra?0:2)];
        }
        NSString *root=[NSString stringWithUTF8String:directory];
        [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *name=ordinal<=2?[NSString stringWithFormat:@"frame-%llu.ppm",(unsigned long long)ordinal]:@"frame-latest.ppm";
        NSString *path=[root stringByAppendingPathComponent:name];
        if([ppm writeToFile:path atomically:YES]){
            if(ordinal>2){
                static unsigned recent;
                [ppm writeToFile:[root stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"frame-recent-%u.ppm",recent++%6]] atomically:YES];
                latest=ordinal;
            }
            NVN_LOG("NVN_GPU_FRAME_CAPTURE ordinal=%llu width=%lu height=%lu",(unsigned long long)ordinal,(unsigned long)width,(unsigned long)height);
        }
    }
    pthread_mutex_unlock(&capture_lock);
}
static uint64_t present_on_worker(const nvn_present_request *request) {
    @autoreleasepool {
        pthread_mutex_lock(&sink_lock);void (^pacer)(int)=frame_pacer;pthread_mutex_unlock(&sink_lock);
        if(pacer)pacer(request->interval);
        id<MTLTexture> source=nvn_metal_texture(device,&request->texture,NULL,0);
        if(!source || source.textureType!=MTLTextureType2D || source.sampleCount!=1 || source.arrayLength!=1){
            NVN_LOG("NVN_GPU_PRESENT_UNSUPPORTED texture layout");return 0;
        }
        MTLPixelFormat format=source.pixelFormat;
        if(format!=MTLPixelFormatRGBA8Unorm && format!=MTLPixelFormatRGBA8Unorm_sRGB &&
           format!=MTLPixelFormatBGRA8Unorm && format!=MTLPixelFormatBGRA8Unorm_sRGB){
            NVN_LOG("NVN_GPU_PRESENT_UNSUPPORTED format=%lu",(unsigned long)format);return 0;
        }
        int32_t x=request->crop[0],y=request->crop[1],w=request->crop[2],h=request->crop[3];
        if(!w && !h){x=y=0;w=(int32_t)source.width;h=(int32_t)source.height;}
        if(x<0 || y<0 || w<=0 || h<=0 || (uint64_t)x+w>source.width || (uint64_t)y+h>source.height)return 0;
        /* An immutable snapshot releases window ownership at GPU completion.
         * Drawable acquisition must never block this guest submission worker. */
        MTLTextureDescriptor *desc=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:w height:h mipmapped:NO];
        desc.storageMode=MTLStorageModeShared;desc.usage=MTLTextureUsageShaderRead;
        id<MTLTexture> output=[device newTextureWithDescriptor:desc];
        id<MTLCommandBuffer> command=[metal_queue commandBuffer];
        if(!output || !command)return 0;
        id<MTLBlitCommandEncoder> blit=[command blitCommandEncoder];if(!blit)return 0;
        [blit copyFromTexture:source sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(x,y,0)
            sourceSize:MTLSizeMake(w,h,1) toTexture:output destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0,0,0)];
        [blit endEncoding];
        NSString *key=[NSString stringWithFormat:@"%llx:%llu",(unsigned long long)request->texture.object,
            (unsigned long long)request->texture.words[15]];
        uint64_t generation=nvn_metal_render_generation(render_state,&request->texture);
        BOOL fresh=generation && generation>presented_generations[key].unsignedLongLongValue;
        static uint64_t presentations;uint64_t ordinal=++presentations;
        int interval=request->interval;
        uint64_t sequence=commit_command(command, ^{
            BOOL capture=ordinal==1 || ordinal==2;
            if(fresh){
                uint64_t count=atomic_fetch_add(&offscreen_frames,1)+1;
                if(count%60==0)capture=YES;
                if(count==1 || count%60==0)
                    NVN_LOG("GUEST_GPU_FRAME_COMPLETED count=%llu delivery=offscreen",(unsigned long long)count);
            }
            pthread_mutex_lock(&sink_lock);
            void (^sink)(id<MTLTexture>,int,uint64_t)=frame_sink;
            pthread_mutex_unlock(&sink_lock);
            if(sink)sink(output,interval,ordinal);
            if(capture)capture_frame(output,ordinal);
        });
        if(sequence && fresh)presented_generations[key]=@(generation);
        return sequence;
    }
}
static uint64_t present(const nvn_present_request *request) {
    nvn_present_request copy=*request;
    __block uint64_t sequence=0;
    dispatch_semaphore_t finished=dispatch_semaphore_create(0);
    dispatch_async(encoding_worker, ^{
        sequence=present_on_worker(&copy);
        dispatch_semaphore_signal(finished);
    });
    dispatch_semaphore_wait(finished,DISPATCH_TIME_FOREVER);
    return sequence;
}
static void initialize(void) {
    encoding_worker=dispatch_queue_create("smo.gpu.encoding",DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t finished=dispatch_semaphore_create(0);
    dispatch_async(encoding_worker, ^{
      @autoreleasepool {
        device=MTLCreateSystemDefaultDevice();
        metal_queue=[device newCommandQueue];
        if (!metal_queue) { NVN_LOG("NVN_GPU_UNAVAILABLE: Metal device/queue unavailable"); }
        else {
            render_state=nvn_metal_render_state();
            presented_generations=[NSMutableDictionary new];
            static const nvn_gpu_backend backend={submit,poll,present};
            nvn_gpu_install_backend(&backend);
            NVN_LOG("NVN_GPU_BACKEND device=%s worker=native",device.name.UTF8String);
        }
      }
      dispatch_semaphore_signal(finished);
    });
    dispatch_semaphore_wait(finished,DISPATCH_TIME_FOREVER);
}
void nvn_metal_runtime_init(void) {
    static pthread_once_t once=PTHREAD_ONCE_INIT;
    pthread_once(&once,initialize);
}
