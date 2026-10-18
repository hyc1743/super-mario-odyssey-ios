#include "../hle.h"
#include "../audio_ring.h"
#include "../audio_device_sink.h"
#include "../audio_output.h"
#include <pthread.h>
#include <time.h>
#include <stdio.h>

module_t g_mod[MAX_MOD];
int g_nmod = 2;
void unimpl_stubs(void) {}
int svc_dispatch(unsigned n, uint64_t *r) { (void)n; (void)r; return -1; }
static _Atomic int fails;
static int valid_calls, size_calls, accept;
static const void *expected_parameter;
static uint8_t expected_internal[0x34];
static int constructed, initialized, finalized, destroyed, started, stopped;
static int client_calls, server_calls, bound, forgotten;
static _Atomic int processed,output_calls,device_commands;
static int16_t captured_pcm[480*2*4];
static size_t captured_frames;
static int captured_peak;
static _Atomic int event_signals;
static _Atomic int worker_attach_calls;
static void *last_bound;
static uint32_t server_result, init_result;
static int budget;
static uint8_t commands[1024];
static _Atomic unsigned symbol_lookups;
static int32_t sink_mix[240*2];
static const uint8_t *process_list;
static const void *expected_config;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); atomic_fetch_add(&fails,1); } } while (0)
static void output_pcm(const int16_t *pcm,size_t frames){
    int call=atomic_fetch_add(&output_calls,1)+1;CHECK(frames==240 && pcm[0]==call*100 && pcm[1]==call*100);
    for(size_t i=0;i<frames*2;i++) {
        if (captured_frames < 240*4) captured_pcm[captured_frames*2+i%2] = pcm[i];
        int value=pcm[i]<0?-(int)pcm[i]:pcm[i]; if(value>captured_peak) captured_peak=value;
        if(i%2==1) captured_frames++;
    }
}
static void write_test_wav(void) {
    const char *path=getenv("SMO_AUDIO_TEST_WAV"); if(!path)return;
    size_t frames=captured_frames>240*4?240*4:captured_frames;
    FILE *f=fopen(path,"wb");CHECK(f!=NULL);if(!f)return;
    uint32_t riff=36+(uint32_t)(frames*4),fmt=16,data=(uint32_t)(frames*4),rate=48000,byte_rate=rate*4;
    uint16_t audio=1,channels=2,bits=16,block=4;
    fwrite("RIFF",1,4,f);fwrite(&riff,4,1,f);fwrite("WAVEfmt ",1,8,f);fwrite(&fmt,4,1,f);
    fwrite(&audio,2,1,f);fwrite(&channels,2,1,f);fwrite(&rate,4,1,f);fwrite(&byte_rate,4,1,f);
    fwrite(&block,2,1,f);fwrite(&bits,2,1,f);fwrite("data",1,4,f);fwrite(&data,4,1,f);
    fwrite(captured_pcm,4,frames,f);fclose(f);CHECK(captured_peak>0 && frames>=240);
}
static smo_audio_ring test_ring;
static void *ring_producer(void *unused){
    (void)unused;int16_t pair[2];
    for(int i=0;i<100000;i++){pair[0]=(int16_t)i;pair[1]=(int16_t)~i;while(!smo_audio_ring_push(&test_ring,pair,1)){} }
    return NULL;
}
static void output_test(void){
    int16_t pair[2]={123,-456},out[480];
    CHECK(smo_audio_ring_push(&test_ring,pair,1)==1);
    CHECK(smo_audio_ring_pop(&test_ring,out,2)==1);
    CHECK(out[0]==123 && out[1]==-456 && out[2]==0 && out[3]==0);
    pthread_t producer;CHECK(!pthread_create(&producer,NULL,ring_producer,NULL));
    for(int i=0;i<100000;){size_t n=smo_audio_ring_pop(&test_ring,out,87);
        for(size_t s=0;s<n;s++,i++)CHECK(out[2*s]==(int16_t)i && out[2*s+1]==(int16_t)~i);}
    CHECK(!pthread_join(producer,NULL));
    uint8_t header[32]={0},cmd[0x130]={0};int32_t mix[240*6]={0};
    uint32_t v=6;memcpy(header+0x10,&v,4);v=240;memcpy(header+0x14,&v,4);v=48000;memcpy(header+0x18,&v,4);
    uint64_t address=(uintptr_t)mix;memcpy(cmd+0x118,&address,8);cmd[0x10]=1;
    v=2;memcpy(cmd+0x120,&v,4);cmd[0x124]=1;cmd[0x125]=0;
    mix[240]=INT32_MAX;mix[0]=INT32_MIN;
    CHECK(smo_audio_device_pcm(header,cmd,sizeof cmd,out,240)==240);
    CHECK(out[0]==32767 && out[1]==-32768 && out[2]==0 && out[3]==0);
    v=1;memcpy(cmd+0x120,&v,4);mix[240]=1234;
    CHECK(smo_audio_device_pcm(header,cmd,sizeof cmd,out,240)==240 && out[0]==1234 && out[1]==1234);
    v=6;memcpy(cmd+0x120,&v,4);for(int i=0;i<6;i++)cmd[0x124+i]=(uint8_t)i;
    memset(mix,0,sizeof mix);mix[0]=10000;mix[240]=10000;
    CHECK(smo_audio_device_pcm(header,cmd,sizeof cmd,out,240)==240 && abs(out[0]-7071)<=2 && abs(out[1]-7071)<=2);
    cmd[0x124]=6;CHECK(smo_audio_device_pcm(header,cmd,sizeof cmd,out,240)<0);
    CHECK(smo_audio_device_pcm(header,cmd,0x12f,out,240)<0);
}
static int valid(const void *p) {
    valid_calls++;
    CHECK(p == expected_parameter);
    return accept;
}
static uint64_t size(const void *p) {
    size_calls++;
    CHECK(!memcmp(p, expected_internal, sizeof expected_internal));
    return 0x8000;
}
void hle_bind_system_event(void *event) { CHECK(event); last_bound = event; bound++; }
void hle_signal_system_event(void *event) { (void)event; atomic_fetch_add(&event_signals,1); }
void hle_forget_system_event(void *event) { CHECK(event); forgotten++; }
uint32_t hle_thread_attach_host_worker(void) { return (uint32_t)(atomic_fetch_add(&worker_attach_calls,1)+1); }
void hle_thread_detach_host_worker(void) { }
static void construct(void *p) { CHECK(p); constructed++; }
static uint32_t initialize(void *p, const void *parameters, uint32_t process,
                           void *work, size_t bytes, const uint64_t *applet, int session) {
    CHECK(p && work && bytes >= 0x8000 && applet && !*applet && session == 0);
    CHECK(process == 0xffff8001u);
    CHECK(!memcmp(parameters, expected_internal, sizeof expected_internal));
    initialized++;
    return init_result;
}
static void finalize(void *p) { CHECK(p); finalized++; }
static void destroy(void *p) { CHECK(p); destroyed++; }
static void signal_event(void *p) { CHECK(p); }
static uint32_t start(void *p) { CHECK(p); started++; return 0; }
static void stop(void *p) { CHECK(p); stopped++; }
static void set_limit(void *p, int value) { CHECK(p); budget = value; }
static int get_limit(const void *p) { CHECK(p); return budget; }
static void *get_buffer(const void *p) { CHECK(p); return commands; }
static size_t capacity(const void *p) { CHECK(p); return sizeof commands; }
static size_t generate(void *p, void *b, size_t n) {
    CHECK(p && b == commands && n == sizeof commands);
    if(atomic_load(&device_commands)){
        memset(commands,0,sizeof commands);uint32_t v=4;memcpy(commands+4,&v,4);
        v=2;memcpy(commands+0x10,&v,4);v=240;memcpy(commands+0x14,&v,4);v=48000;memcpy(commands+0x18,&v,4);
        size_t at=32;
        for(int i=0;i<4;i++){
            v=0xcafebabe;memcpy(commands+at,&v,4);uint16_t len=i%2?0x130:0x18,type=i%2?15:20;
            memcpy(commands+at+4,&len,2);memcpy(commands+at+6,&type,2);commands[at+0x10]=1;
            if(type==15){uint64_t address=(uintptr_t)sink_mix;memcpy(commands+at+0x118,&address,8);
                v=2;memcpy(commands+at+0x120,&v,4);commands[at+0x125]=1;
            }else{v=(i/2+1)*100;memcpy(commands+at+0x14,&v,4);}
            at+=len;
        }return at;
    }
    return 32;
}
static void setup(void *p, const void *b, size_t n) {
    CHECK(p);if(!atomic_load(&device_commands))CHECK(b==commands && n==32);else CHECK(n==32+0x18+0x130);process_list=b;
}
static void process(void *p) {
    CHECK(p);atomic_fetch_add(&processed,1);if(atomic_load(&device_commands)){
        size_t at=32;for(uint32_t i=0;i<smo_audio_u32(process_list+4);i++){
            if(smo_audio_u16(process_list+at+6)==20)for(unsigned s=0;s<480;s++)sink_mix[s]=(int32_t)smo_audio_u32(process_list+at+0x14);
            at+=smo_audio_u16(process_list+at+4);
        }
    }
}
static void time_limit(void *p, uint32_t n) { CHECK(p && n == UINT32_MAX); }
typedef struct { void *object, *event; } handle_t;
typedef struct { void *data; size_t size; } buffer_t;
static uint32_t update(void *p, void *out, size_t out_size, void *performance,
                        size_t performance_size, const void *in, size_t in_size) {
    CHECK(p && out == commands && out_size == 16);
    CHECK(!performance && !performance_size && in == expected_config && in_size == 24);
    server_calls++;
    return server_result;
}
static uint32_t client(handle_t handle, const void *config) {
    CHECK(config == expected_config);
    const void *const *vtable = *(const void *const **)handle.object;
    uint32_t (*call)(void *, const buffer_t *, const buffer_t *, const buffer_t *) = (void *)vtable[8];
    buffer_t out = {commands, 16}, performance = {NULL, 0}, in = {(void *)config, 24};
    client_calls++;
    return call(handle.object, &out, &performance, &in);
}
void *module_sym(module_t *module, const char *name) {
    symbol_lookups++;
    CHECK(module == &g_mod[1]);
    if (strstr(name, "IsValidAudioRendererParameter")) return (void *)valid;
    if (strstr(name, "AudioRenderSystem17GetWorkBufferSize")) return (void *)size;
    if (strstr(name, "RequestUpdateAudioRenderer")) return (void *)client;
    if (strstr(name, "AudioRenderSystemC1Ev")) return (void *)construct;
    if (strstr(name, "AudioRenderSystem10Initialize")) return (void *)initialize;
    if (strstr(name, "AudioRenderSystem8Finalize")) return (void *)finalize;
    if (strstr(name, "AudioRenderSystem5Start")) return (void *)start;
    if (strstr(name, "AudioRenderSystem4Stop")) return (void *)stop;
    if (strstr(name, "AudioRenderSystem6Update")) return (void *)update;
    if (strstr(name, "AudioRenderSystem21SetRenderingTimeLimit")) return (void *)set_limit;
    if (strstr(name, "AudioRenderSystem21GetRenderingTimeLimit")) return (void *)get_limit;
    if (strstr(name, "AudioRenderSystem26GetCommandBufferWorkBuffer")) return (void *)get_buffer;
    if (strstr(name, "AudioRenderSystem30GetCommandBufferWorkBufferSize")) return (void *)capacity;
    if (strstr(name, "AudioRenderSystem15GenerateCommand")) return (void *)generate;
    if (strstr(name, "CommandListProcessor17SetProcessTimeMax")) return (void *)time_limit;
    if (strstr(name, "CommandListProcessor5Setup")) return (void *)setup;
    if (strstr(name, "CommandListProcessor7Process")) return (void *)process;
    if (strstr(name, "os11SignalEvent")) return (void *)signal_event;
    if (strstr(name, "DestroySystemEvent") || strstr(name, "FinalizeEvent") || strstr(name, "FinalizeMutex")) return (void *)destroy;
    CHECK(0);
    return NULL;
}
int main(void) {
    output_test();
    strcpy(g_mod[0].name, "main");
    strcpy(g_mod[1].name, "sdk");
    uint64_t (*get_size)(const void *) = (void *)dm_hle_force_lookup(
        "_ZN2nn5audio30GetAudioRendererWorkBufferSizeERKNS0_22AudioRendererParameterE");
    CHECK(get_size);
    CHECK(get_size(NULL) == 0 && valid_calls == 0 && size_calls == 0);
    uint32_t parameter[14];
    uint8_t *p = (uint8_t *)parameter;
    for (unsigned i = 0; i < sizeof parameter; i++) p[i] = (uint8_t)(i + 1);
    expected_parameter = parameter;
    CHECK(get_size(parameter) == 0 && valid_calls == 1 && size_calls == 0);
    memcpy(expected_internal, p, 0x20);
    expected_internal[0x20] = p[0x20];
    expected_internal[0x22] = p[0x2c];
    expected_internal[0x23] = p[0x30];
    memcpy(expected_internal + 0x24, p + 0x24, 8);
    memcpy(expected_internal + 0x30, p + 0x34, 4);
    accept = 1;
    CHECK(get_size(parameter) == 0x8000 && valid_calls == 2 && size_calls == 1);
    // A second query must use the current parameters, not a cached fixed size.
    p[0] ^= 0x80;
    expected_internal[0] = p[0];
    CHECK(get_size(parameter) == 0x8000 && valid_calls == 3 && size_calls == 2);
    uint32_t (*open_renderer)(handle_t *, void *, const void *, void *, size_t) = (void *)dm_hle_force_lookup(
        "_ZN2nn5audio17OpenAudioRendererEPNS0_19AudioRendererHandleEPNS_2os11SystemEventERKNS0_22AudioRendererParameterEPvm");
    uint32_t (*update_renderer)(handle_t, const void *) = (void *)dm_hle_force_lookup(
        "_ZN2nn5audio26RequestUpdateAudioRendererENS0_19AudioRendererHandleEPKNS0_19AudioRendererConfigE");
    uint32_t (*start_renderer)(handle_t) = (void *)dm_hle_force_lookup("_ZN2nn5audio18StartAudioRendererENS0_19AudioRendererHandleE");
    void (*stop_renderer)(handle_t) = (void *)dm_hle_force_lookup("_ZN2nn5audio17StopAudioRendererENS0_19AudioRendererHandleE");
    void (*close_renderer)(handle_t) = (void *)dm_hle_force_lookup("_ZN2nn5audio18CloseAudioRendererENS0_19AudioRendererHandleE");
    uint32_t (*set_budget)(handle_t, int) = (void *)dm_hle_force_lookup("_ZN2nn5audio34SetAudioRendererRenderingTimeLimitENS0_19AudioRendererHandleEi");
    int (*get_budget)(handle_t) = (void *)dm_hle_force_lookup("_ZN2nn5audio34GetAudioRendererRenderingTimeLimitENS0_19AudioRendererHandleE");
    uint32_t (*execute)(handle_t) = (void *)dm_hle_force_lookup("_ZN2nn5audio29ExecuteAudioRendererRenderingENS0_19AudioRendererHandleE");
    CHECK(open_renderer && update_renderer && start_renderer && stop_renderer && close_renderer && execute && set_budget && get_budget);
    void *allocation = malloc(0x9000);
    void *work = (void *)(((uintptr_t)allocation + 0xfff) & ~(uintptr_t)0xfff);
    handle_t handle = {0};
    int event;
    CHECK(open_renderer(&handle, &event, parameter, work, 0x7000) != 0 && !handle.object && !constructed);
    parameter[11] = parameter[12] = 0; // automatic mode
    expected_internal[0x22] = expected_internal[0x23] = 0;
    init_result = 0x899;
    CHECK(open_renderer(&handle, &event, parameter, work, 0x8000) == init_result);
    CHECK(!handle.object && constructed == 1 && initialized == 1 && destroyed == 3);
    init_result = 0;
    CHECK(!open_renderer(&handle, &event, parameter, work, 0x8000) && handle.object && handle.event == &event && bound == 1);
    expected_config = commands + 32;
    CHECK(!update_renderer(handle, expected_config) && client_calls == 1 && server_calls == 1 && !processed);
    int automatic_before;
    CHECK(!start_renderer(handle) && started == 1);
    CHECK(!update_renderer(handle, expected_config));
    server_result = 0x5299;
    CHECK(update_renderer(handle, expected_config) == server_result);
    server_result = 0;
    CHECK(execute(handle) != 0); // explicit execution is only valid in manual mode
    CHECK(!set_budget(handle, 65) && get_budget(handle) == 65);
    CHECK(set_budget(handle, 101) != 0 && get_budget(handle) == 65);
    int mixed_before=atomic_load(&processed);
    int signals_before=atomic_load(&event_signals);
    struct timespec auto_wait={0,30000000};nanosleep(&auto_wait,NULL);
    CHECK(atomic_load(&worker_attach_calls)==1);
    CHECK(atomic_load(&processed)-mixed_before>=1);
    CHECK(atomic_load(&event_signals)-signals_before>=1);
    stop_renderer(handle);
    automatic_before=atomic_load(&processed);
    CHECK(!update_renderer(handle, expected_config) && atomic_load(&processed)==automatic_before && stopped == 1);
    close_renderer(handle);
    CHECK(finalized == 1 && destroyed == 6 && forgotten == 1);
    CHECK(start_renderer(handle) != 0 && update_renderer(handle, expected_config) != 0);
    // Closed handles do not reach a freed SDK object.
    close_renderer(handle);
    CHECK(finalized == 1);
    parameter[11] = parameter[12] = 1;
    expected_internal[0x22] = expected_internal[0x23] = 1;
    CHECK(!open_renderer(&handle, NULL, parameter, work, 0x8000));
    CHECK(!start_renderer(handle));
    int manual_before=atomic_load(&processed);
    CHECK(!update_renderer(handle, expected_config) && atomic_load(&processed)==manual_before);
    CHECK(!execute(handle) && atomic_load(&processed)==manual_before+1);
    unsigned lookups_before=atomic_load(&symbol_lookups);
    captured_frames=0;captured_peak=0;atomic_store(&device_commands,1);smo_audio_set_output(output_pcm);
    CHECK(!execute(handle) && atomic_load(&processed)==manual_before+3 && output_calls==2);
    CHECK(captured_peak>0 && captured_frames>=480);
    CHECK(atomic_load(&symbol_lookups)==lookups_before); // no symbol table scans in recurring audio frames
    atomic_store(&device_commands,0);smo_audio_set_output(NULL);
    close_renderer(handle);
    write_test_wav();
    parameter[11]=0;expected_internal[0x22]=0;
    memset(commands,0,sizeof commands);
    CHECK(!open_renderer(&handle,NULL,parameter,work,0x8000));
    int prior=atomic_load(&processed);
    struct timespec t0,t1;clock_gettime(CLOCK_MONOTONIC,&t0);
    CHECK(!start_renderer(handle));
    for(int i=0;i<10;i++)CHECK(!update_renderer(handle,expected_config));
    struct timespec wait={0,100000000};nanosleep(&wait,NULL);
    int auto_frames=atomic_load(&processed)-prior;
    clock_gettime(CLOCK_MONOTONIC,&t1);
    /* The 5 ms clock renders late periods back to back, so the count tracks wall time.
     * The ticker thread's clock started before this renderer opened (earlier sessions in
     * this test), so up to 8 owed periods can be caught up immediately after start.
     * An update-driven mix loop would add one frame per update on top of that. */
    long periods=((t1.tv_sec-t0.tv_sec)*1000000000L+(t1.tv_nsec-t0.tv_nsec))/5000000L;
    CHECK(auto_frames>=1 && auto_frames<=periods+8);
    close_renderer(handle);
    free(allocation);
    // Native boot previously aborted while polling this uninitialized event.
    void (*notification)(void *) = (void *)dm_hle_force_lookup(
        "_ZN2nn5audio36AcquireAudioDeviceSwitchNotificationEPNS_2os11SystemEventE");
    int (*list_devices)(void *, int) = (void *)dm_hle_force_lookup(
        "_ZN2nn5audio19ListAudioDeviceNameEPNS0_15AudioDeviceNameEi");
    void (*active_device)(void *) = (void *)dm_hle_force_lookup(
        "_ZN2nn5audio24GetActiveAudioDeviceNameEPNS0_15AudioDeviceNameE");
    int (*active_channels)(void) = (void *)dm_hle_force_lookup(
        "_ZN2nn5audio21GetActiveChannelCountEv");
    CHECK(notification && list_devices && active_device && active_channels);
    int previous_bound = bound;
    notification(&event);
    CHECK(bound == previous_bound + 1 && last_bound == &event);
    struct { uint64_t before; char names[2][0x100]; uint64_t after; } devices;
    memset(&devices, 0xa5, sizeof devices);
    CHECK(list_devices(devices.names, 0) == 0 && devices.names[0][0] == (char)0xa5);
    CHECK(list_devices(NULL, 1) == 0 && list_devices(devices.names, -1) == 0);
    CHECK(list_devices(devices.names, 2) == 1);
    CHECK(!strcmp(devices.names[0], "AudioTvOutput"));
    CHECK(devices.names[0][255] == 0 && devices.names[1][0] == (char)0xa5);
    active_device(devices.names[1]);
    CHECK(!memcmp(devices.names[0], devices.names[1], 0x100));
    CHECK(devices.before == UINT64_C(0xa5a5a5a5a5a5a5a5) && devices.after == devices.before);
    CHECK(active_channels() == 2);
    printf("audio parameter ABI: %s\n", fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;
}
