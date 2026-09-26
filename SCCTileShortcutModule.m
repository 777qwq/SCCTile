#import "SCCTileShortcutModule.h"
#import "SCCTileProvider.h"
#import "SCCTileModuleViewController.h"

@implementation SCCTileShortcutModule {
    BOOL _flash;
    BOOL _running;
    UIViewController<CCUIContentModuleContentViewController> *_contentVC;
}

- (instancetype)initWithName:(NSString *)name symbol:(NSString *)symbol colorIndex:(NSUInteger)colorIndex
{
    if ((self = [super init])) {
        _shortcutName = [name copy];
        if ([symbol length] > 0) {
            _symbolName = [symbol copy];
        } else {
            _symbolName = @"square.stack.3d.up.fill";
        }
        _colorIndex = colorIndex;
        _flash = NO;
        _running = NO;
    }
    [SCCTileProvider logFormat:@"module init '%@' symbol=%@", _shortcutName, _symbolName];
    return self;
}

- (CCUILayoutSize)moduleSizeForOrientation:(int)orientation
{
    (void)orientation;
    return CGSizeMake(1, 1);
}

- (UIImage *)glyphImage
{
    UIImage *image = [UIImage systemImageNamed:self.symbolName];
    if (!image) {
        image = [UIImage systemImageNamed:@"square.stack.3d.up.fill"];
    }
    return image;
}

- (UIImage *)iconGlyph
{
    [SCCTileProvider logFormat:@"iconGlyph asked (%@)", _symbolName];
    return [self glyphImage];
}

- (UIImage *)selectedIconGlyph
{
    return [self glyphImage];
}

- (UIColor *)selectedColor
{
    NSArray<UIColor *> *palette = [SCCTileProvider palette];
    return [palette objectAtIndex:(_colorIndex % [palette count])];
}

- (UIViewController<CCUIContentModuleContentViewController> *)contentViewController
{
    if (!_contentVC) {
        [SCCTileProvider logFormat:@"contentViewController creating (self-drawn)"];
        _contentVC = [[SCCTileModuleViewController alloc] initWithModule:self];
    }
    return _contentVC;
}

- (BOOL)isSelected
{
    return _flash;
}

- (void)setSelected:(BOOL)selected
{
    /* 点击磁贴：运行快捷指令后立即回弹，不做驻留选中态 */
    if (selected && !_running && _shortcutName.length > 0) {
        _running = YES;
        [SCCTileProvider runShortcutNamed:_shortcutName];

        _flash = YES;
        [self refreshState];

        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf->_flash = NO;
            strongSelf->_running = NO;
            [strongSelf refreshState];
        });
    }
}

@end
