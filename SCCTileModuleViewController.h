#import "SCCTileBase.h"

NS_ASSUME_NONNULL_BEGIN

@class SCCTileShortcutModule;

/* 自绘磁贴渲染器：不依赖 CCUIToggleViewController 的系统内部状态 */
@interface SCCTileModuleViewController : UIViewController <CCUIContentModuleContentViewController>

- (instancetype)initWithModule:(SCCTileShortcutModule *)module;

@end

NS_ASSUME_NONNULL_END
