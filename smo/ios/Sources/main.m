// SMO Mobile —— iOS App 壳。
//
// 现状：报告「移植做到哪一步」+「游戏文件在不在」（用与宿主同一份的 romfs_resolve 逻辑），
// 并把宿主的**日志环形缓冲**显示在屏幕上（未接电脑也能看）。宿主启动在下一轮接入。

#import <UIKit/UIKit.h>
#import "SMOMetalView.h"
#import "SMOTouchController.h"
#import "SMOAudio.h"
#import "SMOFramePacer.h"
#import "nvn_metal_private.h"
#include <fcntl.h>      // open/O_RDONLY（HexHead 走 POSIX 读，要 errno）
#include <stdio.h>
#include <string.h>
#include <unistd.h>     // read/close/usleep
#include "logbuf.h"
#include "logsum.h"
#include "romfs_resolve.h"
#include "smoarc.h"
#include "dm.h"
#include "hle.h"
#include "hle_thread.h"
#include "nvn_shader.h"
#include "nvn_shader_archive.h"
extern void dm_jump_guest(void *arg, void *fn);
void dm_crash_install(void);        // crashlog.c：信号 → PC/LR/帧链写进日志

// 上一次运行是否崩了（启动时看上一轮日志里有没有崩溃/FATAL/异常标记；见 AppDelegate）
static BOOL g_prevCrashed;

// ---- 宿主引导（后台线程跑；日志进环形缓冲，前台定时刷新显示） ----

// 数「真实条目」：容器卷（RomFS.smoa.N）与展开标记不算 —— 只有卷不算「已展开」
static unsigned CountRealEntries(NSFileManager *fm, NSString *dir) {
    unsigned n = 0;
    for (NSString *e in [fm contentsOfDirectoryAtPath:dir error:nil] ?: @[]) {
        if ([e hasPrefix:@"RomFS.smoa."] || [e isEqualToString:@".smoa-done"]) continue;
        n++;
    }
    return n;
}

// 5.5 GB 展开要几分钟：每 100 个文件一行，屏幕上能看见在动
static void PackProgress(void *user, unsigned done, const char *name) {
    unsigned long long total = user ? *(const unsigned long long *)user : 0;
    if (total && done % 10 == 0) {
        char d[160];
        snprintf(d, sizeof d, "%.1f / %.1f GB · %u 个文件", smoarc_bytes_done() / 1e9, total / 1e9, done);
        dm_progress_frac((double)smoarc_bytes_done() / (double)total, d);
    }
    if (done % 100) return;
    LOG("  容器展开：%u 个文件（%s）", done, name ? name : "");
}

// 文件头若干字节的十六进制（拷坏时靠它对照：正确的大小与头字节写在 STATUS/说明里）
static NSString *HexHead(NSString *path, NSUInteger n) {
    // 走 POSIX open/read：NSFileHandle 失败时什么都不说，而这里我们**需要** errno ——
    // 「卷大小对、内容读不到」是真机上反复遇到的情况，得区分「文件坏了」还是「还没落盘」。
    // 失败再试三次：用「文件」App 拷贝/下载大文件时，读会在落盘完成前失败。
    int fd = -1;
    for (int try = 0; try < 3; try++) {
        fd = open(path.fileSystemRepresentation, O_RDONLY);
        if (fd >= 0) break;
        if (try == 2) return [NSString stringWithFormat:@"（打不开：errno %d %s）", errno, strerror(errno)];
        usleep(300 * 1000);
    }
    unsigned char b[16];
    ssize_t r = read(fd, b, n <= sizeof b ? n : sizeof b);
    int e = errno;
    close(fd);
    if (r <= 0) return [NSString stringWithFormat:@"（读不到内容：read=%zd errno=%d %s —— 文件还没落盘？）",
                                                 r, e, strerror(e)];
    NSMutableString *s = [NSMutableString string];
    for (ssize_t i = 0; i < r; i++) [s appendFormat:@"%02x ", b[i]];
    return s;
}

static void RunHost(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *docs = [fm URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask
                    appropriateForURL:nil create:NO error:nil];
    char ep[1024];
    if (!docs || !dm_exefs_path(ep, sizeof ep, docs.path.UTF8String)) {
        LOG("App：Documents 里没有 ExeFS —— 只显示状态页（把改写产物放进「文件」App 的 SMOMobile/ExeFS）");
        dm_progress_stage(1, 6, "检查游戏文件");
        dm_progress_finish(DM_RUN_FAIL, "没找到 ExeFS：用「文件」App 把游戏文件放进 SMOMobile");
        return;
    }
    // ---- 资源容器：把 RomFS.smoa.N 卷展开成真正的目录树 ----
    // 卷在哪、要展开到哪 —— 判断在 smoarc_plan()（C，能进 CI 单测）。它认三种形状，第三种
    // （Documents/<包装目录>/RomFS/RomFS.smoa.N）就是我们自己打的包的形状：上一版不认它，
    // 手机上根本没展开，RomFS 目录里只有两个卷，游戏一读文件就崩。
    // 标记文件 .smoa-done 放在卷旁边（不放 RomFS 目录里，免得被游戏的目录列举撞上）。
    NSFileManager *fm2 = NSFileManager.defaultManager;
    NSURL *docs2 = [fm2 URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask
                      appropriateForURL:nil create:NO error:nil];
    dm_progress_stage(1, 6, "检查游戏文件");
    if (docs2) {
        char vols[24][1024], target[1024], base[1024];   // 卷上限 24：小卷（512 MB/1 GB）也够用
        unsigned nvols = smoarc_plan(docs2.path.UTF8String, vols, 24, target, sizeof target,
                                     base, sizeof base);
        if (nvols) {
            const char *volp[24];
            for (unsigned i = 0; i < nvols; i++) volp[i] = vols[i];
            NSString *targetS = [NSString stringWithUTF8String:target];
            // 标记放在 RomFS 的**父目录**：三种形状下 target 都是「.../RomFS」，父目录即包装目录。
            // 不放进 RomFS 里面 —— 游戏会列举目录，树里多一个点文件是没必要的风险。
            NSString *marker = [[targetS stringByDeletingLastPathComponent]
                                 stringByAppendingPathComponent:@".smoa-done"];
            if ([fm2 fileExistsAtPath:marker]) {
                LOG("容器：%s 已展开过（.smoa-done），跳过", target);
            } else {
                // 走到这里就必定是「卷在、树没展开」：smoarc_plan 只在确实找到卷时才返回非 0。
                // 上一版把「目录里有东西」当成「已展开」，用户手机上顶层有一个不相干的条目，
                // 于是展开被跳过 —— RomFS 里一个游戏文件都没有。判据不能这么松。
                // 先报每个卷的大小与头字节：拷坏（截断 / 传输过程改了字节 / 拷的是旧文件）时，
                // 这两项立刻就能对照出来（源：卷 0 = 3218914442 字节，头 53 4d 4f 41 00 02；
                // 卷 1 = 2286390220 字节，头 53 4d 4f 41 01 02）。
                for (unsigned i = 0; i < nvols; i++) {
                    NSString *vp = [NSString stringWithUTF8String:volp[i]];
                    NSError *err = nil;
                    NSDictionary *at = [fm2 attributesOfItemAtPath:vp error:&err];
                    // 注意：LOG 走的是 C 的 vsnprintf —— %@ 它不认识，会打出空字符串（真机上
                    // 「头」那栏一直空着就是这个原因）。要用 %s + .UTF8String。
                    // （不再打「源应为」：分卷大小随打包参数变，写死的数字过时过一次；对照用电脑上的卷）
                    LOG("  卷 %u：%llu 字节，改于 %s，头 %s", i, [at fileSize],
                        [[at fileModificationDate] description].UTF8String ?: "?",
                        HexHead(vp, 8).UTF8String ?: "?");
                    (void)err;
                }
                static unsigned long long totalBytes;
                totalBytes = 0;
                for (unsigned i = 0; i < nvols; i++)
                    totalBytes += [[fm2 attributesOfItemAtPath:[NSString stringWithUTF8String:volp[i]]
                                                         error:nil] fileSize];
                dm_progress_stage(2, 6, "首次运行：解开游戏资源（只做一次，约几分钟）");
                dm_progress_frac(0, "准备中");
                [fm2 createDirectoryAtPath:targetS withIntermediateDirectories:YES attributes:nil error:nil];
                LOG("首次运行：展开 RomFS 容器 %u 卷 → %s（5.5 GB，几分钟；每 100 个文件一行）",
                    nvols, target);
                int rc = smoarc_extract_cb(target, volp, nvols, PackProgress, &totalBytes);
                LOG("展开结果：%d（0 = 成功；-1 格式错；-2 读写错）—— %s", rc, smoarc_error());
                if (rc == 0) {
                    [[NSString stringWithFormat:@"vols=%u\n", nvols] writeToFile:marker atomically:YES
                                                                         encoding:NSUTF8StringEncoding error:nil];
                } else {
                    LOG("【红】展开没成功（见上一行的原因）—— 先别进游戏：重拷一遍卷，或看看手机剩余空间");
                    // 失败后做一次**只读**全卷体检：不写文件（空间不够也能跑），
                    // 一次数清「几千条里坏了几条、第一条是哪个」。
                    LOG("整卷校验（只读，不写盘）……");
                    char why[600];
                    snprintf(why, sizeof why, "解开资源失败：%s", smoarc_error());
                    dm_progress_stage(2, 6, "解开失败，正在检查资源卷（只读）");
                    int badv = smoarc_verify_cb(volp, nvols, PackProgress, &totalBytes);
                    LOG("整卷校验结果：%d（-1 = 卷打不开/格式错；0 = 全部完好）；%s", badv, smoarc_error());
                    dm_progress_finish(DM_RUN_FAIL, why);
                    return;
                }
            }
        }
    }
    // RomFS 里到底有没有东西：只有卷没展开时，进了游戏就是一路读文件失败，最后以莫名其妙的崩溃收场。
    // 这里直接拦下并把原因写清楚（比让用户拿个崩溃报告猜省事得多）。
    {
        char rp[1024];
        if (!dm_romfs_path(rp, sizeof rp, docs.path.UTF8String)) {
            LOG("【红】Documents 里没有 RomFS（放好 RomFS 目录，或 RomFS.smoa.N 卷）");
            dm_progress_finish(DM_RUN_FAIL, "没找到 RomFS（游戏资源）");
            return;
        }
        unsigned n = CountRealEntries(fm, [NSString stringWithUTF8String:rp]);
        LOG("RomFS：%s（顶层 %u 个条目）", rp, n);
        if (!n) {
            LOG("【红】RomFS 目录里没有展开的内容（只剩容器卷？）—— 见上面的展开日志");
            dm_progress_finish(DM_RUN_FAIL, "RomFS 里没有内容（资源没解开）");
            return;
        }
        // 完整的 RomFS 只有十几个顶层目录：少的时候把名字列出来，一眼看出是没展开还是拷少了
        if (n <= 16) {
            NSArray *es = [[fm contentsOfDirectoryAtPath:[NSString stringWithUTF8String:rp] error:nil]
                           sortedArrayUsingSelector:@selector(compare:)];
            for (NSString *e in es) LOG("   · %s", e.UTF8String);
        }
        // Discovery and fs HLE must use the same directory, including wrapped
        // layouts such as Documents/SMO Resource/RomFS.
        NSString *save = [docs.path stringByAppendingPathComponent:@"SMOSaves"];
        NSString *temp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SMO"];
        NSError *pathError = nil;
        if (![fm createDirectoryAtPath:save withIntermediateDirectories:YES attributes:nil error:&pathError] ||
            ![fm createDirectoryAtPath:temp withIntermediateDirectories:YES attributes:nil error:&pathError]) {
            LOG("无法建立存档或临时目录：%s", pathError.localizedDescription.UTF8String);
            dm_progress_finish(DM_RUN_FAIL, "无法建立游戏数据目录");
            return;
        }
        if (setenv("SMO_ROMFS", rp, 1) || setenv("SMO_SAVE", save.fileSystemRepresentation, 1) ||
            setenv("SMO_TEMP", temp.fileSystemRepresentation, 1)) {
            dm_progress_finish(DM_RUN_FAIL, "无法设置游戏资源路径");
            return;
        }
        LOG("文件服务已接入 RomFS：%s", rp);
    }
    NSString *fontDirectory = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"SharedFonts"];
    setenv("SMO_FONT_DIR", fontDirectory.fileSystemRepresentation, 1);
    NSString *shaderDirectory = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"RuntimeShaders"];
    NSString *shaderIndex = [shaderDirectory stringByAppendingPathComponent:@"shaders.idx"];
    NSString *shaderArchive = [shaderDirectory stringByAppendingPathComponent:@"shaders.smoa"];
    int shaderFiles=nvn_shader_archive_open(shaderArchive.fileSystemRepresentation);
    if(shaderFiles<=0){
        LOG("IOS_RUNTIME_SHADER_ARCHIVE_INVALID");
        dm_progress_finish(DM_RUN_FAIL, "着色器资源包不完整，请重新安装测试包");
        return;
    }
    LOG("IOS_RUNTIME_SHADER_ARCHIVE_READY entries=%d",shaderFiles);
    if (setenv("SMO_SHADER_DIR", shaderDirectory.fileSystemRepresentation, 1) ||
        setenv("SMO_SHADER_IDX", shaderIndex.fileSystemRepresentation, 1)) {
        dm_progress_finish(DM_RUN_FAIL, "无法设置着色器资源路径");
        return;
    }
    /* 真机诊断捕获（只写 Documents，可用「文件」App 导出，随日志一起提交）：
     * 着色器失配样本（shader-*.bin）、每帧画面 PPM、绘制状态/可见性、Metal 错误详情。
     * 代价是每帧一次同步回读（约几 MB），只用于定位黑屏/闪退的测试轮。 */
    NSString *diagnostics = [docs.path stringByAppendingPathComponent:@"SMODiagnostics"];
    [fm createDirectoryAtPath:diagnostics withIntermediateDirectories:YES attributes:nil error:NULL];
    setenv("SMO_SHADER_CAPTURE_DIR", diagnostics.fileSystemRepresentation, 1);
    setenv("SMO_FRAME_CAPTURE_DIR", diagnostics.fileSystemRepresentation, 1);
    /* C constructors run before NSBundle paths are available. Reload explicitly
     * before entering any guest code; the CLI constructor keeps its own path. */
    nvn_shader_reset();
    int shaderCount = nvn_shader_load(shaderIndex.fileSystemRepresentation);
    if (shaderCount <= 0) {
        LOG("IOS_RUNTIME_SHADERS_MISSING");
        dm_progress_finish(DM_RUN_FAIL, "安装包缺少着色器资源，请安装完整测试包");
        return;
    }
    LOG("IOS_RUNTIME_SHADERS_LOADED rows=%d", shaderCount);
    LOG("== SMO 宿主（App 内）：从 %s 装载 ==", ep);
    // 不装 rtld：宿主自己扮演 rtld（映射/重定位/DT_INIT 都在 loader_core.c），而 rtld 的 32 条重定位
    // 落在代码段边界页里，按三段装不了（smo/ios/tools/x0_layout.py）。参考项目同样只装游戏模块。
    static const char *names[] = { "sdk", "subsdk0", "main" };
    // 引导顺序只有一处：host_boot()（与 CLI 宿主同一份）。上一版这里把 run_module_inits 写在了
    // svc_thread_main_init 前面 —— 客体第一个构造函数就去读线程/TLS 环境，真机上一跑就崩。
    void *fn = host_boot(ep, names, 3, "nnMain");
    if (!fn) {
        dm_progress_finish(DM_RUN_FAIL, "游戏程序没装起来");   // host_boot 已报过具体原因时这句不会盖掉它
        return;
    }
    dm_progress_frac(-1, "游戏在跑（还没有画面：图形层没接上）");
    dm_jump_guest(NULL, fn);
    LOG("== 客体入口返回了（正常游戏里 nnMain 不会返回）==");
    dm_progress_finish(DM_RUN_WAIT, "游戏入口返回了（不该返回）");
}

// 各子系统状态。写在代码里，改的时候顺手改，别让它和 STATUS.md 对不上。
static NSArray<NSArray<NSString *> *> *kSubsystems(void) {
    return @[
        @[@"游戏文件解包（NSP → ExeFS / RomFS）", @"已完成"],
        @[@"模块侦察（导入 / 图形入口 / 着色器位置）", @"已完成"],
        @[@"程序改写（4 个 NSO，含动态等价性）", @"已完成"],
        @[@"着色器翻译（18470 个 → SPIR-V → MSL）", @"已完成"],
        @[@"宿主加载器（文件与三段内嵌两条路径）", @"已完成"],
        @[@"内核 svc + fs/oe/hid 服务", @"部分"],
        @[@"图形层（NVN → Metal，离屏验证中）", @"进行中"],
        @[@"双摇杆触屏手柄", @"进行中"],
        @[@"扬声器 PCM 音频输出", @"进行中"],
    ];
}

// 最近日志（宿主的环形缓冲 logbuf.c；与宿主共用同一份代码，逻辑有 CI 自检）
static NSString *RecentLog(void) {
    char buf[16384];
    size_t n = dm_log_dump(buf, sizeof buf);
    if (!n) return @"（暂无宿主日志）";
    // 注意：日志里若混进非法 UTF-8，stringWithUTF8String: 会返回 nil；而 nil 一旦进
    // NSMutableArray 就抛 NSInvalidArgumentException 直接终止进程（真机第七崩）。
    // 两层兜底：UTF-8 不行就退到 Latin-1（字节一对一映射，永不失败）。
    NSString *s = [[NSString alloc] initWithBytes:buf length:n encoding:NSUTF8StringEncoding];
    if (!s) s = [[NSString alloc] initWithBytes:buf length:n encoding:NSISOLatin1StringEncoding];
    return s ?: @"（日志读不出来）";
}

// C 串 → NSString。注意 NSString 的 %s 不按 UTF-8 解（按系统编码），中文会变乱码：一律走这里 + %@
static NSString *U(const char *c) {
    if (!c) return @"";
    NSString *s = [NSString stringWithUTF8String:c];
    return s ?: ([NSString stringWithCString:c encoding:NSISOLatin1StringEncoding] ?: @"");
}

// 屏上只看最近 n 行（完整的在导出日志里）
static NSString *RecentLogTail(NSUInteger n) {
    NSArray<NSString *> *ls = [RecentLog() componentsSeparatedByString:@"\n"];
    NSMutableArray<NSString *> *keep = [NSMutableArray array];
    for (NSString *l in ls) if (l.length) [keep addObject:l];
    if (keep.count > n) [keep removeObjectsInRange:NSMakeRange(0, keep.count - n)];
    return [keep componentsJoinedByString:@"\n"];
}

// 在 App 自己的目录里找游戏文件。装包流程与参考项目一致：资源放在 App 的目录里，
// 由「文件」App 或 Finder 拷进去。
static NSString *ScanDocuments(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *docs = [fm URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask
                    appropriateForURL:nil create:NO error:nil];
    if (!docs) return @"读不到自己的目录";
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:docs.path error:nil] ?: @[];
    NSUInteger exefs = 0, romfs = 0, shader = 0;
    for (NSString *it in items) {
        NSString *name = it.lastPathComponent;
        if ([name isEqualToString:@"ExeFS"]) exefs++;
        if ([name isEqualToString:@"RomFS"]) romfs++;
        if ([name isEqualToString:@"ShaderData"]) shader++;
        // 也接受「一层目录里装着 ExeFS/RomFS」的放法
        NSString *sub = [docs.path stringByAppendingPathComponent:it];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:sub isDirectory:&isDir] && isDir) {
            if ([fm fileExistsAtPath:[sub stringByAppendingPathComponent:@"ExeFS"]]) exefs++;
            if ([fm fileExistsAtPath:[sub stringByAppendingPathComponent:@"RomFS"]]) romfs++;
        }
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"目录：%@", docs.path]];
    [lines addObject:[NSString stringWithFormat:@"顶层条目 %lu 个", (unsigned long)items.count]];
    [lines addObject:[NSString stringWithFormat:@"ExeFS：%@", exefs ? @"找到" : @"没有"]];
    [lines addObject:[NSString stringWithFormat:@"RomFS：%@", romfs ? @"找到" : @"没有"]];
    [lines addObject:[NSString stringWithFormat:@"ShaderData：%@", shader ? @"找到" : @"没有"]];
    char rp[1024], ep[1024];
    if (dm_romfs_path(rp, sizeof rp, docs.path.UTF8String))
        [lines addObject:[NSString stringWithFormat:@"RomFS 路径（宿主同款解析）：%@", U(rp)]];
    if (dm_exefs_path(ep, sizeof ep, docs.path.UTF8String))
        [lines addObject:[NSString stringWithFormat:@"ExeFS 路径（宿主同款解析）：%@", U(ep)]];
    if (!exefs || !romfs) {
        [lines addObject:@""];
        [lines addObject:@"把你自己游戏里的 ExeFS 与 RomFS 目录放到这里（用「文件」App 或 Finder），"];
        [lines addObject:@"放好之后回来看这一页。"];
    }
    [lines addObject:@""];
    [lines addObject:@"注意：即使文件放好了，现在也进不了游戏——宿主与图形层还没接上。"];
    return [lines componentsJoinedByString:@"\n"];
}

@interface SMOViewController : UIViewController
@end

// 屏幕只放「用户要知道的」：现在第几步、做到多少、要不要导出日志、最近几行日志。
// 完整的东西（状态、文件、全量带时间戳日志、stderr、上一轮日志）都在「导出日志」里。
@implementation SMOViewController {
    SMOTouchController *_touchController;
    UIButton *_powerMode;
    UIButton *_layoutMode;
    SMOMetalView *_gameView;
    UIStackView *_statusColumn;
    UIButton *_displayLogs;
    UILabel *_title, *_step, *_detail, *_hint, *_banner;
    UIProgressView *_bar;
    UIActivityIndicatorView *_spin;
    UITextView *_tail;
    UIButton *_export, *_more;
    BOOL _showAll;
    // 「卡住了没有」：日志行数与展开字节都不变的时长
    unsigned _lastLines;
    unsigned long long _lastBytes;
    double _quietSince;
    // 剩余时间：本步开始的时刻与进度
    int _stepSeen;
    double _stepT0;
}

static UILabel *MakeLabel(CGFloat size, UIFontWeight w, UIColor *c) {
    UILabel *l = [[UILabel alloc] init];
    l.font = [UIFont systemFontOfSize:size weight:w];
    l.textColor = c;
    l.numberOfLines = 0;
    l.adjustsFontForContentSizeCategory = YES;
    return l;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _gameView=[[SMOMetalView alloc] initWithFrame:self.view.bounds];
    _gameView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_gameView];
    _touchController=[[SMOTouchController alloc] initWithFrame:self.view.bounds];
    _touchController.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _touchController.hidden=YES;[self.view addSubview:_touchController];
    __weak SMOMetalView *weakGameView=_gameView;
    nvn_metal_set_frame_sink(^(id<MTLTexture> texture,int interval,uint64_t ordinal){
        [weakGameView offerTexture:texture interval:interval ordinal:ordinal];
    });
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.10 alpha:1.0];
    UIColor *dim = [UIColor colorWithWhite:0.62 alpha:1.0];

    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    _title = MakeLabel(15, UIFontWeightSemibold, [UIColor colorWithWhite:0.92 alpha:1.0]);
    _title.text = [NSString stringWithFormat:@"SMO Mobile  v%@", info[@"CFBundleShortVersionString"] ?: @"?"];
    _banner = MakeLabel(14, UIFontWeightSemibold, UIColor.whiteColor);
    _banner.backgroundColor = [UIColor colorWithRed:0.55 green:0.12 blue:0.12 alpha:1.0];
    _banner.layer.cornerRadius = 8;
    _banner.layer.masksToBounds = YES;
    _banner.textAlignment = NSTextAlignmentCenter;
    _banner.hidden = YES;
    _step = MakeLabel(20, UIFontWeightBold, UIColor.whiteColor);
    _bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _bar.trackTintColor = [UIColor colorWithWhite:0.22 alpha:1.0];
    _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spin.color = dim;
    _spin.hidesWhenStopped = YES;
    _detail = MakeLabel(14, UIFontWeightRegular, dim);
    _hint = MakeLabel(15, UIFontWeightSemibold, UIColor.whiteColor);
    _hint.layer.cornerRadius = 8;
    _hint.layer.masksToBounds = YES;
    _hint.textAlignment = NSTextAlignmentCenter;

    _export = [UIButton buttonWithType:UIButtonTypeSystem];
    [_export setTitle:@"导出日志" forState:UIControlStateNormal];
    [_export setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _export.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _export.layer.cornerRadius = 10;
    [_export addTarget:self action:@selector(exportLog) forControlEvents:UIControlEventTouchUpInside];

    _more = [UIButton buttonWithType:UIButtonTypeSystem];
    [_more setTitle:@"显示全部" forState:UIControlStateNormal];
    _more.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    [_more addTarget:self action:@selector(toggleMore) forControlEvents:UIControlEventTouchUpInside];

    _tail = [[UITextView alloc] init];
    _tail.editable = NO;
    _tail.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    _tail.layer.cornerRadius = 8;
    _tail.textColor = [UIColor colorWithWhite:0.80 alpha:1.0];
    _tail.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    _tail.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);

    UIStackView *barRow = [[UIStackView alloc] initWithArrangedSubviews:@[_bar, _spin]];
    barRow.axis = UILayoutConstraintAxisHorizontal;
    barRow.alignment = UIStackViewAlignmentCenter;
    barRow.spacing = 10;
    UIStackView *btnRow = [[UIStackView alloc] initWithArrangedSubviews:@[_export, _more]];
    btnRow.axis = UILayoutConstraintAxisHorizontal;
    btnRow.spacing = 12;
    UIStackView *col = [[UIStackView alloc] initWithArrangedSubviews:
                        @[_title, _banner, _step, barRow, _detail, _hint, btnRow, _tail]];
    col.axis = UILayoutConstraintAxisVertical;
    col.spacing = 12;
    [col setCustomSpacing:4 afterView:barRow];
    col.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:col];
    _statusColumn=col;
    _displayLogs=[UIButton buttonWithType:UIButtonTypeSystem];
    [_displayLogs setTitle:@"日志" forState:UIControlStateNormal];
    _displayLogs.backgroundColor=[UIColor colorWithWhite:0 alpha:0.65];
    [_displayLogs setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _displayLogs.layer.cornerRadius=8;_displayLogs.hidden=YES;
    _displayLogs.translatesAutoresizingMaskIntoConstraints=NO;
    [_displayLogs addTarget:self action:@selector(toggleDisplayLogs) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_displayLogs];
    _powerMode=[UIButton buttonWithType:UIButtonTypeSystem];
    [_powerMode setTitle:@"60 帧" forState:UIControlStateNormal];
    [_powerMode setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _powerMode.backgroundColor=[UIColor colorWithWhite:0 alpha:0.65];_powerMode.layer.cornerRadius=8;
    _powerMode.hidden=YES;_powerMode.translatesAutoresizingMaskIntoConstraints=NO;
    [_powerMode addTarget:self action:@selector(togglePowerMode) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:_powerMode];
    _layoutMode=[UIButton buttonWithType:UIButtonTypeSystem];
    [_layoutMode setTitle:_touchController.isThreeDLayout?@"3D":@"2D" forState:UIControlStateNormal];
    [_layoutMode setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _layoutMode.backgroundColor=[UIColor colorWithWhite:0 alpha:0.65];_layoutMode.layer.cornerRadius=8;
    _layoutMode.hidden=YES;_layoutMode.translatesAutoresizingMaskIntoConstraints=NO;
    [_layoutMode addTarget:self action:@selector(toggleTouchLayout) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:_layoutMode];
    __weak SMOViewController *displayController=self;
    _gameView.onFirstFrame=^{
        SMOViewController *controller=displayController;
        if(controller){controller->_statusColumn.hidden=YES;controller->_displayLogs.hidden=NO;controller->_touchController.hidden=controller->_touchController.hasExternalController;controller->_powerMode.hidden=NO;controller->_layoutMode.hidden=NO;}
    };

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_powerMode.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [_powerMode.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [_powerMode.widthAnchor constraintEqualToConstant:100],
        [_powerMode.heightAnchor constraintEqualToConstant:36],
        [_layoutMode.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [_layoutMode.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [_layoutMode.widthAnchor constraintEqualToConstant:64],
        [_layoutMode.heightAnchor constraintEqualToConstant:36],
        [_displayLogs.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
        [_displayLogs.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [_displayLogs.widthAnchor constraintEqualToConstant:64],
        [_displayLogs.heightAnchor constraintEqualToConstant:36],
        [col.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [col.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [col.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
        [col.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
        [_export.heightAnchor constraintEqualToConstant:44],
        [_export.widthAnchor constraintEqualToConstant:140],
        [_banner.heightAnchor constraintGreaterThanOrEqualToConstant:36],
        [_hint.heightAnchor constraintGreaterThanOrEqualToConstant:40],
    ]];
    [_tail setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];

    if (g_prevCrashed) {
        _banner.text = @"上一次运行中途退出了（崩溃）\n点「导出日志」—— 会带上上一次的完整日志";
        _banner.hidden = NO;
    }

    [self refresh];
    __weak SMOViewController *weakSelf = self;
    [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        (void)t;
        [weakSelf refresh];
    }];
}

- (void)toggleMore {
    _showAll = !_showAll;
    [_more setTitle:_showAll ? @"只看最近" : @"显示全部" forState:UIControlStateNormal];
    [self refresh];
}
- (void)toggleDisplayLogs {
    _statusColumn.hidden=!_statusColumn.hidden;
    _touchController.hidden=!_statusColumn.hidden || _touchController.hasExternalController;
}
- (void)togglePowerMode {
    SMOFramePacer *pacer=SMOFramePacer.shared;pacer.powerSaving=!pacer.powerSaving;
    [_powerMode setTitle:pacer.powerSaving?@"省电 30 帧":@"60 帧" forState:UIControlStateNormal];
}
- (void)toggleTouchLayout {
    [_touchController toggleLayout];
    [_layoutMode setTitle:_touchController.isThreeDLayout?@"3D":@"2D" forState:UIControlStateNormal];
}

static NSString *FmtDuration(double s) {
    if (s < 60) return [NSString stringWithFormat:@"%.0f 秒", s];
    return [NSString stringWithFormat:@"%.0f 分 %02.0f 秒", floor(s / 60), fmod(s, 60)];
}

- (void)refresh {
    if(_statusColumn.hidden){UIApplication.sharedApplication.idleTimerDisabled=YES;return;}
    dm_progress_t p;
    dm_progress_get(&p);
    unsigned long long bytes = smoarc_bytes_done();

    // 卡住判定：日志行数和展开字节都不动
    if (p.lines != _lastLines || bytes != _lastBytes) {
        _lastLines = p.lines;
        _lastBytes = bytes;
        _quietSince = p.elapsed;
    }
    double quiet = p.elapsed - _quietSince;
    if (p.step != _stepSeen) { _stepSeen = p.step; _stepT0 = p.elapsed; }

    _step.text = p.steps ? [NSString stringWithFormat:@"第 %d/%d 步：%@", p.step, p.steps, U(p.name)]
                         : @"准备中……";
    if (p.frac >= 0) {
        [_bar setProgress:(float)p.frac animated:YES];
        [_spin stopAnimating];
    } else {
        [_bar setProgress:0 animated:NO];
        if (p.state == DM_RUN_BUSY) [_spin startAnimating]; else [_spin stopAnimating];
    }

    NSMutableString *d = [NSMutableString string];
    if (p.detail[0]) [d appendString:U(p.detail)];
    if (p.frac > 0.02 && p.frac < 1 && p.state == DM_RUN_BUSY) {
        double used = p.elapsed - _stepT0;
        double left = used / p.frac * (1 - p.frac);
        [d appendFormat:@"%@%.0f%% · 还要约 %@", d.length ? @"\n" : @"", p.frac * 100, FmtDuration(left)];
    }
    [d appendFormat:@"%@已运行 %@", d.length ? @"\n" : @"", FmtDuration(p.elapsed)];
    if (p.red) [d appendFormat:@" · 红色告警 %u 条", p.red];
    _detail.text = d;

    // 该不该导出日志 —— 这是用户最关心的一句话，颜色区分
    NSString *hint;
    UIColor *bg;
    BOOL exportNow = NO;
    if (p.state == DM_RUN_FAIL) {
        hint = [NSString stringWithFormat:@"出错停下了：%@\n请点「导出日志」发给开发者", U(p.msg)];
        bg = [UIColor colorWithRed:0.55 green:0.12 blue:0.12 alpha:1.0];
        exportNow = YES;
    } else if (p.state == DM_RUN_WAIT || (p.step == p.steps && p.steps && quiet >= 15)) {
        hint = p.msg[0] ? [NSString stringWithFormat:@"%@\n现在可以导出日志了", U(p.msg)]
                        : @"已走到目前能走的最远处（还没有画面是正常的）\n现在可以导出日志了";
        bg = [UIColor colorWithRed:0.10 green:0.36 blue:0.20 alpha:1.0];
        exportNow = YES;
    } else if (quiet >= 60) {
        hint = [NSString stringWithFormat:@"已经 %@ 没有动静，可能卡住了\n可以导出日志", FmtDuration(quiet)];
        bg = [UIColor colorWithRed:0.55 green:0.38 blue:0.08 alpha:1.0];
        exportNow = YES;
    } else {
        hint = @"正在进行，请等待\n保持 App 在前台、不要锁屏";
        bg = [UIColor colorWithWhite:0.18 alpha:1.0];
    }
    _hint.text = hint;
    _hint.backgroundColor = bg;
    _bar.progressTintColor = p.state == DM_RUN_FAIL ? UIColor.systemRedColor : UIColor.systemGreenColor;
    _export.backgroundColor = exportNow || g_prevCrashed ? UIColor.systemBlueColor
                                                         : [UIColor colorWithWhite:0.25 alpha:1.0];
    // 忙的时候别让屏幕自动锁上（锁屏后 App 被挂起，展开就停了）
    UIApplication.sharedApplication.idleTimerDisabled = (p.state == DM_RUN_BUSY);

    // 日志区：默认只看最近 12 行；「显示全部」= 原来的完整状态页
    BOOL atBottom = _tail.contentOffset.y >= _tail.contentSize.height - _tail.bounds.size.height - 20;
    _tail.text = _showAll ? [self statusText] : RecentLogTail(12);
    if (!_showAll || atBottom) [_tail scrollRangeToVisible:NSMakeRange(_tail.text.length, 0)];
}

static NSString *ReadTextFile(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return s ?: [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
}

- (void)exportLog {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *docs = [fm URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask
                    appropriateForURL:nil create:YES error:nil];
    NSString *stamp = [NSDateFormatter localizedStringFromDate:NSDate.date
                                                     dateStyle:NSDateFormatterShortStyle
                                                     timeStyle:NSDateFormatterMediumStyle];
    stamp = [stamp stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    stamp = [stamp stringByReplacingOccurrencesOfString:@":" withString:@"."];
    NSString *name = [NSString stringWithFormat:@"SMO-log-%@.txt", stamp];
    NSURL *url = [docs URLByAppendingPathComponent:name];

    // 详细版：进度摘要 + 状态页 + 全量落盘日志（带时间戳，不受屏上 512 行限制）+ stderr + 上一轮日志
    dm_progress_t p;
    dm_progress_get(&p);
    NSMutableString *text = [NSMutableString string];
    static const char *kState[] = { "进行中", "已到头", "出错" };
    [text appendFormat:@"== 导出时的进度 ==\n第 %d/%d 步：%@\n状态：%@ %@\n本步进度：%.0f%%  %@\n"
                        "已运行 %.1f 秒；日志 %u 行；红色告警 %u 条；最后一行日志在 %.1f 秒\n\n",
        p.step, p.steps, U(p.name), U(kState[p.state < 3 ? p.state : 0]), U(p.msg),
        p.frac < 0 ? 0 : p.frac * 100, U(p.detail), p.elapsed, p.lines, p.red, p.last_log];
    [text appendString:[self statusText]];
    NSString *dir = docs.path;
    NSString *live = ReadTextFile([dir stringByAppendingPathComponent:@"SMO-log-live.txt"]);
    [text appendFormat:@"\n\n== 完整日志（本次运行，[秒] 为启动后时间）==\n%@",
        live ?: @"（没有 SMO-log-live.txt）"];
    NSString *err = ReadTextFile([dir stringByAppendingPathComponent:@"SMO-stderr.txt"]);
    if (err.length) [text appendFormat:@"\n\n== stderr（系统库消息）==\n%@", err];
    NSString *prev = ReadTextFile([dir stringByAppendingPathComponent:@"SMO-log-previous.txt"]);
    if (prev.length) [text appendFormat:@"\n\n== 上一次运行的日志%@ ==\n%@",
                         g_prevCrashed ? @"（上一次崩溃了）" : @"", prev];

    NSError *werr = nil;
    if (![text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&werr]) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"导出失败"
                                    message:werr.localizedDescription ?: @"?"
                                    preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }
    // 同时留一份固定名的最新日志（方便你在「文件」App 里直接翻）
    [text writeToURL:[docs URLByAppendingPathComponent:@"SMO-log-latest.txt"]
          atomically:YES encoding:NSUTF8StringEncoding error:nil];
    // 摘要：日志到几 MB 之后，回传最实用的其实这一份（同类消息合并计数 + 错误行 + 尾部原文）。
    // 只有几十 KB，聊天窗口也能直接发。
    NSMutableArray<NSURL *> *items = [NSMutableArray arrayWithObject:url];
    {
        NSString *sumName = [name stringByReplacingOccurrencesOfString:@"SMO-log-"
                                                           withString:@"SMO-log-summary-"];
        NSURL *sumURL = [docs URLByAppendingPathComponent:sumName];
        char errbuf[256] = {0};
        if (dm_log_summarize(url.path.UTF8String, sumURL.path.UTF8String, errbuf, sizeof errbuf) == 0) {
            [items addObject:sumURL];
            LOG("导出摘要 → %s", sumName.UTF8String ?: "?");
        } else {
            LOG("【红】摘要生成失败：%s", errbuf[0] ? errbuf : "原因不明");
        }
    }
    UIActivityViewController *avc = [[UIActivityViewController alloc]
        initWithActivityItems:items applicationActivities:nil];
    avc.popoverPresentationController.sourceView = _export;   // iPad 上不给锚点会直接崩
    [self presentViewController:avc animated:YES completion:nil];
}

- (NSString *)statusText {
    UIDevice *dev = UIDevice.currentDevice;
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSMutableArray<NSString *> *out = [NSMutableArray array];

    [out addObject:@"SMO Mobile — iOS 兼容层"];
    [out addObject:@"（把你自己买的 Switch 版《超级马里奥 奥德赛》跑到 iPhone 上）"];
    [out addObject:@""];
    [out addObject:[NSString stringWithFormat:@"版本 %@ (%@)",
                    info[@"CFBundleShortVersionString"] ?: @"?",
                    info[@"CFBundleVersion"] ?: @"?"]];
    [out addObject:[NSString stringWithFormat:@"设备 %@ / %@ %@", dev.model,
                    dev.systemName, dev.systemVersion]];
    [out addObject:[NSString stringWithFormat:@"本机标识 %@", dev.identifierForVendor.UUIDString]];
    [out addObject:@""];
    [out addObject:@"== 移植进度（详见仓库 STATUS.md）=="];
    for (NSArray<NSString *> *row in kSubsystems()) {
        NSString *mark = [row[1] isEqualToString:@"已完成"] ? @"[✓]"
                       : ([row[1] isEqualToString:@"进行中"] ? @"[~]" : @"[ ]");
        [out addObject:[NSString stringWithFormat:@"%@ %@ —— %@", mark, row[0], row[1]]];
    }
    [out addObject:@""];
    [out addObject:@"== 游戏文件 =="];
    [out addObject:ScanDocuments()];
    [out addObject:@""];
    [out addObject:@"== 宿主日志 =="];
    [out addObject:RecentLog()];
    [out addObject:@""];
    [out addObject:@"== 这个壳是什么 =="];
    [out addObject:@"不模拟 CPU：游戏自己的 aarch64 程序将来会在本机直接执行。"];
    [out addObject:@"本仓库不含任何游戏内容；游戏文件由你自己提供。"];
    [out addObject:@"本项目与 Nintendo 无关。MIT 许可。"];
    return [out componentsJoinedByString:@"\n"];
}

@end

// 未捕获的 Objective-C 异常：消息默认只进 stderr（真机上没人看得到），这里写进日志。
// 真机第七崩（NSInvalidArgumentException: object cannot be nil）就是靠 stderr 文件才拿到消息的 ——
// 有了它就不用绕那一圈。（注意：NSSetUncaughtExceptionHandler 收的是**函数指针**，不是 block。）
static void SMOUncaughtException(NSException *e) {
    LOG("【ObjC 异常】%s: %s", e.name.UTF8String ?: "?", e.reason.UTF8String ?: "?");
    for (NSString *line in e.callStackSymbols) LOG("  %s", line.UTF8String ?: "?");
}

@interface SMOAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SMOAppDelegate

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    // 日志实时落盘到 Documents/SMO-log-live.txt（崩溃也留得下；导出按钮里也会带上）
    NSString *liveLog = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                          stringByAppendingPathComponent:@"SMO-log-live.txt"];
    if (liveLog) {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *prev = [liveLog.stringByDeletingLastPathComponent
                          stringByAppendingPathComponent:@"SMO-log-previous.txt"];
        if ([fm fileExistsAtPath:liveLog]) {
            NSData *d = [NSData dataWithContentsOfFile:liveLog];
            NSString *t = d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil;
            g_prevCrashed = t && ([t containsString:@"【崩溃】"] || [t containsString:@"FATAL"] ||
                                  [t containsString:@"【ObjC 异常】"]);
            [fm removeItemAtPath:prev error:nil];
            [fm moveItemAtPath:liveLog toPath:prev error:nil];
        }
        dm_log_set_file(liveLog.UTF8String);
    }
    // 系统级 stderr 单独落一个文件：libsystem / malloc / musl 的断言消息默认只走 stderr，
    // 真机上没有终端就永远看不到（真机第七崩的 SIGABRT 就是系统库发的，消息丢了）。
    if (liveLog) {
        NSString *errPath = [liveLog.stringByDeletingLastPathComponent
                             stringByAppendingPathComponent:@"SMO-stderr.txt"];
        if (errPath) freopen(errPath.UTF8String, "w", stderr);
    }
    dm_crash_install();             // 崩溃也留现场（信号 + PC/LR + 帧链 → SMO-log-live.txt）
    NSSetUncaughtExceptionHandler(&SMOUncaughtException);
    SMOFramePacer *pacer=SMOFramePacer.shared;
    nvn_metal_set_frame_pacer(^(int interval){[pacer waitForFrame:interval];});
    [SMOAudio start];

    self.window.rootViewController = [[SMOViewController alloc] init];
    [self.window makeKeyAndVisible];
    // 宿主引导放后台：不得阻塞主线程（引导 + 客体入口会一直跑）
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ RunHost(); });
    return YES;
}

@end

int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(SMOAppDelegate.class));
    }
}
