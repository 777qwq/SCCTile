#import "SCCTileBase.h"
#import "SCCTileShortcutModule.h"

NS_ASSUME_NONNULL_BEGIN

/* CCSupport Provider：读取配置文件，把每条快捷指令注册为一个控制中心磁贴 */
@interface SCCTileProvider : NSObject <CCSModuleProvider>

+ (NSArray<UIColor *> *)palette;
+ (void)runShortcutNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
