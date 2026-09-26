#import "SCCTileBase.h"

NS_ASSUME_NONNULL_BEGIN

/* 单个快捷指令磁贴（Provider 模式的动态模块实例）
 * 形态与原生开关磁贴一致：1x1、图标居中、点击瞬间高亮并运行指令 */
@interface SCCTileShortcutModule : CCUIToggleModule

@property (nonatomic, copy) NSString *shortcutName;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, assign) NSUInteger colorIndex;

- (instancetype)initWithName:(NSString *)name
                      symbol:(nullable NSString *)symbol
                  colorIndex:(NSUInteger)colorIndex;

@end

NS_ASSUME_NONNULL_END
