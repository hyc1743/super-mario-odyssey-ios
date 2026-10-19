#import "SMOAudio.h"
#import <UIKit/UIKit.h>
#import <AVFAudio/AVFAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#include "audio_output.h"
#include "audio_ring.h"
#include "logbuf.h"
static smo_audio_ring ring;
static _Atomic int accepting,flush;
/* After running dry, wait until ~30 ms are queued before playing again: one short gap
 * instead of a continuous crackle when the producer runs right at the consumption rate. */
enum { PRIME_FRAMES=1440 };
static int primed;
static _Atomic uint64_t callbacks,played;
static uint64_t queued_frames(void){
    uint64_t w=atomic_load_explicit(&ring.write,memory_order_acquire);
    uint64_t r=atomic_load_explicit(&ring.read,memory_order_relaxed);
    return w>=r?w-r:0;
}
static void enqueue(const int16_t *pcm,size_t frames){
    if(atomic_load_explicit(&accepting,memory_order_acquire))smo_audio_ring_push(&ring,pcm,frames);
}
static OSStatus render(void *context,AudioUnitRenderActionFlags *flags,
                       const AudioTimeStamp *time,UInt32 bus,UInt32 frames,AudioBufferList *buffers){
    (void)context;(void)flags;(void)time;(void)bus;
    if(atomic_exchange(&flush,0))atomic_store_explicit(&ring.read,atomic_load_explicit(&ring.write,memory_order_acquire),memory_order_release);
    if(buffers->mNumberBuffers!=1 || !buffers->mBuffers[0].mData ||
       buffers->mBuffers[0].mDataByteSize<frames*4)return kAudio_ParamError;
    uint64_t queued=atomic_load_explicit(&ring.write,memory_order_acquire)-atomic_load_explicit(&ring.read,memory_order_relaxed);
    if(!primed && queued<PRIME_FRAMES){
        memset(buffers->mBuffers[0].mData,0,(size_t)frames*4);
        atomic_fetch_add_explicit(&ring.underrun,frames,memory_order_relaxed);
        atomic_fetch_add_explicit(&callbacks,1,memory_order_relaxed);return noErr;
    }
    primed=1;
    size_t count=smo_audio_ring_pop(&ring,buffers->mBuffers[0].mData,frames);
    if(count<frames)primed=0;
    atomic_fetch_add_explicit(&callbacks,1,memory_order_relaxed);
    atomic_fetch_add_explicit(&played,count,memory_order_relaxed);return noErr;
}
@implementation SMOAudio {
    AudioUnit _unit;
    BOOL _interrupted,_running;
}
+ (void)start {
    static SMOAudio *audio;static dispatch_once_t once;
    dispatch_once(&once,^{audio=[SMOAudio new];[audio install];});
}
- (void)install {
    smo_audio_set_output(enqueue);
    smo_audio_set_suspended(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive);
    NSNotificationCenter *nc=NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(lifecycle:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(lifecycle:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [nc addObserver:self selector:@selector(interruption:) name:AVAudioSessionInterruptionNotification object:nil];
    [nc addObserver:self selector:@selector(reset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
    [self resume];
    [NSTimer scheduledTimerWithTimeInterval:10 repeats:YES block:^(NSTimer *timer){
        (void)timer;dm_log_emit("AUDIO_SPEAKER callbacks=%llu played=%llu underrun=%llu dropped=%llu queued=%llu running=%d",
            (unsigned long long)atomic_load(&callbacks),(unsigned long long)atomic_load(&played),
            (unsigned long long)atomic_load(&ring.underrun),(unsigned long long)atomic_load(&ring.dropped),
            (unsigned long long)queued_frames(),self->_running);
    }];
}
- (BOOL)createUnit {
    AudioComponentDescription description={.componentType=kAudioUnitType_Output,
        .componentSubType=kAudioUnitSubType_RemoteIO,.componentManufacturer=kAudioUnitManufacturer_Apple};
    AudioComponent component=AudioComponentFindNext(NULL,&description);
    OSStatus result=component?AudioComponentInstanceNew(component,&_unit):-1;
    AudioStreamBasicDescription format={.mSampleRate=48000,.mFormatID=kAudioFormatLinearPCM,
        .mFormatFlags=kAudioFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked,
        .mBytesPerPacket=4,.mFramesPerPacket=1,.mBytesPerFrame=4,.mChannelsPerFrame=2,.mBitsPerChannel=16};
    AURenderCallbackStruct callback={render,NULL};
    if(!result)result=AudioUnitSetProperty(_unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input,0,&format,sizeof format);
    if(!result)result=AudioUnitSetProperty(_unit,kAudioUnitProperty_SetRenderCallback,kAudioUnitScope_Input,0,&callback,sizeof callback);
    if(!result)result=AudioUnitInitialize(_unit);
    if(result){if(_unit)AudioComponentInstanceDispose(_unit);_unit=NULL;dm_log_emit("AUDIO_SPEAKER_SETUP_FAILED status=%d",(int)result);return NO;}
    return YES;
}
- (void)resume {
    if(_running || _interrupted || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    AVAudioSession *session=AVAudioSession.sharedInstance;NSError *error=nil;
    if(![session setCategory:AVAudioSessionCategoryPlayback error:&error] ||
       ![session setPreferredSampleRate:48000 error:&error] ||
       ![session setPreferredIOBufferDuration:0.01 error:&error] ||
       ![session setActive:YES error:&error]){
        dm_log_emit("AUDIO_SESSION_FAILED code=%ld",(long)error.code);return;
    }
    if(!_unit && ![self createUnit])return;
    atomic_store(&flush,1);
    OSStatus result=AudioOutputUnitStart(_unit);
    _running=result==noErr;atomic_store_explicit(&accepting,_running,memory_order_release);
    dm_log_emit("AUDIO_SPEAKER_START status=%d rate=48000 channels=2 queued=%llu",(int)result,
                (unsigned long long)queued_frames());
}
- (void)suspend {
    atomic_store_explicit(&accepting,0,memory_order_release);
    if(_unit && _running)AudioOutputUnitStop(_unit);_running=NO;
    [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    dm_log_emit("AUDIO_SPEAKER_SUSPEND queued=%llu",(unsigned long long)queued_frames());
}
- (void)lifecycle:(NSNotification *)note {
    BOOL active=[note.name isEqualToString:UIApplicationDidBecomeActiveNotification];
    smo_audio_set_suspended(!active);dm_log_emit("AUDIO_SPEAKER_LIFECYCLE active=%d",active);
    if(active)[self resume];else [self suspend];
}
- (void)interruption:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(),^{
        self->_interrupted=[note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan;
        dm_log_emit("AUDIO_SPEAKER_INTERRUPTION began=%d",self->_interrupted);
        if(self->_interrupted)[self suspend];else [self resume];
    });
}
- (void)reset:(NSNotification *)note {
    (void)note;dispatch_async(dispatch_get_main_queue(),^{
        dm_log_emit("AUDIO_SPEAKER_MEDIA_RESET");
        [self suspend];if(self->_unit)AudioComponentInstanceDispose(self->_unit);self->_unit=NULL;[self resume];
    });
}
@end
