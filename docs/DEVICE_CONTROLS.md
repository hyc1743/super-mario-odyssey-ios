# 真机操作与性能诊断

## 触屏手柄

当前 iOS 构建已经接入屏幕手柄。游戏首帧出现后显示双摇杆、方向键、A/B/X/Y、L/R、ZL/ZR、L3/R3 和 `+` / `−`。可以同时拖动摇杆并按动作键；松手、系统取消触摸或切到后台都会清除对应输入。屏幕右上角的“日志”按钮会临时打开状态面板并隐藏手柄，再点一次关闭面板并恢复手柄。

手柄输入通过 HID 接口进入游戏，不需要外接控制器。若首个游戏画面出现后仍看不到按键，导出日志检查 `TOUCH_CONTROLLER_READY dual_stick=1 buttons=16`。若手柄可见但按键无效，检查随后操作时游戏状态是否变化，并附上 `SMO-log-live.txt` 与 `SMO-stderr.txt`。

开始或确认标题画面的选项时，先按右侧动作键区的 `A`；触屏上的 `+` 对应 Switch 手柄 Plus 键，用于游戏里的 Start/菜单操作。若画面明确提示按 Start，再按 `+`。

2026-10-17 的 r252 真机日志显示，按 A 后已进入下一场景的资源加载，但宿主命令记录空间不足，在 `FATAL command memory exhausted, request=56` 处主动终止。补充存储按需分配，最多 64 MiB，跟随原命令内存区间重用或内存池销毁回收；不会按固定帧数提前回收。`NVN_COMMAND_SPILL` 记录分配次数和当前占用。ARM64 检查在第 10 秒和第 20 秒附近各按一次真实 HID A 键，要求最后一次松开后仍有 GPU 完成帧；截图还需确认已离开说明页。这项检查仍不等于完整关卡验证。

## 降低发热

屏幕顶部中央的帧率按钮可以在 60 帧和省电 30 帧之间切换。iOS 低电量模式或系统温控达到 Serious/Critical 时，渲染上限会自动降到 30 帧；应用进入后台后暂停渲染，回到前台再恢复。30 帧会让操作响应略慢，若游戏逻辑明显异常可切回 60 帧。

运行日志每 10 秒记录 `RUNTIME_STATS`，包括实际送出的帧率、进程 CPU 核心占用、内存占用和温控状态。连续游玩时对比这些数据和手机温度，能区分高帧率负载、内存增长和系统温控降速。

## 音频检查

iOS 使用 48 kHz 立体声扬声器输出。`AUDIO_RENDERER_MIX_FRAMES` 应持续增加，`AUDIO_DEVICE_PCM` 的 `frames` 记录混音器产生的设备帧数，`audible` / `peak` 表示样本是否包含非零信号；`AUDIO_SPEAKER` 的 `callbacks` / `played` / `queued` 则表示 RemoteIO 是否持续取走音频队列。`AUDIO_SPEAKER_LIFECYCLE`、`AUDIO_SPEAKER_INTERRUPTION` 和 `AUDIO_SPEAKER_MEDIA_RESET` 用于区分前后台切换、系统中断和音频服务重置。启动自检还会要求持续混音，单帧静音不再算通过。

真机验证时先确认铃声/媒体音量正常，再进入游戏并操作一段时间；随后切到后台、恢复前台并再次播放。若没有声音，请导出日志，重点保留上述三类音频记录及其前后时间戳。启动自检能证明 PCM 持续生成，最终扬声器听感仍需真机确认。

r252 的本次真机日志中 `AUDIO_SPEAKER running=1`，`callbacks=978 played=422400`，但 `AUDIO_DEVICE_PCM` 仍为 `audible=0 peak=0`。这证明设备输出回调取到了静音样本，尚未验证到非零游戏音频；不能据此宣称声音已修复。

后续真机日志定位到另一处崩溃：命令内存补充成功后，约 30 秒时在 `nvnTextureGetZCullStorageSize` 路径出现 `FATAL missing resource type=12`。修复包括实现纹理 ZCull 存储大小查询，并把失效纹理记录为 `NVN_RESOURCE_MISS` 后跳过该次渲染命令，避免单个资源生命周期问题直接终止进程。

r257 的新日志显示资源失效已被绕过，但约 53 秒时仍因 12 个已知的低层命令记录为不支持而 `NVN_GPU_SUBMIT_FAILED`。下一版对这 12 个命令只跳过其自身状态更新并保留日志，未知命令仍然拒绝提交。音频日志从下一版开始同时记录 DSP 设备输入 `input_peak` 和 PCM 输出 `peak`，用来确定静音发生在 DSP 前还是转换后。

真机前可运行 `SMO_AUDIO_TEST_WAV=work/test-audio.wav ./smo/host/audio_selftest`，再运行 `python smo/verify/check_audio_wav.py work/test-audio.wav`。该测试使用合成的非零混音命令，检查 48 kHz PCM16 双声道、非零峰值和 WAV 数据长度；它能验证混音/转换链路，但不能证明真实游戏资源已经播放音乐。
