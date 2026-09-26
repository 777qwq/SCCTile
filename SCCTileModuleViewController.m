#import "SCCTileModuleViewController.h"
#import "SCCTileShortcutModule.h"
#import "SCCTileProvider.h"

@implementation SCCTileModuleViewController {
    __weak SCCTileShortcutModule *_module;
    UIImageView *_glyphView;
}

- (instancetype)initWithModule:(SCCTileShortcutModule *)module
{
    if ((self = [super init])) {
        _module = module;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [SCCTileProvider logFormat:@"tileVC viewDidLoad"];

    _glyphView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _glyphView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _glyphView.contentMode = UIViewContentModeCenter;
    _glyphView.image = [_module iconGlyph];
    _glyphView.tintColor = [UIColor labelColor];
    [self.view addSubview:_glyphView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [self.view addGestureRecognizer:tap];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [SCCTileProvider logFormat:@"tileVC viewWillAppear"];
    [self refreshState];
}

- (void)handleTap
{
    [SCCTileProvider logFormat:@"tileVC tapped"];
    [_module setSelected:YES];
}

- (void)refreshState
{
    _glyphView.tintColor = [_module isSelected] ? [_module selectedColor] : [UIColor labelColor];
}

- (CGFloat)preferredExpandedContentHeight
{
    return 0;
}

- (CGFloat)preferredExpandedContentWidth
{
    return 0;
}

- (BOOL)providesOwnPlatter
{
    return NO;
}

@end
