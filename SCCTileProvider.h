#import "SCCTileBase.h"
#import "SCCTileShortcutModule.h"

NS_ASSUME_NONNULL_BEGIN

/* CCSupport Provider：把每条快捷指令注册为一个控制中心磁贴
 * v1.0.1 起以 tweak dylib 注入，hook CCSupport 的 manager 补插注册 */
@interface SCCTileProvider : NSObject <CCSModuleProvider>

+ (void)writeDefaultConfigIfMissing;
+ (void)startConfigWatch;
+ (void)logFormat:(NSString *)format, ...;
+ (NSArray<UIColor *> *)palette;
+ (void)runShortcutNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
