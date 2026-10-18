#ifndef SMO_NVN_CMD_RENDER_H
#define SMO_NVN_CMD_RENDER_H
#include "nvn_cmd.h"
#include "nvn_resources.h"
#include "include/nvn.h"

enum {
    NVN_CMD_SET_RT=100, NVN_CMD_VIEWPORTS, NVN_CMD_SCISSORS, NVN_CMD_DEPTH_RANGES,
    NVN_CMD_CLEAR_COLOR, NVN_CMD_CLEAR_DEPTH, NVN_CMD_BIND_STATE, NVN_CMD_BIND_VATTR,
    NVN_CMD_BIND_VSTREAM, NVN_CMD_BIND_BUFFER, NVN_CMD_BIND_PROGRAM,
    NVN_CMD_SET_POOL, NVN_CMD_BIND_HANDLES, NVN_CMD_SCRATCH, NVN_CMD_COUNTER,
    NVN_CMD_DRAW, NVN_CMD_DRAW_INDEXED, NVN_CMD_DISPATCH, NVN_CMD_BLEND_COLOR,
    NVN_CMD_DISPATCH_INDIRECT
};
enum { NVN_STATE_BLEND, NVN_STATE_COLOR, NVN_STATE_CHANNEL, NVN_STATE_DEPTH,
       NVN_STATE_POLYGON, NVN_STATE_MULTISAMPLE };
enum { NVN_BIND_VERTEX, NVN_BIND_UNIFORM, NVN_BIND_STORAGE };
enum { NVN_BIND_TEXTURE, NVN_BIND_SAMPLER, NVN_BIND_IMAGE, NVN_BIND_SEPARATE_TEXTURE };
typedef struct { nvn_resource_snapshot resource; nvn_view_state view; uint64_t has_view; } nvn_attachment;
typedef struct { int32_t count, reserved; nvn_attachment colors[8], depth; } nvn_cmd_targets;
typedef struct { int32_t first, count; /* followed by count elements */ } nvn_cmd_array;
typedef struct { int32_t index, mask; float value[4]; } nvn_cmd_color;
typedef struct { float depth; uint32_t depth_mask; int32_t stencil, stencil_mask; } nvn_cmd_depth;
typedef struct { uint32_t kind, size; uint8_t bytes[24]; } nvn_cmd_state;
typedef struct { int32_t kind, stage, first, count; /* followed by NVNbufferRange */ } nvn_cmd_buffers;
typedef struct { nvn_resource_snapshot resource; uint64_t stages; } nvn_cmd_program;
typedef struct { uint64_t pool; int32_t kind, reserved; } nvn_cmd_pool;
typedef struct { int32_t kind, stage, first, count; /* followed by uint64 handles */ } nvn_cmd_handles;
typedef struct { uint64_t pool, offset, size; } nvn_cmd_scratch;
typedef struct { uint64_t type, address; } nvn_cmd_counter;
typedef struct { int32_t primitive, first, count, base_instance, instances, reserved; } nvn_cmd_draw;
typedef struct { int32_t primitive, index_type, count, base_vertex, base_instance, instances; uint64_t address; } nvn_cmd_draw_indexed;
typedef struct { uint32_t groups[3], reserved; } nvn_cmd_dispatch;
typedef struct { uint64_t address; } nvn_cmd_dispatch_indirect;  /* three uint32 group counts in GPU memory */
#endif
