/* SCCTileModuleShared.m  (v1.2.0)
 * 静态 bundle 模块（/Library/ControlCenter/Bundles 通路，已在 TA 设备验证可用）。
 * 同一份源码编 6 个 bundle，SLOT 宏区分（1..6），类名随之唯一。
 *
 * 自研能力（零第三方依赖）：
 *  - 执行引擎：WFSpringBoardWorkflowRunnerClient（系统后台执行客户端，全后台无 UI）
 *  - 图标渲染：直读 Shortcuts.sqlite（ZSHORTCUTICON.ZGLYPHNUMBER/ZBACKGROUNDCOLORVALUE）
 *              经 WFWorkflowIcon + WFWorkflowIconDrawer 渲染成指令自己的彩色图标
 *  - 配置：    /var/mobile/Library/Preferences/com.qwq.scctile.plist（enabled + shortcuts[{name}]） */

#import <UIKit/UIKit.h>
#import <sqlite3.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <notify.h>

/* 基类最小声明（实现在 ControlCenterUIKit.framework，链接触达即可） */
@interface CCUIToggleModule : NSObject
- (BOOL)isSelected;
- (void)setSelected:(BOOL)selected;
- (void)refreshState;
- (void)reconfigureView;
- (UIImage *)iconGlyph;
- (UIImage *)selectedIconGlyph;
- (UIColor *)selectedColor;
@end

static NSString * const kPrefPath = @"/var/mobile/Library/Preferences/com.qwq.scctile.plist";
static NSString * const kCachePath = @"/var/mobile/Library/Preferences/com.qwq.scctile.cache.plist";
static NSString * const kRefreshNotification = @"com.qwq.scctile/refresh";
static NSString * const kDefaultSymbol = @"square.stack.3d.up.fill";

#pragma mark - 文件日志（Filza 直接可读，>256KB 自动清）

static void SCTLogFormat(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    static NSString * const kLogPath = @"/var/mobile/Library/SCCTile.log";
    NSString *line = [NSString stringWithFormat:@"[%@][%@] %@\n",
                      [[NSDate date] descriptionWithLocale:nil],
                      [[NSProcessInfo processInfo] processName],
                      message];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:kLogPath error:nil];
    if ([attrs fileSize] > 256 * 1024) [fm removeItemAtPath:kLogPath error:nil];

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
    if (!handle) {
        [line writeToFile:kLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [handle seekToEndOfFile];
    [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

#pragma mark - 配置读取

static NSDictionary *SCTConfig(void)
{
    NSData *data = [NSData dataWithContentsOfFile:kPrefPath];
    if (!data) return nil;
    return [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil];
}

/* slot 从 0 计；返回该槽位指令名，未配置返回 nil */
static NSString *SCTNameForSlot(NSUInteger slot)
{
    NSDictionary *config = SCTConfig();
    if (![config[@"enabled"] boolValue]) return nil;

    NSArray *shortcuts = [config isKindOfClass:[NSDictionary class]] ? config[@"shortcuts"] : nil;
    if (!shortcuts || slot >= [shortcuts count]) return nil;

    id item = [shortcuts objectAtIndex:slot];
    if ([item isKindOfClass:[NSString class]] && [item length] > 0) return item;
    if ([item isKindOfClass:[NSDictionary class]]) {
        NSString *name = [item objectForKey:@"name"];
        if ([name length] > 0) return name;
    }
    return nil;
}

#pragma mark - 指令目录（读 sctiled 发布的缓存 plist）

/* 缓存由 sctiled 守护进程维护：name -> { "uuid", "glyph", "color" } */
static NSDictionary<NSString *, NSDictionary *> *sctCatalog = nil;
static dispatch_once_t sctCatalogOnce;

static NSDictionary<NSString *, NSDictionary *> *SCTCatalog(void)
{
    dispatch_once(&sctCatalogOnce, ^{
        NSDictionary *cache = [NSDictionary dictionaryWithContentsOfFile:kCachePath];
        NSDictionary *catalog = cache[@"catalog"];
        if ([catalog isKindOfClass:[NSDictionary class]]) {
            sctCatalog = catalog;
            SCTLogFormat(@"CATALOG loaded from cache count=%lu updated=%@",
                         (unsigned long)[catalog count], cache[@"updated"]);
            for (NSString *k in catalog) {
                NSDictionary *e = catalog[k];
                SCTLogFormat(@"CATALOG item \"%@\" uuid=%@ glyph=%@ color=%@", k, e[@"uuid"], e[@"glyph"], e[@"color"]);
            }
        } else {
            sctCatalog = @{};
            SCTLogFormat(@"CATALOG cache missing or invalid");
        }
    });
    return sctCatalog;
}

static void SCTRequestRefresh(void)
{
    notify_post(kRefreshNotification.UTF8String);
}

#pragma mark - 图标渲染（WorkflowKit：WFWorkflowIcon + WFWorkflowIconDrawer）

static Class sctWorkflowIconClass = Nil;
static Class sctWorkflowIconDrawerClass = Nil;
static BOOL sctRenderersReady = NO;

static void SCTPrepareRenderers(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *wk = dlopen("/System/Library/PrivateFrameworks/WorkflowKit.framework/WorkflowKit", RTLD_LAZY | RTLD_LOCAL);
        void *vsc = wk ? dlopen("/System/Library/PrivateFrameworks/VoiceShortcutClient.framework/VoiceShortcutClient", RTLD_LAZY | RTLD_LOCAL) : NULL;
        (void)vsc;

        sctWorkflowIconClass = NSClassFromString(@"WFWorkflowIcon");
        sctWorkflowIconDrawerClass = NSClassFromString(@"WFWorkflowIconDrawer");
        SCTLogFormat(@"RENDERER wk=%p vsc=%p iconClass=%@ drawerClass=%@",
                     wk, vsc, sctWorkflowIconClass ? @"YES" : @"NO", sctWorkflowIconDrawerClass ? @"YES" : @"NO");
        if (!sctWorkflowIconClass || !sctWorkflowIconDrawerClass) return;

        sctRenderersReady =
            [sctWorkflowIconClass instancesRespondToSelector:NSSelectorFromString(@"initWithBackgroundColorValue:glyphCharacter:customImageData:")] &&
            [sctWorkflowIconDrawerClass instancesRespondToSelector:NSSelectorFromString(@"initWithIcon:")] &&
            [sctWorkflowIconDrawerClass instancesRespondToSelector:NSSelectorFromString(@"imageWithSize:scale:")];
        SCTLogFormat(@"RENDERER ready=%d", sctRenderersReady);
    });
}

static UIImage *SCTImageFromRendered(id rendered, CGFloat scale)
{
    if ([rendered isKindOfClass:[UIImage class]]) return rendered;

    for (NSString *selName in @[@"UIImage", @"untintedUIImage", @"platformImage"]) {
        SEL sel = NSSelectorFromString(selName);
        if (![rendered respondsToSelector:sel]) continue;
        id candidate = ((id (*)(id, SEL))objc_msgSend)(rendered, sel);
        if ([candidate isKindOfClass:[UIImage class]]) return candidate;
    }
    for (NSString *selName in @[@"CGImage", @"internalCGImage"]) {
        SEL sel = NSSelectorFromString(selName);
        if (![rendered respondsToSelector:sel]) continue;
        CGImageRef cg = ((CGImageRef (*)(id, SEL))objc_msgSend)(rendered, sel);
        if (cg) {
            UIImage *image = [UIImage imageWithCGImage:cg scale:scale orientation:UIImageOrientationUp];
            if (image.size.width > 0) return image;
        }
    }
    SEL pngSel = NSSelectorFromString(@"PNGRepresentation");
    if ([rendered respondsToSelector:pngSel]) {
        NSData *png = ((id (*)(id, SEL))objc_msgSend)(rendered, pngSel);
        if ([png isKindOfClass:[NSData class]] && png.length > 0) return [UIImage imageWithData:png scale:scale];
    }
    return nil;
}

static UIImage *SCTRenderWorkflowIcon(NSNumber *colorValue, uint16_t glyphNumber, CGSize size)
{
    if (!sctRenderersReady || glyphNumber == 0) return nil;

    @try {
        id icon = ((id (*)(id, SEL, int64_t, uint16_t, id))objc_msgSend)(
            [sctWorkflowIconClass alloc],
            NSSelectorFromString(@"initWithBackgroundColorValue:glyphCharacter:customImageData:"),
            colorValue.longLongValue,
            glyphNumber,
            nil);
        if (!icon) return nil;

        id drawer = ((id (*)(id, SEL, id))objc_msgSend)(
            [sctWorkflowIconDrawerClass alloc],
            NSSelectorFromString(@"initWithIcon:"),
            icon);
        if (!drawer) return nil;

        CGFloat scale = MAX([UIScreen mainScreen].scale, 1.0);
        id rendered = ((id (*)(id, SEL, CGSize, CGFloat))objc_msgSend)(
            drawer, NSSelectorFromString(@"imageWithSize:scale:"), size, scale);
        if (!rendered) {
            SEL alt = NSSelectorFromString(@"imageWithSize:");
            if ([drawer respondsToSelector:alt]) {
                rendered = ((id (*)(id, SEL, CGSize))objc_msgSend)(drawer, alt, size);
            }
        }
        if (!rendered) return nil;

        UIImage *image = SCTImageFromRendered(rendered, scale);
        if (![image isKindOfClass:[UIImage class]] || image.size.width <= 0) return nil;
        return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    } @catch (NSException *exception) {
        NSLog(@"[SCCTile] ICON_RENDER_EXCEPTION glyph=%u reason=%@", glyphNumber, exception.reason);
        return nil;
    }
}

/* 磁贴图标：指令自带彩色图标 → 失败回退默认 symbol（原色白，CC 负责着色） */
static UIImage *SCTIconForSlot(NSUInteger slot)
{
    SCTPrepareRenderers();

    NSString *name = SCTNameForSlot(slot);
    NSDictionary *entry = name ? [SCTCatalog() objectForKey:name] : nil;

    NSNumber *colorValue = entry[@"color"];
    NSNumber *glyph = entry[@"glyph"];
    SCTLogFormat(@"ICON slot=%lu name=%@ entry=%@ glyph=%@", (unsigned long)slot, name, entry ? @"YES" : @"NO", glyph);
    UIImage *image = nil;
    if (glyph) {
        image = SCTRenderWorkflowIcon(
            colorValue ?: @0xFF4055B4, /* 默认蓝 */
            (uint16_t)[glyph unsignedIntValue],
            CGSizeMake(30.0, 30.0));
    }
    if (image) {
        SCTLogFormat(@"ICON rendered OK (slot=%lu)", (unsigned long)slot);
        return image;
    }
    SCTLogFormat(@"ICON fallback to default symbol (slot=%lu)", (unsigned long)slot);
    return [UIImage systemImageNamed:kDefaultSymbol];
}

static UIColor *SCTColorForSlot(NSUInteger slot)
{
    NSString *name = SCTNameForSlot(slot);
    NSDictionary *entry = name ? [SCTCatalog() objectForKey:name] : nil;
    NSNumber *colorValue = entry[@"color"];
    if (![colorValue isKindOfClass:[NSNumber class]]) return [UIColor systemBlueColor];

    uint32_t rgba = [colorValue unsignedIntValue];
    CGFloat red = ((rgba >> 24) & 0xFF) / 255.0;
    CGFloat green = ((rgba >> 16) & 0xFF) / 255.0;
    CGFloat blue = ((rgba >> 8) & 0xFF) / 255.0;
    CGFloat alpha = (rgba & 0xFF) / 255.0;
    if (alpha <= 0.0) alpha = 1.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

#pragma mark - 执行引擎（WFSpringBoardWorkflowRunnerClient，系统后台执行客户端）

static id sctActiveRunner = nil;
static BOOL sctRunnerLoaded = NO;

static BOOL SCTLoadRunnerFrameworks(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *wk = dlopen("/System/Library/PrivateFrameworks/WorkflowKit.framework/WorkflowKit", RTLD_LAZY | RTLD_LOCAL);
        void *vsc = wk ? dlopen("/System/Library/PrivateFrameworks/VoiceShortcutClient.framework/VoiceShortcutClient", RTLD_LAZY | RTLD_LOCAL) : NULL;
        sctRunnerLoaded = (wk != NULL && vsc != NULL);
        if (!sctRunnerLoaded) NSLog(@"[SCCTile] RUNNER_FRAMEWORK_LOAD_FAILED");
    });
    return sctRunnerLoaded;
}

static void SCTPollRunner(id runner, NSUInteger attempt, BOOL observedRunning)
{
    NSTimeInterval interval = attempt < 10 ? 1.0 : 5.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (sctActiveRunner != runner) return;

        BOOL running = NO;
        @try {
            running = [runner isRunning];
        } @catch (NSException *exception) {
            NSLog(@"[SCCTile] RUNNER_STATUS_EXCEPTION reason=%@", exception.reason);
            sctActiveRunner = nil;
            return;
        }

        if (!running) {
            sctActiveRunner = nil; /* 完成（或未启动） */
            return;
        }
        SCTPollRunner(runner, attempt + 1, YES);
    });
}

static BOOL SCTRunNamed(NSString *name, NSString *workflowIdentifier)
{
    SCTLogFormat(@"RUN begin name=%@ uuid=%@", name, workflowIdentifier);
    if (!workflowIdentifier || !SCTLoadRunnerFrameworks()) {
        SCTLogFormat(@"RUN abort: no uuid or frameworks not loaded -> request refresh");
        SCTRequestRefresh();
        return NO;
    }

    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:workflowIdentifier];
    if (!uuid) {
        SCTLogFormat(@"RUN abort: uuid parse failed");
        return NO;
    }

    if (sctActiveRunner) {
        BOOL running = NO;
        @try { running = [sctActiveRunner isRunning]; } @catch (__unused NSException *e) { sctActiveRunner = nil; }
        if (running) return NO; /* 上一条还在跑，忽略本次 */
        sctActiveRunner = nil;
    }

    Class runnerClass = NSClassFromString(@"WFSpringBoardWorkflowRunnerClient");
    SEL initializer = NSSelectorFromString(@"initWithWorkflowIdentifier:");
    if (!runnerClass || ![runnerClass instancesRespondToSelector:initializer]) {
        SCTLogFormat(@"RUN abort: runner class/selector unavailable (class=%@)", runnerClass ? @"YES" : @"NO");
        return NO;
    }

    @try {
        id runner = ((id (*)(id, SEL, NSString *))objc_msgSend)(
            [runnerClass alloc], initializer, uuid.UUIDString);
        if (!runner) return NO;
        sctActiveRunner = runner;
        ((void (*)(id, SEL))objc_msgSend)(runner, NSSelectorFromString(@"start"));
        SCTLogFormat(@"RUN started OK name=%@", name);
        SCTPollRunner(runner, 0, NO);
        return YES;
    } @catch (NSException *exception) {
        sctActiveRunner = nil;
        NSLog(@"[SCCTile] RUNNER_START_EXCEPTION reason=%@", exception.reason);
        return NO;
    }
}

#pragma mark - 模块类（宏展开，类名 = SCCTileModule<SLOT>）

#define SCT_STR2(x) #x
#define SCT_CAT2(a,b) a##b
#define SCT_CAT(a,b) SCT_CAT2(a,b)

#ifndef SLOT
#error "SLOT must be defined (1..6)"
#endif

@interface SCT_CAT(SCCTileModule, SLOT) : CCUIToggleModule
@end

@implementation SCT_CAT(SCCTileModule, SLOT)

+ (void)load
{
    /* 首次运行写带注释的配置模板（幂等） */
    if (![[NSFileManager defaultManager] fileExistsAtPath:kPrefPath]) {
        NSString *xml =
            @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
            @"<plist version=\"1.0\">\n"
            @"<dict>\n"
            @"    <!-- 总开关：false 时全部磁贴失效 -->\n"
            @"    <key>enabled</key>\n"
            @"    <true/>\n"
            @"    <!-- 数组第 N 项 = 磁贴「快捷指令N」的指令。\n"
            @"         每行一条：把 string 里的文字改成你快捷指令的名字（一字不差）。\n"
            @"         图标自动使用指令自己的彩色图标，无需任何额外配置。\n"
            @"         数组不足 6 项时，多余磁贴点击无效果。\n"
            @"         改完保存后注销一次生效 -->\n"
            @"    <key>shortcuts</key>\n"
            @"    <array>\n"
            @"        <string>打卡</string>\n"
            @"        <string>示例指令B</string>\n"
            @"    </array>\n"
            @"</dict>\n"
            @"</plist>\n";
        [xml writeToFile:kPrefPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }

    /* 预热：读缓存；缓存缺失时请 daemon 刷新 */
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        BOOL binOk = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/usr/libexec/sctiled"];
        NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.qwq.scctile.plist"];
        BOOL cacheOk = [[NSFileManager defaultManager] fileExistsAtPath:kCachePath];
        SCTLogFormat(@"DAEMON diag binary=%@ stateFile=%@ resolverState=%@ resolverMsg=%@ cache=%@",
                     binOk ? @"YES" : @"NO",
                     state ? @"YES" : @"NO",
                     state[@"ResolverState"] ?: @"(nil)",
                     state[@"ResolverMessage"] ?: @"(nil)",
                     cacheOk ? @"YES" : @"NO");
        if (!cacheOk) {
            SCTLogFormat(@"BOOT cache missing -> request refresh");
            SCTRequestRefresh();
        }
        SCTCatalog();
    });
}

- (NSUInteger)sctSlot
{
    return (NSUInteger)(SLOT - 1);
}

- (UIImage *)iconGlyph
{
    return SCTIconForSlot([self sctSlot]);
}

- (UIImage *)selectedIconGlyph
{
    return [self iconGlyph];
}

- (UIColor *)selectedColor
{
    return SCTColorForSlot([self sctSlot]);
}

- (BOOL)isSelected
{
    return NO; /* 瞬时磁贴，无驻留选中态 */
}

- (void)setSelected:(BOOL)selected
{
    if (!selected) return;

    NSUInteger slot = [self sctSlot];
    NSString *name = SCTNameForSlot(slot);
    SCTLogFormat(@"TAP slot=%lu name=%@", (unsigned long)slot, name);
    if (![name length]) return;

    NSDictionary *entry = [SCTCatalog() objectForKey:name];
    SCTRunNamed(name, entry[@"uuid"]);

    /* 立即回弹：视图按 isSelected=NO 重绘 */
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshState];
        [self reconfigureView];
    });
}

@end
