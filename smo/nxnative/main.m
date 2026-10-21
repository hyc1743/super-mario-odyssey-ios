// nxnative iOS boot adapter: game data and translated shaders live in Documents.
// Derived from nxnative's iOS entry point (MIT, copyright 2026 jhaizhou).
// See third_party/nxnative.LICENSE; the original license also ships in the IPA.
#import <UIKit/UIKit.h>
#import "SMOResources.h"
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

int dm_main(int argc, char **argv);
void dm_host_preload_start(int argc, char **argv);
UIViewController *front_ios_root(void);
void front_ios_focus_event(int ev);
void front_ios_audio_session(void);
static char *g_argv[3];
static BOOL g_ready;
static NSString *g_documents;
static NSDictionary *g_identity;

static void *boot_thread(void *unused) {
    (void)unused;
    static char alt[65536]; stack_t ss = {.ss_sp = alt, .ss_size = sizeof alt}; sigaltstack(&ss, NULL);
    int rc = dm_main(2, g_argv);
    fprintf(stderr, "boot: dm_main returned %d\n", rc);
    return NULL;
}
int front_ios_boot_ok(void) { return g_ready; }
void front_ios_boot(void) {
    static BOOL started;
    if (started || !g_ready) return;
    started = YES; front_ios_audio_session();
    pthread_attr_t attr; pthread_attr_init(&attr); pthread_attr_setstacksize(&attr, 64u << 20);
    pthread_t thread;
    if (!pthread_create(&thread, &attr, boot_thread, NULL)) pthread_detach(thread);
    pthread_attr_destroy(&attr);
}

@interface SMOSetup : UIViewController
@property(nonatomic, strong) UILabel *message;
@property(nonatomic, strong) UIButton *check;
@end
@implementation SMOSetup
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.07 blue:0.12 alpha:1];
    self.message = [UILabel new]; self.message.numberOfLines = 0;
    self.message.textColor = UIColor.whiteColor; self.message.textAlignment = NSTextAlignmentCenter;
    self.message.font = [UIFont systemFontOfSize:17];
    self.check = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.check setTitle:@"Check again / 重新检查" forState:UIControlStateNormal];
    [self.check addTarget:self action:@selector(checkResources) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.message, self.check]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-48],
        [stack.heightAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.heightAnchor constant:-24]]];
    [self checkResources];
}
- (void)checkResources {
    if (!self.check.enabled) return;
    self.check.enabled = NO;
    self.message.text = @"Checking resources / 正在校验资源…\nFiles → On My iPhone → SMO Mobile\nromfs/ + msl/ + resource_manifest.json";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL personal = [g_identity[@"package_kind"] isEqual:@"personal"];
        NSString *manifestPath = [g_documents stringByAppendingPathComponent:@"resource_manifest.json"];
        NSString *manifestHash = SMOFileDigest(manifestPath);
        NSString *markerPath = [g_documents stringByAppendingPathComponent:@"save/smo-verified-resources.plist"];
        NSDictionary *marker = [NSDictionary dictionaryWithContentsOfFile:markerPath];
        const char *recheckEnv = getenv("SMO_RECHECK");
        BOOL recheck = recheckEnv && recheckEnv[0] == '1';
        // Personal builds verify the full resource set once, then trust a marker
        // in Documents/save that records the manifest hash and build identity.
        // The marker survives overwrite installs; changed resources (different
        // manifest) or a forced SMO_RECHECK=1 in env.txt trigger one fresh check.
        BOOL alreadyVerified = personal && !recheck && manifestHash &&
            [marker[@"manifest"] isEqual:manifestHash] &&
            [marker[@"chain"] isEqual:g_identity[@"shader_chain"]] &&
            [marker[@"commit"] isEqual:g_identity[@"nxnative_commit"]];
        NSString *error = nil;
        if (alreadyVerified) {
            fprintf(stderr, "boot: resources already verified; skipping re-check\n");
        } else {
            NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
                               stringByAppendingPathComponent:@"smo-verified-resources.plist"];
            error = g_identity ? SMOCheckResources(g_documents, g_identity, cache, ^(NSUInteger n, NSUInteger total) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.message.text = [NSString stringWithFormat:@"Verifying resources / 正在校验资源\n%lu / %lu", (unsigned long)n, (unsigned long)total];
                });
            }) : @"The app's package identity is missing. Reinstall the IPA.";
            if (!personal) error = [NSString stringWithFormat:@"Pure shell / 纯壳版本\nInstall your personal IPA, then copy the resource folders.\n请安装个人 IPA，再复制资源目录。\n\n%@", error ?: @"Resources verified / 资源校验通过"];
            if (!error && personal) {
                NSDateFormatter *stamp = [NSDateFormatter new];
                stamp.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                [@{@"manifest": manifestHash, @"chain": g_identity[@"shader_chain"], @"commit": g_identity[@"nxnative_commit"],
                   @"verified_at": [stamp stringFromDate:NSDate.date]} writeToFile:markerPath atomically:YES];
            }
        }
        if (error) {
            fprintf(stderr, "boot: %s\n", error.UTF8String);
            dispatch_async(dispatch_get_main_queue(), ^{ self.message.text = error; self.check.enabled = YES; });
            return;
        }
        NSString *res = NSBundle.mainBundle.resourcePath, *dm = [res stringByAppendingPathComponent:@"dm"];
        setenv("DM_ROMFS", [g_documents stringByAppendingPathComponent:@"romfs"].fileSystemRepresentation, 1);
        setenv("DM_MSL_DIR", [g_documents stringByAppendingPathComponent:@"msl"].fileSystemRepresentation, 1);
        setenv("DM_SAVE", [g_documents stringByAppendingPathComponent:@"save"].fileSystemRepresentation, 1);
        setenv("DM_TEMP", [g_documents stringByAppendingPathComponent:@"temp"].fileSystemRepresentation, 1);
        setenv("DM_NVN_SHMAP", [dm stringByAppendingPathComponent:@"shader_map.tsv"].fileSystemRepresentation, 1);
        setenv("DM_FONT_DIR", [dm stringByAppendingPathComponent:@"font"].fileSystemRepresentation, 1);
        g_argv[0] = strdup("dmhost"); g_argv[1] = strdup(dm.fileSystemRepresentation);
        dm_host_preload_start(2, g_argv);
        fprintf(stderr, "boot: resources %s; starting nxnative\n", alreadyVerified ? "already verified (skipped re-check)" : "verified");
        dispatch_async(dispatch_get_main_queue(), ^{ g_ready = YES; self.view.window.rootViewController = front_ios_root(); });
    });
}
- (BOOL)prefersStatusBarHidden { return YES; }
@end

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation SceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [SMOSetup new]; [self.window makeKeyAndVisible];
}
- (void)sceneWillResignActive:(UIScene *)s { front_ios_focus_event(0); }
- (void)sceneDidEnterBackground:(UIScene *)s { front_ios_focus_event(1); }
- (void)sceneWillEnterForeground:(UIScene *)s { front_ios_focus_event(2); }
- (void)sceneDidBecomeActive:(UIScene *)s { front_ios_focus_event(3); }
@end
@interface App : UIResponder <UIApplicationDelegate>
@end
@implementation App
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    return [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        NSFileManager *fm = NSFileManager.defaultManager;
        g_documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        for (NSString *folder in @[@"", @"save", @"temp"])
            [fm createDirectoryAtPath:[g_documents stringByAppendingPathComponent:folder] withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *log = [g_documents stringByAppendingPathComponent:@"log.txt"], *prev = [g_documents stringByAppendingPathComponent:@"log.prev.txt"];
        [fm removeItemAtPath:prev error:nil]; [fm moveItemAtPath:log toPath:prev error:nil];
        if (freopen(log.fileSystemRepresentation, "w", stderr)) setvbuf(stderr, NULL, _IOLBF, 0);
        NSString *identityPath = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"dm/package_identity.json"];
        NSData *identityData = [NSData dataWithContentsOfFile:identityPath];
        if (identityData) g_identity = [NSJSONSerialization JSONObjectWithData:identityData options:0 error:nil];
        // User settings are applied first; verified resource paths are set explicitly afterwards.
        NSString *env = [NSString stringWithContentsOfFile:[g_documents stringByAppendingPathComponent:@"env.txt"] encoding:NSUTF8StringEncoding error:nil];
        for (NSString *raw in [env componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
            NSString *line = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            NSRange eq = [line rangeOfString:@"="];
            if (!line.length || [line hasPrefix:@"#"] || eq.location == NSNotFound || eq.location == 0) continue;
            setenv([line substringToIndex:eq.location].UTF8String, [line substringFromIndex:eq.location + 1].UTF8String, 0);
        }
        chdir(g_documents.fileSystemRepresentation);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(App.class));
    }
}
