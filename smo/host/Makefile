# 宿主（macOS 开发/CI）。iOS 出包时同一份源码编进 App（映像走内嵌签名段那条路，见 loader_apple.c）。
#
# 依赖：clang（Xcode 命令行工具即可）。
# 用法：
#   make -C smo/host            编出 smo_host
#   make -C smo/host test       用合成产物跑装载器自检（不需要游戏文件）
#   make -C smo/host run        在真实产物上装载并进 nnMain（需要 work/rewrite 里有产物）
CC      ?= clang
CFLAGS  ?= -O2 -Wall -Wextra -Werror -g
LDFLAGS ?=
# CORE = 除 main.c 以外的宿主全部源（自检目标复用；内嵌装载自检也要它）
CORE = logbuf.c logsum.c romfs_resolve.c loader_core.c host_boot.c loader_apple.c thread.c hle.c hle_svc.c hle_thread.c hle_fs.c hle_hipc.c hle_sdkinit.c hle_vi.c hle_oe.c hle_pl.c hle_audio.c hle_hid.c hle_force_gen.c hle_nvn_reg.c entry.S ../gfx/nvn/hle_nvn.c ../gfx/nvn/nvn_table.c ../gfx/nvn/nvn_state.c ../gfx/nvn/nvn_core.c ../gfx/nvn/nvn_texture_transfer.c ../gfx/nvn/nvn_cmd.c ../gfx/nvn/nvn_cmd_render.c ../gfx/nvn/nvn_resources.c ../gfx/nvn/nvn_render_state.c ../gfx/nvn/nvn_gpu.c ../gfx/nvn/nvn_window.c ../gfx/nvn/nvn_tex.c ../gfx/nvn/nvn_shader.c ../gfx/nvn/nvn_shader_archive.c ../gfx/nvn/nvn_replay.c
METAL_RUNTIME_SRC = ../gfx/nvn/nvn_metal_runtime.m ../gfx/nvn/nvn_metal_render.m ../gfx/nvn/nvn_metal_resources.m ../gfx/nvn/nvn_texread.c ../gfx/nvn/nvn_bcdec.c
HOST_GPU_SRC =
HOST_GPU_FLAGS =
ifeq ($(shell uname -s),Darwin)
HOST_GPU_SRC = $(METAL_RUNTIME_SRC)
HOST_GPU_FLAGS = -DSMO_METAL_RUNTIME=1 -fobjc-arc -framework Metal -framework Foundation
endif
SRC = $(CORE) main.c $(HOST_GPU_SRC)
INC = -I. -I../gfx/nvn

smo_host: $(SRC) dm.h hle.h
	$(CC) $(CFLAGS) $(INC) $(HOST_GPU_FLAGS) -o $@ $(SRC) $(LDFLAGS)

# Execute the exact embedded program used by the IPA, without the iOS UI.
smo_host_embedded: $(SRC) ../ios/Sources/Embedded.S ../ios/Sources/Embedded.c
	$(CC) $(CFLAGS) $(INC) $(HOST_GPU_FLAGS) -DSMO_EMBED -o $@ $^ \
	    -Wl,-segprot,__DMsdkW,rw,rw -Wl,-segprot,__DMsubsdk0W,rw,rw -Wl,-segprot,__DMmainW,rw,rw

# 图形层单测的公共依赖。
#
# 为什么是一个变量而不是每个目标各写一份：原先三个目标各自抄了一遍文件清单，
# 加重放层时 hle_nvn.c 里多了一处 nvn_replay_call，只有 replay_selftest 的清单跟着改了，
# 另外两个目标从此链不上（undefined reference to `nvn_replay_call`）。
# CI 没发现是因为它绕过 Makefile、自己写 gcc 命令行 —— 现在 regress.sh 会跑 `make test`。
# 结论：这一组文件是相互依赖的整体，就该只写一次。
GFX_COMMON = ../gfx/nvn/hle_nvn.c ../gfx/nvn/nvn_table.c ../gfx/nvn/nvn_state.c \
             ../gfx/nvn/nvn_core.c ../gfx/nvn/nvn_texture_transfer.c ../gfx/nvn/nvn_cmd.c ../gfx/nvn/nvn_cmd_render.c ../gfx/nvn/nvn_resources.c ../gfx/nvn/nvn_render_state.c ../gfx/nvn/nvn_gpu.c ../gfx/nvn/nvn_window.c ../gfx/nvn/nvn_tex.c ../gfx/nvn/nvn_shader.c ../gfx/nvn/nvn_shader_archive.c ../gfx/nvn/nvn_replay.c

# NVN 图形层单测：接口层（按名取函数 + 命令记录）
nvn_iface_selftest: $(GFX_COMMON) ../gfx/nvn/tests/nvn_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^

# NVN 核心家族状态层单测（设备/池/缓冲/同步/采样器/程序）
nvn_selftest: $(GFX_COMMON) ../gfx/nvn/tests/nvn_core_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^

cmd_selftest: $(GFX_COMMON) ../gfx/nvn/tests/cmd_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^

queue_selftest: $(GFX_COMMON) ../gfx/nvn/tests/queue_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^

cmd_render_selftest: $(GFX_COMMON) ../gfx/nvn/tests/cmd_render_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^

render_state_selftest: ../gfx/nvn/nvn_render_state.c ../gfx/nvn/tests/render_state_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^

resources_selftest: ../gfx/nvn/nvn_resources.c ../gfx/nvn/nvn_state.c ../gfx/nvn/tests/resources_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^

metal_queue_selftest: $(GFX_COMMON) $(METAL_RUNTIME_SRC) ../gfx/nvn/tests/metal_queue_selftest.c
	$(CC) $(CFLAGS) $(INC) -DSMO_METAL_RUNTIME=1 -fobjc-arc -framework Metal -framework Foundation -o $@ $^

metal_resources_selftest: $(GFX_COMMON) ../gfx/nvn/nvn_metal_resources.m ../gfx/nvn/nvn_texread.c ../gfx/nvn/nvn_bcdec.c ../gfx/nvn/tests/metal_resources_selftest.m
	$(CC) $(CFLAGS) $(INC) -fobjc-arc -framework Metal -framework Foundation -o $@ $^

metal_render_selftest: $(GFX_COMMON) $(METAL_RUNTIME_SRC) ../gfx/nvn/tests/metal_render_selftest.m
	$(CC) $(CFLAGS) $(INC) -DSMO_METAL_RUNTIME=1 -fobjc-arc -framework Metal -framework Foundation -o $@ $^

metal_compute_selftest: $(GFX_COMMON) $(METAL_RUNTIME_SRC) ../gfx/nvn/tests/metal_compute_selftest.m
	$(CC) $(CFLAGS) $(INC) -DSMO_METAL_RUNTIME=1 -fobjc-arc -framework Metal -framework Foundation -o $@ $^

mtl_replay_selftest: $(GFX_COMMON) ../gfx/nvn/nvn_mtl.m ../gfx/nvn/tests/mtl_replay_selftest.c
	$(CC) $(CFLAGS) $(INC) -fobjc-arc -framework Metal -framework Foundation -o $@ $^

# 着色器索引单测（合成自检；真实数据用命令行给索引与 blob）
shader_selftest: $(GFX_COMMON) ../gfx/nvn/tests/shader_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^

# 重放记账层单测（不需要 Metal）
replay_selftest: $(GFX_COMMON) ../gfx/nvn/tests/replay_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^

# 纹理块线性布局单测（纯算术：GOB 双射 / 解交错可逆 / 尺寸性质）。
# 不进 GFX_COMMON：nvn_tex.c 不依赖状态层，单独编更快也更能定位问题。
tex_selftest: ../gfx/nvn/nvn_tex.c ../gfx/nvn/tests/tex_selftest.c ../gfx/nvn/nvn_tex.h
	$(CC) $(CFLAGS) $(INC) -o $@ ../gfx/nvn/nvn_tex.c ../gfx/nvn/tests/tex_selftest.c

# BC 解码单测（bcdec 薄封装；手工构造已知图样的 BC1/BC4/BC5 块，期望值手算可得）
bcdec_selftest: ../gfx/nvn/nvn_bcdec.c ../gfx/nvn/tests/bcdec_selftest.c ../gfx/nvn/nvn_bcdec.h
	$(CC) $(CFLAGS) $(INC) -o $@ ../gfx/nvn/nvn_bcdec.c ../gfx/nvn/tests/bcdec_selftest.c

# 纹理整链单测（块线性 BC 贴图 → 行优先像素：解交错 + 解码组合层）
texread_selftest: ../gfx/nvn/nvn_tex.c ../gfx/nvn/nvn_bcdec.c ../gfx/nvn/nvn_texread.c ../gfx/nvn/tests/texread_selftest.c
	$(CC) $(CFLAGS) $(INC) -o $@ ../gfx/nvn/nvn_tex.c ../gfx/nvn/nvn_bcdec.c ../gfx/nvn/nvn_texread.c ../gfx/nvn/tests/texread_selftest.c

# 装载器自检只用平台无关的那部分（本机也能编，见 smo/host/tests/loader_selftest.c）
loader_selftest: loader_core.c tests/loader_selftest.c dm.h
	$(CC) $(CFLAGS) -o $@ logbuf.c loader_core.c tests/loader_selftest.c

# 内核内存族的单测：不需要游戏文件，也不需要 Apple 平台
svc_selftest: hle_svc.c tests/svc_selftest.c dm.h hle.h
	$(CC) $(CFLAGS) -I. -o $@ logbuf.c hle_svc.c tests/svc_selftest.c

# 线程族单测：真并发（争锁互斥、条件唤醒、事件、地址仲裁、超时）
thread_selftest: hle_thread.c tests/thread_selftest.c dm.h hle_thread.h
	$(CC) $(CFLAGS) -I. -o $@ logbuf.c hle_thread.c tests/thread_selftest.c

# fs 服务单测：自己造一棵 romfs 与一个存档目录，不需要游戏文件
fs_selftest: hle_fs.c hle.c hle_force_gen.c tests/fs_selftest.c dm.h hle.h
	$(CC) $(CFLAGS) -I. -o $@ logbuf.c hle_fs.c hle.c hle_force_gen.c tests/fs_selftest.c

# HIPC 单测：启动日志服务的消息往返、句柄生命周期、边界与并发。
hipc_selftest: hle_sdkinit.c hle_hipc.c hle.c hle_force_gen.c tests/hipc_selftest.c dm.h hle.h
	$(CC) $(CFLAGS) -I. -o $@ logbuf.c hle_sdkinit.c hle_hipc.c hle.c hle_force_gen.c tests/hipc_selftest.c

# oe + hid 单测：环境查询与 Npad/触屏布局
oehid_selftest: hle_oe.c hle_hid.c hle.c hle_force_gen.c tests/oehid_selftest.c dm.h hle.h dm_input.h dm_oe.h
	$(CC) $(CFLAGS) -I. -o $@ logbuf.c hle_oe.c hle_hid.c hle.c hle_force_gen.c tests/oehid_selftest.c

pl_selftest: hle_pl.c hle.c hle_force_gen.c tests/pl_selftest.c dm.h hle.h
	$(CC) $(CFLAGS) -I. -o $@ logbuf.c hle_pl.c hle.c hle_force_gen.c tests/pl_selftest.c

audio_selftest: hle_audio.c hle.c hle_force_gen.c tests/audio_selftest.c dm.h hle.h
	$(CC) $(CFLAGS) -I. -o $@ logbuf.c hle_audio.c hle.c hle_force_gen.c tests/audio_selftest.c

gate_stack_selftest: thread.c entry.S logbuf.c tests/gate_stack_selftest.c tests/gate_stack_probe.S dm.h
	$(CC) $(CFLAGS) -I. -o $@ thread.c entry.S logbuf.c tests/gate_stack_selftest.c tests/gate_stack_probe.S

# 合成改写产物：装载器自检用。真产物是游戏内容，不能进 CI，所以自己造一份。
# 路径是仓库根下的 work/synthetic（make 在 smo/host 里跑，所以要 ../..）。
PY     ?= python3
SYNDIR  = ../../work/synthetic

$(SYNDIR)/sdk.patched.bin:
	$(PY) ../tools/make_synthetic_artifacts.py $(SYNDIR)

# 内嵌装载自检（只在 macOS 上跑：要 mach_vm_remap 与生成的 .S/.c）。
# 用**合成产物**生成三段内嵌，验证：不读任何文件也能装起来、映像与 patched.bin 逐字节相同、
# 代码段 RX / 可写段 RW 且真能写、门登记成功。iOS 真机路线就靠这条路，所以在 CI（macOS）上先证。
EMBED_S = ../../work/embed_selftest.S
EMBED_C = ../../work/embed_selftest.c
smoarc_selftest: smoarc.c tests/smoarc_selftest.c smoarc.h
	$(CC) $(CFLAGS) $(INC) -o $@ smoarc.c tests/smoarc_selftest.c

applogic_selftest: logbuf.c romfs_resolve.c tests/applogic_selftest.c dm.h logbuf.h romfs_resolve.h
	$(CC) $(CFLAGS) $(INC) -o $@ logbuf.c romfs_resolve.c tests/applogic_selftest.c

embed_selftest: $(CORE) $(HOST_GPU_SRC) tests/embed_selftest.c $(EMBED_S) $(EMBED_C)
	$(CC) $(CFLAGS) $(INC) $(HOST_GPU_FLAGS) -DSMO_EMBED -o $@ $(CORE) $(HOST_GPU_SRC) $(EMBED_S) $(EMBED_C) tests/embed_selftest.c \
	      -Wl,-segprot,__DMsdkW,rw,rw

$(EMBED_S): $(SYNDIR)/sdk.patched.bin ../ios/tools/gen_embed.py
	$(PY) ../ios/tools/gen_embed.py $(SYNDIR) $(EMBED_S) sdk

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
TEST_EXTRA = embed_selftest gate_stack_selftest
endif

logsum_selftest: logsum.c tests/logsum_selftest.c logsum.h
	$(CC) $(CFLAGS) -I. -o $@ logsum.c tests/logsum_selftest.c

test: logsum_selftest cmd_selftest queue_selftest cmd_render_selftest render_state_selftest resources_selftest $(TEST_EXTRA) applogic_selftest smoarc_selftest loader_selftest svc_selftest thread_selftest fs_selftest hipc_selftest vi_selftest oehid_selftest pl_selftest audio_selftest nvn_iface_selftest nvn_selftest shader_selftest replay_selftest tex_selftest bcdec_selftest texread_selftest $(SYNDIR)/sdk.patched.bin
	./applogic_selftest
	./smoarc_selftest
	./loader_selftest $(SYNDIR) sdk main
	./svc_selftest
	./thread_selftest
	./fs_selftest
	./hipc_selftest
	./vi_selftest
	./oehid_selftest
	./pl_selftest
	./audio_selftest
	./logsum_selftest
	./nvn_iface_selftest
	./nvn_selftest
	./cmd_selftest
	./queue_selftest
	./cmd_render_selftest
	./render_state_selftest
	./resources_selftest
	./shader_selftest
	./replay_selftest
	./tex_selftest
	./bcdec_selftest
	./texread_selftest
ifeq ($(UNAME_S),Darwin)
	./embed_selftest $(SYNDIR)/sdk.patched.bin
	./gate_stack_selftest
endif

# 改写前后动态等价性校验（Unicorn；需要 work/rewrite 里有真实产物，所以不进 CI）
equiv: ../tools/equiv_check.py
	$(PY) ../tools/equiv_check.py sdk --limit 200
	$(PY) ../tools/equiv_check.py sdk --kind cntpct --limit 40
	$(PY) ../tools/equiv_check.py rtld --limit 10

run: smo_host
	./smo_host work/rewrite sdk subsdk0 main --list

clean:
	rm -f logsum_selftest cmd_selftest queue_selftest smo_host embed_selftest gate_stack_selftest applogic_selftest smoarc_selftest loader_selftest svc_selftest thread_selftest fs_selftest hipc_selftest vi_selftest oehid_selftest pl_selftest audio_selftest nvn_selftest nvn_iface_selftest shader_selftest replay_selftest tex_selftest bcdec_selftest texread_selftest

.PHONY: test run equiv clean

vi_selftest: hle_vi.c hle_thread.c hle.c hle_force_gen.c tests/vi_selftest.c dm.h hle.h hle_thread.h
	$(CC) $(CFLAGS) -I. -o $@ logbuf.c hle_vi.c hle_thread.c hle.c hle_force_gen.c tests/vi_selftest.c
