/* SCCTileModuleShared.m
 * 静态 bundle 模块（照 RefreshRateCC 的 iOS16 rootless 验证通路）。
 * 同一份源码编 6 个 bundle，SLOT 宏区分（1..6），类名随之唯一。 */

#import <UIKit/UIKit.h>
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import <spawn.h>
#import <signal.h>
#import <sys/wait.h>
#import <crt_externs.h>

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

/* SpringCuts (rootless) 提供的后台运行工具：
 * springcuts -r "指令名" -i  → 全后台执行（走 siriactionsd，不弹快捷指令 App） */
static NSString * const kSpringCutsTool = @"/var/jb/usr/bin/springcuts";

#pragma mark - 配置读取（各 bundle 私有 static 副本）

static NSString * const kPrefPath = @"/var/mobile/Library/Preferences/com.qwq.scctile.plist";

static NSDictionary *SCTConfig(void)
{
    NSData *data = [NSData dataWithContentsOfFile:kPrefPath];
    if (!data) return nil;
    return [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil];
}

/* slot 从 0 计；返回该槽位的指令条目 {name, symbol}，未配置返回 nil */
static NSDictionary *SCTEntry(NSUInteger slot)
{
    NSDictionary *config = SCTConfig();
    if (![config[@"enabled"] boolValue]) return nil;

    NSArray *shortcuts = [config isKindOfClass:[NSDictionary class]] ? config[@"shortcuts"] : nil;
    if (!shortcuts || slot >= [shortcuts count]) return nil;

    id item = [shortcuts objectAtIndex:slot];
    if ([item isKindOfClass:[NSString class]]) {
        return @{@"name": item};
    }
    if ([item isKindOfClass:[NSDictionary class]] && [item objectForKey:@"name"]) {
        return item;
    }
    return nil;
}

/* 通过 SpringCuts 的 CLI 后台运行指令（siriactionsd 引擎，无 App 启动、无感知） */
static void SCTSpawnSpringCuts(NSString *name)
{
    const char *tool = kSpringCutsTool.UTF8String;
    const char *argv[] = {tool, "-r", name.UTF8String, "-i", NULL};

    pid_t pid = -1;
    int rc = posix_spawn(&pid, tool, NULL, NULL, (char *const *)argv, *_NSGetEnviron());
    if (rc == 0 && pid > 0) {
        /* 回收子进程避免僵尸（springcuts 瞬时退出） */
        int status = 0;
        waitpid(pid, &status, 0);
    }
}

static void SCTRunSlot(NSUInteger slot)
{
    NSDictionary *entry = SCTEntry(slot);
    NSString *name = [entry objectForKey:@"name"];
    if (![name length]) return;

    SCTSpawnSpringCuts(name);
}


/* 首次运行写带注释的配置模板（幂等）——定义在使用处之后，供 +load 调用 */
static void SCTWriteDefaultConfigIfMissing(void)
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:kPrefPath]) return;

    static NSString * const kDefaultConfigXML =
        @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
        @"<plist version=\"1.0\">\n"
        @"<dict>\n"
        @"    <!-- 总开关：false 时全部磁贴失效 -->\n"
        @"    <key>enabled</key>\n"
        @"    <true/>\n"
        @"    <!-- 数组第 N 项 = 磁贴「快捷指令N」的指令。\n"
        @"         name:   快捷指令的准确名称（以快捷指令App里的名字为准）\n"
        @"         symbol: 磁贴图标（SF Symbols 名称，可整行删掉用默认图标）\n"
        @"         数组不足 6 项时，多余磁贴点击无效果。\n"
        @"         保存后重新进入控制中心生效（改图标需注销一次） -->\n"
        @"    <key>shortcuts</key>\n"
        @"    <array>\n"
        @"        <dict><key>name</key><string>示例指令A</string><key>symbol</key><string>house.fill</string></dict>\n"
        @"        <dict><key>name</key><string>示例指令B</string><key>symbol</key><string>camera.fill</string></dict>\n"
        @"    </array>\n"
        @"</dict>\n"
        @"</plist>\n";

    [kDefaultConfigXML writeToFile:kPrefPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark - 模块类（宏展开，类名 = SCCTileModule<SLOT>）

#define SCT_STR2(x) #x
#define SCT_STR(x) SCT_STR2(x)
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
    SCTWriteDefaultConfigIfMissing();
}

- (NSUInteger)sctSlot
{
    return (NSUInteger)(SLOT - 1);
}

- (UIImage *)sctGlyph
{
    NSDictionary *entry = SCTEntry([self sctSlot]);
    NSString *symbol = [entry objectForKey:@"symbol"];
    UIImage *image = [symbol length] ? [UIImage systemImageNamed:symbol] : nil;
    return image ?: [UIImage systemImageNamed:@"square.stack.3d.up.fill"];
}

- (UIImage *)iconGlyph
{
    return [self sctGlyph];
}

- (UIImage *)selectedIconGlyph
{
    return [self sctGlyph];
}

- (UIColor *)selectedColor
{
    static NSArray<UIColor *> *palette;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        palette = @[[UIColor systemBlueColor], [UIColor systemOrangeColor], [UIColor systemPurpleColor],
                    [UIColor systemGreenColor], [UIColor systemPinkColor], [UIColor systemTealColor],
                    [UIColor systemIndigoColor], [UIColor systemRedColor]];
    });
    return [palette objectAtIndex:([self sctSlot] % [palette count])];
}

- (BOOL)isSelected
{
    return NO; /* 瞬时磁贴，无驻留选中态 */
}

- (void)setSelected:(BOOL)selected
{
    if (!selected) return;

    SCTRunSlot([self sctSlot]);

    /* 立即回弹：视图按 isSelected=NO 重绘 */
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshState];
        [self reconfigureView];
    });
}

@end
