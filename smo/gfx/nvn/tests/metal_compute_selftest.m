/* Guest compute path end to end on a real Metal device: program bind → exact
 * shader match (compute has no SPH) → uniform/storage/driver-bank bindings →
 * direct and indirect DispatchCompute → GPU result readback.
 * The kernel is an independently authored test input, never a game shader. */
#import "../nvn_metal_private.h"
#import "../nvn_metal_resources.h"
#include "../nvn_host.h"
#include "../nvn_state.h"
#include "../nvn_shader.h"
#include "../nvn_gpu.h"
#include <assert.h>
#include <unistd.h>
#define P(x) ((uint64_t)(uintptr_t)(x))
static uint64_t call(const char *name,void *obj,uint64_t a,uint64_t b,uint64_t c,uint64_t d,uint64_t f) {
    nvn_fn fn=nvn_lookup(name);assert(fn&&fn!=nvn_unimplemented&&!nvn_is_missing_command(fn));
    return fn(P(obj),a,b,c,d,f,0,0);
}
#define C(n,o,a,b,c,d,f) call("nvn" #n,o,a,b,c,d,f)

/* out[i] = in[i] * scale + groups_x, for i < count. Reads the dispatch grid from the
 * driver bank (c0 + 0x200) and the storage address table (c0 + 0x310) just to prove
 * the runtime fills them; lane id comes from thread_index_in_simdgroup like the
 * translated game kernels. */
static NSString *const kernelSource=@
    "#include <metal_stdlib>\nusing namespace metal;\n"
    "struct A{constant float4 *cp_c3[[id(0)]];device float *cp_s0[[id(1)]];device float *cp_s1[[id(2)]];constant uint4 *cp_c0[[id(3)]];};\n"
    "kernel void main0(constant A &a[[buffer(0)]],uint3 g[[threadgroup_position_in_grid]],uint lane[[thread_index_in_simdgroup]]){\n"
    "  uint i=g.x*32u+lane; uint count=as_type<uint>(a.cp_c3[0].x); if(i>=count)return;\n"
    "  uint groups=a.cp_c0[0x200/16].x; uint has_in=a.cp_c0[0x310/16].z;\n"
    "  a.cp_s1[i]=a.cp_s0[i]*a.cp_c3[0].y+float(groups)+(has_in?0.0f:1000.0f);\n"
    "}\n";

int main(void) {
    @autoreleasepool {
        size_t page=(size_t)sysconf(_SC_PAGESIZE);uint8_t *memory=NULL;
        assert(!posix_memalign((void **)&memory,page,page*8));memset(memory,0,page*8);
        NVNmemoryPool pool;NVNcommandBuffer cb;NVNqueue q;NVNqueueBuilder qb;NVNsync sync;NVNprogram program;
        nvn_st_ent *p=nvn_st_new(&pool,4);p->v[1]=P(memory);p->v[2]=page*8;
        NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        assert([[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL]);
        setenv("SMO_SHADER_DIR",root.UTF8String,1);
        /* Compute code has no SPH: the index's code-only columns equal the full span. */
        uint8_t *code=memory+page*4;for(unsigned i=0;i<192;i++)code[i]=(uint8_t)(i*29+3);
        uint64_t key=nvn_shader_key(code,192),prefix=nvn_shader_key(code,64);
        NSString *name=[NSString stringWithFormat:@"%016llx",(unsigned long long)key];
        NSString *idx=[root stringByAppendingPathComponent:@"shaders.idx"];
        FILE *index=fopen(idx.fileSystemRepresentation,"wb");assert(index);
        fprintf(index,"%016llx\t0\t%s.metal\t192\t%016llx\t%016llx\t%016llx\n",(unsigned long long)key,name.UTF8String,
            (unsigned long long)prefix,(unsigned long long)key,(unsigned long long)prefix);
        fclose(index);
        assert([kernelSource writeToFile:[root stringByAppendingPathComponent:[name stringByAppendingString:@".metal"]]
            atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        NSDictionary *bindings=@{@"version":@1,@"key":name,@"stage":@0,@"entry":@"main0",@"argument_buffer":@0,
            @"threadgroup_size":@[@32,@1,@1],@"vertex_inputs":@[],@"unsupported_arguments":@[],
            @"arguments":@[@{@"id":@0,@"kind":@"cbuf",@"nvn_slot":@0},@{@"id":@1,@"kind":@"sbuf",@"nvn_slot":@0},
                           @{@"id":@2,@"kind":@"sbuf",@"nvn_slot":@1},@{@"id":@3,@"kind":@"driver"}]};
        NSData *json=[NSJSONSerialization dataWithJSONObject:bindings options:0 error:NULL];assert(json);
        assert([json writeToFile:[root stringByAppendingPathComponent:[name stringByAppendingString:@".bindings.json"]] atomically:YES]);
        nvn_shader_reset();assert(nvn_shader_load(idx.fileSystemRepresentation)==1);

        enum { COUNT=100 };
        float *input=(float *)(memory+page*1),*output=(float *)(memory+page*2);
        for(unsigned i=0;i<COUNT;i++){input[i]=(float)i;output[i]=-1;}
        output[COUNT]=-7;  /* first element past count must stay untouched */
        uint32_t count=COUNT;float scale=2;memcpy(memory+page*3,&count,4);memcpy(memory+page*3+4,&scale,4);
        uint32_t indirect[3]={4,1,1};memcpy(memory+page*3+256,indirect,sizeof indirect);

        uint64_t device[8]={0};assert(nvn_st_new(device,1));
        C(ProgramInitialize,&program,P(device),0,0,0,0);
        nvn_shader_data stage={P(code),NULL};assert(C(ProgramSetShaders,&program,1,P(&stage),0,0,0));
        assert(C(CommandBufferInitialize,&cb,0,0,0,0,0));C(CommandBufferAddCommandMemory,&cb,P(&pool),page*6,page*2,0,0);
        C(CommandBufferBeginRecording,&cb,0,0,0,0,0);
        C(CommandBufferBindProgram,&cb,P(&program),NVN_SHADER_STAGE_COMPUTE_BIT,0,0,0);
        C(CommandBufferBindUniformBuffer,&cb,NVN_SHADER_STAGE_COMPUTE,0,P(memory+page*3),16,0);
        C(CommandBufferBindStorageBuffer,&cb,NVN_SHADER_STAGE_COMPUTE,0,P(input),COUNT*4,0);
        C(CommandBufferBindStorageBuffer,&cb,NVN_SHADER_STAGE_COMPUTE,1,P(output),(COUNT+1)*4,0);
        C(CommandBufferDispatchCompute,&cb,4,1,1,0,0);   /* 4 groups × 32 lanes ≥ 100 */
        uint64_t direct=C(CommandBufferEndRecording,&cb,0,0,0,0,0);

        C(QueueBuilderSetDefaults,&qb,0,0,0,0,0);assert(C(QueueInitialize,&q,P(&qb),0,0,0,0));assert(C(SyncInitialize,&sync,0,0,0,0,0));
        C(QueueSubmitCommands,&q,1,P(&direct),0,0,0);C(QueueFenceSync,&q,P(&sync),0,0,0,0);
        assert(C(SyncWait,&sync,UINT64_C(5000000000),0,0,0,0)<2);
        for(unsigned i=0;i<COUNT;i++)assert(output[i]==(float)i*2+4);
        assert(output[COUNT]==-7);

        /* Indirect: group counts read from GPU memory, and c0 + 0x200 must see them too. */
        for(unsigned i=0;i<COUNT;i++)output[i]=-1;
        indirect[0]=4;memcpy(memory+page*3+256,indirect,sizeof indirect);
        C(CommandBufferBeginRecording,&cb,0,0,0,0,0);
        C(CommandBufferBindProgram,&cb,P(&program),NVN_SHADER_STAGE_COMPUTE_BIT,0,0,0);
        C(CommandBufferBindUniformBuffer,&cb,NVN_SHADER_STAGE_COMPUTE,0,P(memory+page*3),16,0);
        C(CommandBufferBindStorageBuffer,&cb,NVN_SHADER_STAGE_COMPUTE,0,P(input),COUNT*4,0);
        C(CommandBufferBindStorageBuffer,&cb,NVN_SHADER_STAGE_COMPUTE,1,P(output),(COUNT+1)*4,0);
        C(CommandBufferDispatchComputeIndirect,&cb,P(memory+page*3+256),0,0,0,0);
        uint64_t viaIndirect=C(CommandBufferEndRecording,&cb,0,0,0,0,0);
        C(QueueSubmitCommands,&q,1,P(&viaIndirect),0,0,0);C(QueueFenceSync,&q,P(&sync),0,0,0,0);
        assert(C(SyncWait,&sync,UINT64_C(5000000000),0,0,0,0)<2);
        for(unsigned i=0;i<COUNT;i++)assert(output[i]==(float)i*2+4);

        /* An unmatched compute program must not break the submission (dispatch skipped). */
        uint8_t other[192];memcpy(other,code,sizeof other);other[100]^=1;memcpy(memory+page*5,other,sizeof other);
        NVNprogram unknown;C(ProgramInitialize,&unknown,P(device),0,0,0,0);
        nvn_shader_data unknownStage={P(memory+page*5),NULL};assert(C(ProgramSetShaders,&unknown,1,P(&unknownStage),0,0,0));
        for(unsigned i=0;i<COUNT;i++)output[i]=-1;
        C(CommandBufferBeginRecording,&cb,0,0,0,0,0);
        C(CommandBufferBindProgram,&cb,P(&unknown),NVN_SHADER_STAGE_COMPUTE_BIT,0,0,0);
        C(CommandBufferDispatchCompute,&cb,4,1,1,0,0);
        uint64_t skipped=C(CommandBufferEndRecording,&cb,0,0,0,0,0);
        C(QueueSubmitCommands,&q,1,P(&skipped),0,0,0);C(QueueFenceSync,&q,P(&sync),0,0,0,0);
        assert(C(SyncWait,&sync,UINT64_C(5000000000),0,0,0,0)<2);
        for(unsigned i=0;i<COUNT;i++)assert(output[i]==-1);

        C(QueueFinalize,&q,0,0,0,0,0);C(SyncFinalize,&sync,0,0,0,0,0);C(CommandBufferFinalize,&cb,0,0,0,0,0);
        nvn_metal_resources_reset();nvn_shader_reset();nvn_st_reset();free(memory);
        assert([[NSFileManager defaultManager] removeItemAtPath:root error:NULL]);
        puts("METAL_COMPUTE_PASS: compute shader match, uniform/storage/driver bindings, direct + indirect dispatch, unmatched program skipped");
    }
    return 0;
}
