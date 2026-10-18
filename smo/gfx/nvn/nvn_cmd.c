#include "nvn_host.h"
#include "nvn_state.h"
#include "nvn_cmd.h"
#include "include/nvn.h"
#include <limits.h>
#include <pthread.h>

enum { CMD_TYPE = 13, POOL_TYPE = 4 };
enum { C_DEV, C_CB, C_DATA, C_CUR, C_END, C_BEGIN, C_RECORDING,
       C_SIZE, C_USED, C_CONTROL_SIZE, C_POOL, C_ANCHOR, C_ANCHOR_END };
enum { TAIL_BYTES = 16, MAX_DEPTH = 64, MAX_RECORDS = 1 << 22 };
static void put_header(void *p, uint32_t op, uint32_t size);

/* Host records can exceed the hardware command budget. Keep overflow storage
 * with the guest segment that links to it, including after recorder Finalize.
 * Regranting that range or finalizing its pool invalidates the old handles.
 * A frame-count timeout would instead invalidate long-lived command lists. */
typedef struct cmd_spill {
    struct cmd_spill *next;
    const void *pool;
    uintptr_t anchor, end;
    size_t bytes;
    unsigned char memory[];
} cmd_spill;
static cmd_spill *spills;
static size_t spill_bytes;
static unsigned spill_count;
static pthread_mutex_t spill_lock = PTHREAD_MUTEX_INITIALIZER;
enum { SPILL_CHUNK = 64 * 1024, SPILL_LIMIT = 64 * 1024 * 1024 };

static void release_spills(const void *pool, uintptr_t start, uintptr_t end) {
    pthread_mutex_lock(&spill_lock);
    cmd_spill **link = &spills;
    while (*link) {
        cmd_spill *p = *link;
        if (!pool || (p->pool == pool && p->anchor < end && start < p->end)) {
            *link = p->next; spill_bytes -= p->bytes; free(p);
        } else link = &p->next;
    }
    pthread_mutex_unlock(&spill_lock);
}
void nvn_cmd_release_pool(const void *pool) { release_spills(pool, 0, UINTPTR_MAX); }
void nvn_cmd_reset_storage(void) { release_spills(NULL, 0, 0); }
size_t nvn_cmd_spill_bytes(void) {
    pthread_mutex_lock(&spill_lock); size_t bytes = spill_bytes;
    pthread_mutex_unlock(&spill_lock); return bytes;
}
static void use_segment(nvn_st_ent *s, uintptr_t start, uintptr_t end) {
    if (s->v[C_RECORDING] && s->v[C_CUR]) {
        put_header((void *)(uintptr_t)s->v[C_CUR], NVN_CMD_JUMP, 16);
        memcpy((void *)(uintptr_t)(s->v[C_CUR] + 8), &start, 8);
    }
    if (s->v[C_CUR]) s->v[C_USED] += s->v[C_END] - s->v[C_CUR];
    s->v[C_SIZE] += end - start;
    s->v[C_CUR] = start; s->v[C_END] = end;
}
static void add_spill(nvn_st_ent *s, size_t minimum) {
    if (!s->v[C_POOL] || !s->v[C_ANCHOR])
        NVN_DIE("command memory callback supplied no initial segment");
    size_t bytes = minimum > SPILL_CHUNK ? minimum : SPILL_CHUNK;
    pthread_mutex_lock(&spill_lock);
    cmd_spill *p = bytes <= SPILL_LIMIT - spill_bytes ? malloc(sizeof *p + bytes) : NULL;
    if (!p) {
        size_t total = spill_bytes; pthread_mutex_unlock(&spill_lock);
        NVN_DIE("command overflow storage unavailable request=%zu live=%zu limit=%u", bytes, total, SPILL_LIMIT);
    }
    p->pool = (void *)(uintptr_t)s->v[C_POOL];
    p->anchor = s->v[C_ANCHOR]; p->end = s->v[C_ANCHOR_END]; p->bytes = bytes;
    p->next = spills; spills = p; spill_bytes += bytes;
    size_t total = spill_bytes; unsigned count = ++spill_count;
    pthread_mutex_unlock(&spill_lock);
    uintptr_t start = (uintptr_t)p->memory;
    use_segment(s, start, start + bytes);
    if (count == 1 || count % 64 == 0)
        NVN_LOG("NVN_COMMAND_SPILL count=%u bytes=%zu live=%zu limit=%u", count, bytes, total, SPILL_LIMIT);
}

static nvn_st_ent *cmd(const NVNcommandBuffer *c) {
    nvn_st_ent *s = nvn_st_get(c, CMD_TYPE);
    if (!s) NVN_DIE("command buffer %p is not initialized", (const void *)c);
    return s;
}
static void put_header(void *p, uint32_t op, uint32_t size) {
    nvn_cmd_header h = {op, size};
    memcpy(p, &h, sizeof h);
}
static void *alloc_record(NVNcommandBuffer *c, uint32_t op, size_t payload) {
    nvn_st_ent *s = cmd(c);
    if (!s->v[C_RECORDING]) NVN_DIE("command recorded outside Begin/EndRecording");
    if (payload > UINT32_MAX - sizeof(nvn_cmd_header) - 7 - TAIL_BYTES)
        NVN_DIE("command payload too large");
    size_t size = (sizeof(nvn_cmd_header) + payload + 7) & ~(size_t)7;
    unsigned tries = 0;
    while (!s->v[C_CUR] || s->v[C_END] - s->v[C_CUR] < size + TAIL_BYTES) {
        if (!s->v[C_CB] || tries++ == 2) {
            add_spill(s, size + TAIL_BYTES);
            break;
        }
        PFNNVNCOMMANDBUFFERMEMORYCALLBACKPROC cb =
            (PFNNVNCOMMANDBUFFERMEMORYCALLBACKPROC)(uintptr_t)s->v[C_CB];
        cb(c, NVN_COMMAND_BUFFER_MEMORY_EVENT_OUT_OF_COMMAND_MEMORY,
           size + TAIL_BYTES, (void *)(uintptr_t)s->v[C_DATA]);
    }
    uint8_t *p = (void *)(uintptr_t)s->v[C_CUR];
    s->v[C_CUR] += size;
    s->v[C_USED] += size;
    memset(p, 0, size);
    put_header(p, op, (uint32_t)size);
    return p + sizeof(nvn_cmd_header);
}

int nvn_cmd_missing_is_skippable(const char *name) {
    static const char *const names[]={
        "nvnCommandBufferSetPrimitiveRestart",
        "nvnCommandBufferSetDepthClamp",
        "nvnCommandBufferSetPolygonOffsetClamp",
        "nvnCommandBufferSetTiledCacheAction",
        "nvnCommandBufferSetTiledCacheTileSize",
        "nvnCommandBufferSetStencilValueMask",
        "nvnCommandBufferSetStencilMask",
        "nvnCommandBufferSetStencilRef",
        "nvnCommandBufferSetDepthBounds",
        "nvnCommandBufferSetRasterizerDiscard",
        "nvnCommandBufferSetPointSize",
        "nvnCommandBufferClearTexture"
    };
    if(!name)return 0;
    for(size_t i=0;i<sizeof names/sizeof names[0];i++)if(!strcmp(name,names[i]))return 1;
    return 0;
}

uint64_t nvn_CommandBufferInitialize(NVNcommandBuffer *c, NVNdevice *d) {
    if (!c) return 0;
    nvn_st_ent *s = nvn_st_new(c, CMD_TYPE);
    if (!s) return 0;
    s->v[C_DEV] = (uintptr_t)d;
    return 1;
}
void *nvn_cmd_alloc(void *recorder, uint32_t op, size_t payload_size) {
    return alloc_record(recorder,op,payload_size);
}
void nvn_CommandBufferFinalize(NVNcommandBuffer *c) { nvn_st_del(c, CMD_TYPE); }
void nvn_CommandBufferSetMemoryCallback(NVNcommandBuffer *c, PFNNVNCOMMANDBUFFERMEMORYCALLBACKPROC cb) {
    cmd(c)->v[C_CB] = (uintptr_t)cb;
}
void nvn_CommandBufferSetMemoryCallbackData(NVNcommandBuffer *c, void *data) {
    cmd(c)->v[C_DATA] = (uintptr_t)data;
}
PFNNVNCOMMANDBUFFERMEMORYCALLBACKPROC nvn_CommandBufferGetMemoryCallback(const NVNcommandBuffer *c) {
    return (PFNNVNCOMMANDBUFFERMEMORYCALLBACKPROC)(uintptr_t)cmd(c)->v[C_CB];
}
void *nvn_CommandBufferGetMemoryCallbackData(const NVNcommandBuffer *c) {
    return (void *)(uintptr_t)cmd(c)->v[C_DATA];
}
void nvn_CommandBufferAddCommandMemory(NVNcommandBuffer *c, const NVNmemoryPool *pool,
                                     ptrdiff_t offset, size_t size) {
    nvn_st_ent *s = cmd(c), *p = nvn_st_get(pool, POOL_TYPE);
    if (!p || !p->v[1] || offset < 0 || (uint64_t)offset > p->v[2] ||
        size > p->v[2] - (uint64_t)offset || size < 32)
        NVN_DIE("invalid command memory pool=%p offset=%lld size=%zu",
                (const void *)pool, (long long)offset, size);
    uintptr_t raw = p->v[1] + (uint64_t)offset;
    uintptr_t start = (raw + 7) & ~(uintptr_t)7;
    uintptr_t end = raw + size;
    if (end < raw || end - start < 24) NVN_DIE("invalid command memory alignment");
    if (s->v[C_RECORDING] && s->v[C_POOL] == (uintptr_t)pool &&
        s->v[C_ANCHOR] < end && start < s->v[C_ANCHOR_END])
        NVN_DIE("command memory regranted while its recording is active");
    release_spills(pool, start, end);
    use_segment(s, start, end);
    s->v[C_POOL] = (uintptr_t)pool;
    s->v[C_ANCHOR] = start; s->v[C_ANCHOR_END] = end;
}
void nvn_CommandBufferAddControlMemory(NVNcommandBuffer *c, void *memory, size_t size) {
    if (!memory && size) NVN_DIE("null control memory");
    cmd(c)->v[C_CONTROL_SIZE] += size;
}
size_t nvn_CommandBufferGetCommandMemorySize(const NVNcommandBuffer *c) { return cmd(c)->v[C_SIZE]; }
size_t nvn_CommandBufferGetCommandMemoryUsed(const NVNcommandBuffer *c) { return cmd(c)->v[C_USED]; }
size_t nvn_CommandBufferGetCommandMemoryFree(const NVNcommandBuffer *c) {
    nvn_st_ent *s = cmd(c); return s->v[C_END] - s->v[C_CUR];
}
/* The host stream uses command memory for both records and control links. */
size_t nvn_CommandBufferGetControlMemorySize(const NVNcommandBuffer *c) { return cmd(c)->v[C_CONTROL_SIZE]; }
size_t nvn_CommandBufferGetControlMemoryUsed(const NVNcommandBuffer *c) { (void)cmd(c); return 0; }
size_t nvn_CommandBufferGetControlMemoryFree(const NVNcommandBuffer *c) { return cmd(c)->v[C_CONTROL_SIZE]; }
void nvn_CommandBufferBeginRecording(NVNcommandBuffer *c) {
    nvn_st_ent *s = cmd(c);
    if (s->v[C_RECORDING]) NVN_DIE("BeginRecording while already recording");
    s->v[C_RECORDING] = 1;
    uint8_t *payload = alloc_record(c, NVN_CMD_BEGIN, 0);
    s->v[C_BEGIN] = (uintptr_t)(payload - sizeof(nvn_cmd_header));
}
NVNcommandHandle nvn_CommandBufferEndRecording(NVNcommandBuffer *c) {
    nvn_st_ent *s = cmd(c);
    (void)alloc_record(c, NVN_CMD_END, 0);
    s->v[C_RECORDING] = 0;
    return s->v[C_BEGIN];
}
uint64_t nvn_CommandBufferIsRecording(const NVNcommandBuffer *c) { return cmd(c)->v[C_RECORDING] != 0; }

static int walk(uint64_t handle, nvn_cmd_visit visit, void *context, unsigned depth, unsigned *budget) {
    if (!handle || (handle & 7) || depth >= MAX_DEPTH) return 0;
    const uint8_t *p = (const void *)(uintptr_t)handle;
    nvn_cmd_header h;
    memcpy(&h, p, sizeof h);
    if (h.op != NVN_CMD_BEGIN || h.size != 8) return 0;
    p += 8;
    while (*budget) {
        --*budget;
        memcpy(&h, p, sizeof h);
        if (h.size < 8 || (h.size & 7)) return 0;
        const void *data = p + 8;
        if (h.op == NVN_CMD_END) return h.size == 8;
        if (h.op == NVN_CMD_JUMP || h.op == NVN_CMD_CALL) {
            uint64_t next;
            if (h.size != 16) return 0;
            memcpy(&next, data, sizeof next);
            if (!next || (next & 7)) return 0;
            if (h.op == NVN_CMD_JUMP) { p = (const void *)(uintptr_t)next; continue; }
            if (!walk(next, visit, context, depth + 1, budget)) return 0;
        } else if (h.op == NVN_CMD_BEGIN || !visit(context, h.op, data, h.size - 8)) return 0;
        p += h.size;
    }
    return 0;
}
int nvn_cmd_walk(uint64_t handle, nvn_cmd_visit visit, void *context) {
    unsigned budget = MAX_RECORDS;
    return visit && walk(handle, visit, context, 0, &budget);
}
void nvn_CommandBufferCallCommands(NVNcommandBuffer *c, int count, const NVNcommandHandle *handles) {
    if (count < 0 || (count && !handles)) NVN_DIE("invalid CallCommands array");
    for (int i = 0; i < count; ++i)
        memcpy(alloc_record(c, NVN_CMD_CALL, 8), &handles[i], 8);
}
static int copy_record(void *context, uint32_t op, const void *data, size_t size) {
    memcpy(alloc_record(context, op, size), data, size);
    return 1;
}
void nvn_CommandBufferCopyCommands(NVNcommandBuffer *c, int count, const NVNcommandHandle *handles) {
    if (count < 0 || (count && !handles)) NVN_DIE("invalid CopyCommands array");
    for (int i = 0; i < count; ++i)
        if (!nvn_cmd_walk(handles[i], copy_record, c)) NVN_DIE("invalid copied command handle");
}
void nvn_CommandBufferCopyBufferToBuffer(NVNcommandBuffer *c, NVNbufferAddress src,
                                        NVNbufferAddress dst, size_t size, int flags) {
    nvn_cmd_copy v = {src, dst, size, (uint32_t)flags};
    memcpy(alloc_record(c, NVN_CMD_COPY_BUFFER, sizeof v), &v, sizeof v);
}
void nvn_CommandBufferUpdateUniformBuffer(NVNcommandBuffer *c, NVNbufferAddress dst,
                                         size_t buffer_size, ptrdiff_t offset, size_t size, const void *data) {
    if (offset < 0 || (uint64_t)offset > buffer_size || size > buffer_size - (uint64_t)offset ||
        (size && !data) || dst > UINT64_MAX - (uint64_t)offset || size > UINT32_MAX - 64)
        NVN_DIE("invalid uniform buffer update");
    nvn_cmd_update v = {dst + (uint64_t)offset, size};
    uint8_t *p = alloc_record(c, NVN_CMD_UPDATE_BUFFER, sizeof v + size);
    memcpy(p, &v, sizeof v);
    if (size) memcpy(p + sizeof v, data, size);
}
void nvn_CommandBufferClearBuffer(NVNcommandBuffer *c, NVNbufferAddress dst, size_t size, uint32_t value) {
    if ((dst & 3) || (size & 3)) NVN_DIE("unaligned ClearBuffer");
    nvn_cmd_clear v = {dst, size, value, 0};
    memcpy(alloc_record(c, NVN_CMD_CLEAR_BUFFER, sizeof v), &v, sizeof v);
}
void nvn_CommandBufferBarrier(NVNcommandBuffer *c, int flags) {
    memcpy(alloc_record(c, NVN_CMD_BARRIER, sizeof flags), &flags, sizeof flags);
}
uint64_t nvn_cmd_record_missing(const char *name, const uint64_t args[8]) {
    nvn_cmd_missing m = {name,{0}};
    memcpy(m.args,args,sizeof m.args);
    nvn_st_ent *s=nvn_st_get((void *)(uintptr_t)args[0],CMD_TYPE);
    if (!s || !s->v[C_RECORDING]) NVN_DIE("NVN_COMMAND_UNSUPPORTED %s outside recording",name);
    memcpy(alloc_record((void *)(uintptr_t)args[0],NVN_CMD_UNSUPPORTED,sizeof m),&m,sizeof m);
    return 0;
}
void nvn_CommandBufferSetDebugLabel(NVNcommandBuffer *c, const char *label) {
    (void)cmd(c); (void)label;
}
