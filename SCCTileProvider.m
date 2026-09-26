#import "SCCTileProvider.h"

#import <MobileCoreServices/LSApplicationWorkspace.h>

static NSString * const kPrefPath = @"/var/mobile/Library/Preferences/com.qwq.scctile.plist";
static NSString * const kDarwinReloadName = @"com.opa334.ccsupport/ReloadProviders";
static NSString * const kModulePrefix = @"com.qwq.scctile.";

/* 首次运行写入的配置模板（XML 注释可在 Filza 中直接阅读） */
static NSString * const kDefaultConfigXML =
    @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
    @"<plist version=\"1.0\">\n"
    @"<dict>\n"
    @"    <!-- 总开关：false 时全部磁贴隐藏 -->\n"
    @"    <key>enabled</key>\n"
    @"    <true/>\n"
    @"    <!-- 数组里每项 = 一个磁贴，顺序 = 磁贴顺序。\n"
    @"         name:   快捷指令的准确名称（以快捷指令App里的名字为准）\n"
    @"         symbol: 磁贴图标（SF Symbols 名称，可整行删掉用默认图标）\n"
    @"         保存后约 5 秒自动生效：增删磁贴即时生效；\n"
    @"         改名/改图标后若磁贴无变化，注销一次即可 -->\n"
    @"    <key>shortcuts</key>\n"
    @"    <array>\n"
    @"        <dict>\n"
    @"            <key>name</key>\n"
    @"            <string>示例指令A</string>\n"
    @"            <key>symbol</key>\n"
    @"            <string>house.fill</string>\n"
    @"        </dict>\n"
    @"        <dict>\n"
    @"            <key>name</key>\n"
    @"            <string>示例指令B</string>\n"
    @"            <key>symbol</key>\n"
    @"            <string>camera.fill</string>\n"
    @"        </dict>\n"
    @"    </array>\n"
    @"</dict>\n"
    @"</plist>\n";

@implementation SCCTileProvider

#pragma mark - 生命周期

__attribute__((constructor))
static void SCCTileBundleLoad(void)
{
    /* 配置不存在时写入带注释的默认模板 */
    if (![[NSFileManager defaultManager] fileExistsAtPath:kPrefPath]) {
        [kDefaultConfigXML writeToFile:kPrefPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }

    /* 仅 SpringBoard 进程启动配置轮询（Settings 进程也会加载本 bundle） */
    NSString *processName = [[NSProcessInfo processInfo] processName];
    if ([processName containsString:@"SpringBoard"]) {
        NSTimer *timer = [NSTimer timerWithTimeInterval:5.0
                                                 target:[SCCTileProvider class]
                                               selector:@selector(configChangedCheck:)
                                               userInfo:nil
                                                repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    }
}

+ (void)configChangedCheck:(NSTimer *)timer
{
    static NSData *lastData = nil;
    NSData *current = [NSData dataWithContentsOfFile:kPrefPath];
    if (!current) return;

    /* 首次 tick 仅记录基线，之后内容有变化才通知 CCSupport 重载模块列表 */
    if (lastData && ![current isEqualToData:lastData]) {
        [SCCTileProvider notifyCCSupportReload];
    }
    lastData = current;
}

+ (void)notifyCCSupportReload
{
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kDarwinReloadName,
                                         NULL, NULL, TRUE);
}

#pragma mark - 配置解析

/* 规范化条目：name + symbol；兼容纯字符串写法（只填名字） */
+ (NSArray<NSDictionary *> *)normalizedEntries
{
    NSDictionary *config = [self loadConfig];
    if (!config) return @[];
    if (![config[@"enabled"] boolValue]) return @[];

    NSArray *raw = config[@"shortcuts"];
    if (![raw isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    for (id item in raw) {
        NSString *name = nil;
        NSString *symbol = @"";
        if ([item isKindOfClass:[NSString class]]) {
            name = item;
        } else if ([item isKindOfClass:[NSDictionary class]]) {
            name = item[@"name"];
            id sym = item[@"symbol"];
            if ([sym isKindOfClass:[NSString class]]) symbol = sym;
        }
        if ([name isKindOfClass:[NSString class]] && name.length > 0) {
            [entries addObject:@{ @"name": name, @"symbol": symbol }];
        }
    }
    return [entries copy];
}

+ (NSDictionary *)loadConfig
{
    NSData *data = [NSData dataWithContentsOfFile:kPrefPath];
    if (!data) return nil;
    return [NSPropertyListSerialization propertyListWithData:data
                                                     options:NSPropertyListImmutable
                                                      format:nil
                                                       error:nil];
}

#pragma mark - 运行快捷指令

+ (void)runShortcutNamed:(NSString *)name
{
    if (name.length == 0) return;

    NSMutableCharacterSet *allowed = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowed removeCharactersInString:@"?/&=+"];
    NSString *encoded = [name stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    if (!encoded) return;

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"shortcuts://run-shortcut?name=%@", encoded]];
    if (!url) return;

    NSError *error = nil;
    [[LSApplicationWorkspace defaultWorkspace] openURL:url withOptions:nil error:&error];
#ifdef SCCTILE_DEBUG
    NSLog(@"[SCCTile] run shortcut %@ error=%@", name, error);
#endif
}

#pragma mark - 磁贴配色

+ (NSArray<UIColor *> *)palette
{
    static NSArray<UIColor *> *palette = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        palette = @[
            [UIColor systemBlueColor],
            [UIColor systemOrangeColor],
            [UIColor systemPurpleColor],
            [UIColor systemGreenColor],
            [UIColor systemPinkColor],
            [UIColor systemYellowColor],
            [UIColor systemRedColor],
            [UIColor systemTealColor],
            [UIColor systemIndigoColor],
            [UIColor systemCyanColor],
        ];
    });
    return palette;
}

#pragma mark - CCSModuleProvider

- (NSUInteger)numberOfProvidedModules
{
    return [[SCCTileProvider normalizedEntries] count];
}

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index
{
    return [NSString stringWithFormat:@"%@%lu", kModulePrefix, (unsigned long)index];
}

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier
{
    if (![identifier hasPrefix:kModulePrefix]) return nil;

    NSString *indexPart = [identifier substringFromIndex:[kModulePrefix length]];
    NSInteger index = [indexPart integerValue];
    if (index < 0) return nil;

    NSArray<NSDictionary *> *entries = [SCCTileProvider normalizedEntries];
    if ((NSUInteger)index >= [entries count]) return nil;

    NSDictionary *entry = [entries objectAtIndex:(NSUInteger)index];
    return [[SCCTileShortcutModule alloc] initWithName:entry[@"name"]
                                                symbol:entry[@"symbol"]
                                            colorIndex:(NSUInteger)index];
}

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if (![identifier hasPrefix:kModulePrefix]) return @"快捷指令";

    NSString *indexPart = [identifier substringFromIndex:[kModulePrefix length]];
    NSInteger index = [indexPart integerValue];

    NSArray<NSDictionary *> *entries = [SCCTileProvider normalizedEntries];
    if ((NSUInteger)index < [entries count]) {
        return [entries objectAtIndex:(NSUInteger)index][@"name"];
    }
    return @"快捷指令";
}

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier
{
    NSString *symbol = @"square.stack.3d.up.fill";
    if ([identifier hasPrefix:kModulePrefix]) {
        NSString *indexPart = [identifier substringFromIndex:[kModulePrefix length]];
        NSInteger index = [indexPart integerValue];
        NSArray<NSDictionary *> *entries = [SCCTileProvider normalizedEntries];
        if ((NSUInteger)index < [entries count]) {
            NSString *entrySymbol = [entries objectAtIndex:(NSUInteger)index][@"symbol"];
            if (entrySymbol.length > 0) symbol = entrySymbol;
        }
    }
    return [UIImage systemImageNamed:symbol];
}

@end
