#include "../nvn_host.h"
#include "../nvn_cmd.h"
#include "../nvn_state.h"
#include "../include/nvn.h"
#include <assert.h>

#define P(x) ((uint64_t)(uintptr_t)(x))
static uint64_t call(const char *suffix, uint64_t c, uint64_t a, uint64_t b,
                     uint64_t d, uint64_t e, uint64_t f) {
    char name[128];
    snprintf(name, sizeof name, "nvn%s", suffix);
    nvn_fn fn = nvn_lookup(name);
    assert(fn && fn != nvn_unimplemented);
    return fn(c, a, b, d, e, f, 0, 0);
}
#define CB(name,c,a,b,d,e,f) call("CommandBuffer" #name,P(c),(a),(b),(d),(e),(f))

static NVNmemoryPool pool;
static _Alignas(8) unsigned char memory[32768];
static size_t next_offset;
static unsigned callbacks;
static void replenish(NVNcommandBuffer *c, NVNcommandBufferMemoryEvent event,
                      size_t minimum, void *data) {
    assert(event == NVN_COMMAND_BUFFER_MEMORY_EVENT_OUT_OF_COMMAND_MEMORY);
    assert(data == &callbacks);
    size_t n = (minimum + 63) & ~(size_t)63;
    assert(next_offset + n <= sizeof memory);
    ++callbacks;
    CB(AddCommandMemory,c,P(&pool),next_offset,n,0,0);
    next_offset += n;
}
/* Deliberately a CPU-only test visitor, never installed as a runtime backend. */
static int execute(void *context, uint32_t op, const void *p, size_t size) {
    unsigned *count = context;
    ++*count;
    if (op == NVN_CMD_UPDATE_BUFFER) {
        nvn_cmd_update u;
        if (size < sizeof u) return 0;
        memcpy(&u,p,sizeof u);
        if (u.size > size - sizeof u) return 0;
        memcpy((void *)(uintptr_t)u.dst,(const char *)p + sizeof u,(size_t)u.size);
    } else if (op == NVN_CMD_COPY_BUFFER) {
        nvn_cmd_copy v;
        if (size != sizeof v) return 0;
        memcpy(&v,p,sizeof v);
        memmove((void *)(uintptr_t)v.dst,(const void *)(uintptr_t)v.src,(size_t)v.size);
    } else if (op == NVN_CMD_CLEAR_BUFFER) {
        nvn_cmd_clear v;
        if (size != sizeof v) return 0;
        memcpy(&v,p,sizeof v);
        for (size_t i=0;i<v.size/4;++i) ((uint32_t *)(uintptr_t)v.dst)[i]=v.value;
    } else if (op != NVN_CMD_BARRIER) return 0;
    return 1;
}
static void init(NVNcommandBuffer *c) {
    assert(CB(Initialize,c,0,0,0,0,0));
    CB(SetMemoryCallback,c,P(replenish),0,0,0,0);
    CB(SetMemoryCallbackData,c,P(&callbacks),0,0,0,0);
}
static void no_memory(NVNcommandBuffer *c, NVNcommandBufferMemoryEvent event,
                      size_t minimum, void *data) {
    (void)c; (void)minimum; (void)data;
    assert(event == NVN_COMMAND_BUFFER_MEMORY_EVENT_OUT_OF_COMMAND_MEMORY);
}
static void overflow_lifetime(void) {
    NVNcommandBuffer c, other;
    uint32_t output[4] = {0};
    assert(CB(Initialize,&c,0,0,0,0,0));
    CB(SetMemoryCallback,&c,P(no_memory),0,0,0,0);
    CB(AddCommandMemory,&c,P(&pool),0,64,0,0);
    CB(BeginRecording,&c,0,0,0,0,0);
    for (unsigned i=0;i<100;i++)
        CB(ClearBuffer,&c,P(output),sizeof output,i,0,0);
    uint64_t handle=CB(EndRecording,&c,0,0,0,0,0);
    size_t live=nvn_cmd_spill_bytes();
    assert(live>=65536);
    CB(Finalize,&c,0,0,0,0,0);
    unsigned count=0;
    assert(nvn_cmd_walk(handle,execute,&count) && count==100 && output[0]==99);
    /* A different range in the same pool cannot reclaim this list. */
    assert(CB(Initialize,&other,0,0,0,0,0));
    CB(AddCommandMemory,&other,P(&pool),128,64,0,0);
    assert(nvn_cmd_spill_bytes()==live);
    count=0; assert(nvn_cmd_walk(handle,execute,&count) && count==100);
    /* Explicit reuse, rather than elapsed frames, releases the old storage. */
    CB(AddCommandMemory,&other,P(&pool),0,64,0,0);
    assert(nvn_cmd_spill_bytes()==0);
    CB(BeginRecording,&other,0,0,0,0,0);
    CB(ClearBuffer,&other,P(output),sizeof output,7,0,0);
    CB(ClearBuffer,&other,P(output),sizeof output,8,0,0);
    uint64_t fresh=CB(EndRecording,&other,0,0,0,0,0);
    count=0; assert(nvn_cmd_walk(fresh,execute,&count) && count==2 && output[0]==8);
    assert(nvn_cmd_spill_bytes()>0); /* no callback is also supported */
    /* A single inline uniform upload may exceed the normal spill chunk. */
    size_t bytes=128*1024;
    unsigned char *source=malloc(bytes), *destination=calloc(1,bytes);
    assert(source && destination); memset(source,0x5a,bytes);
    CB(BeginRecording,&other,0,0,0,0,0);
    CB(UpdateUniformBuffer,&other,P(destination),bytes,0,bytes,P(source));
    uint64_t large=CB(EndRecording,&other,0,0,0,0,0);
    count=0; assert(nvn_cmd_walk(large,execute,&count) && count==1);
    assert(memcmp(source,destination,bytes)==0);
    free(source); free(destination);
    CB(Finalize,&other,0,0,0,0,0);
    call("MemoryPoolFinalize",P(&pool),0,0,0,0,0);
    assert(nvn_cmd_spill_bytes()==0);
}
int main(void) {
    assert(nvn_cmd_missing_is_skippable("nvnCommandBufferSetDepthClamp"));
    assert(nvn_cmd_missing_is_skippable("nvnCommandBufferClearTexture"));
    assert(!nvn_cmd_missing_is_skippable("nvnCommandBufferDrawTexture"));
    NVNcommandBuffer a,b;
    uint32_t input[4]={1,2,3,4}, output[4]={0}, copied[4]={0};
    nvn_st_ent *s=nvn_st_new(&pool,4);
    assert(s); s->v[1]=P(memory); s->v[2]=sizeof memory;
    init(&a); init(&b);
    assert(CB(GetMemoryCallback,&a,0,0,0,0,0)==P(replenish));
    assert(CB(GetMemoryCallbackData,&a,0,0,0,0,0)==P(&callbacks));
    assert(!CB(IsRecording,&a,0,0,0,0,0));
    CB(BeginRecording,&a,0,0,0,0,0);
    assert(CB(IsRecording,&a,0,0,0,0,0));
    CB(UpdateUniformBuffer,&a,P(output),sizeof output,0,sizeof input,P(input));
    CB(CopyBufferToBuffer,&a,P(output),P(copied),sizeof output,0,0);
    uint64_t first=CB(EndRecording,&a,0,0,0,0,0);
    assert(!CB(IsRecording,&a,0,0,0,0,0));
    assert(!output[0] && !copied[0]); /* recording has no execution effects */
    input[0]=999; /* record owns uniform update payload */
    unsigned count=0;
    assert(nvn_cmd_walk(first,execute,&count) && count==2);
    assert(output[0]==1 && copied[3]==4);
    assert(callbacks>=2); /* also traversed a segment jump */

    CB(BeginRecording,&b,0,0,0,0,0);
    CB(CopyCommands,&b,1,P(&first),0,0,0);
    uint64_t snapshot=CB(EndRecording,&b,0,0,0,0,0);
    /* A new recording must not mutate a previously ended handle. */
    CB(BeginRecording,&a,0,0,0,0,0);
    CB(ClearBuffer,&a,P(output),sizeof output,0x12345678,0,0);
    uint64_t second=CB(EndRecording,&a,0,0,0,0,0);
    count=0; assert(nvn_cmd_walk(first,execute,&count) && output[0]==1);
    count=0; assert(nvn_cmd_walk(second,execute,&count) && output[0]==0x12345678);
    /* CopyCommands is independent of the source command storage. */
    memset((void *)(uintptr_t)first,0,8);
    count=0; assert(nvn_cmd_walk(snapshot,execute,&count) && output[0]==1);

    uint64_t handles[2]={snapshot,second};
    CB(BeginRecording,&b,0,0,0,0,0);
    CB(CallCommands,&b,2,P(handles),0,0,0);
    uint64_t nested=CB(EndRecording,&b,0,0,0,0,0);
    handles[0]=0; /* handle array itself is copied */
    CB(Finalize,&a,0,0,0,0,0); CB(Finalize,&b,0,0,0,0,0);
    count=0; assert(nvn_cmd_walk(nested,execute,&count) && count==3 && output[0]==0x12345678);
    assert(!nvn_cmd_walk(first,execute,&count));
    assert(!nvn_cmd_walk(0,execute,&count));
    assert(!nvn_cmd_walk(nested+1,execute,&count));
    /* Reject recursive calls instead of overflowing the native stack. */
    _Alignas(8) uint64_t cycle[4];
    nvn_cmd_header begin={NVN_CMD_BEGIN,8}, invoke={NVN_CMD_CALL,16}, end={NVN_CMD_END,8};
    memcpy(cycle,&begin,8); memcpy(cycle+1,&invoke,8);
    cycle[2]=P(cycle); memcpy(cycle+3,&end,8);
    assert(!nvn_cmd_walk(P(cycle),execute,&count));
    overflow_lifetime();
    nvn_cmd_reset_storage();
    nvn_st_reset();
    puts("command recording: ownership, rollover, copy/call order, lifecycle and recursion passed");
    return 0;
}
