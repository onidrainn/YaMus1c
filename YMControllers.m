#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "YMControllers.h"

NSString *const YMThemeDidChangeNotification = @"YMThemeDidChangeNotification";
static NSString *const kYMThemeDefaultsKey = @"YMSelectedAppTheme";

#pragma mark - UIImage Tinting Category

@implementation UIImage (YMTint)
- (UIImage *)ym_tintedImageWithColor:(UIColor *)color {
    if (!color) return self;
    CGSize size = self.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, self.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    CGContextClipToMask(context, rect, self.CGImage);
    [color setFill];
    CGContextFillRect(context, rect);
    UIImage *coloredImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return coloredImg;
}
@end

#pragma mark - YMThemeManager

@implementation YMThemeManager

+ (instancetype)shared {
    static YMThemeManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YMThemeManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _currentTheme = (YMAppTheme)[[NSUserDefaults standardUserDefaults] integerForKey:kYMThemeDefaultsKey];
    }
    return self;
}

- (void)setCurrentTheme:(YMAppTheme)currentTheme {
    if (_currentTheme == currentTheme) return;
    _currentTheme = currentTheme;
    [[NSUserDefaults standardUserDefaults] setInteger:currentTheme forKey:kYMThemeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMThemeDidChangeNotification object:nil];
}

- (BOOL)isDarkTheme {
    return (self.currentTheme == YMAppThemeDarkYellow);
}

- (BOOL)isFlatTheme {
    return (self.currentTheme == YMAppThemeDarkYellow || self.currentTheme == YMAppThemeLightYellow);
}

- (UIColor *)accentColor {
    if (self.currentTheme == YMAppThemeDarkYellow || self.currentTheme == YMAppThemeLightYellow) {
        return [UIColor colorWithRed:0.95 green:0.75 blue:0.10 alpha:1.0]; // Фирменный жёлтый
    } else {
        return [UIColor colorWithRed:0.20 green:0.45 blue:0.78 alpha:1.0]; // Классический синий iOS 6
    }
}

- (UIColor *)backgroundColor {
    return [self isDarkTheme] ? [UIColor blackColor] : [UIColor whiteColor];
}

- (UIColor *)cellBackgroundColor {
    return [self isDarkTheme] ? [UIColor blackColor] : [UIColor whiteColor];
}

- (UIColor *)primaryTextColor {
    return [self isDarkTheme] ? [UIColor whiteColor] : [UIColor colorWithWhite:0.10 alpha:1.0];
}

- (UIColor *)secondaryTextColor {
    return [self isDarkTheme] ? [UIColor colorWithWhite:0.60 alpha:1.0] : [UIColor colorWithWhite:0.45 alpha:1.0];
}

- (UIColor *)separatorColor {
    return [self isDarkTheme] ? [UIColor colorWithWhite:0.18 alpha:1.0] : [UIColor colorWithWhite:0.86 alpha:1.0];
}

- (UIImage *)glossyBarBackgroundWithHeight:(CGFloat)height {
    CGSize size = CGSizeMake(4.0, height);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();

    CGFloat comps[] = {
        0.32, 0.35, 0.40, 1.0,
        0.18, 0.20, 0.24, 1.0,
        0.10, 0.12, 0.15, 1.0,
        0.08, 0.09, 0.12, 1.0
    };
    CGFloat locs[] = {0.0, 0.49, 0.50, 1.0};
    CGGradientRef grad = CGGradientCreateWithColorComponents(space, comps, locs, 4);
    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, 0), CGPointMake(0, height), 0);

    CGContextSetRGBFillColor(ctx, 0.55, 0.58, 0.65, 1.0);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, 1.0));

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    CGGradientRelease(grad);
    CGColorSpaceRelease(space);
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsZero];
}

- (void)applyThemeToNavigationController:(UINavigationController *)nav {
    if (!nav) return;

    UIViewController *rootVC = nav.viewControllers.firstObject;
    BOOL isPlayerNav = [rootVC isKindOfClass:[YMPlayerViewController class]];

    if (self.currentTheme == YMAppThemeDarkYellow || (self.currentTheme == YMAppThemeLightYellow && isPlayerNav)) {
        nav.navigationBar.barStyle = UIBarStyleBlack;
        nav.navigationBar.tintColor = [self accentColor];
        nav.navigationBar.titleTextAttributes = @{
            UITextAttributeTextColor: [UIColor whiteColor],
            UITextAttributeTextShadowColor: [UIColor clearColor]
        };
        if ([nav.navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
            CGSize size = CGSizeMake(320, 44);
            UIGraphicsBeginImageContext(size);
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextSetRGBFillColor(ctx, 0.08, 0.08, 0.08, 1.0);
            CGContextFillRect(ctx, CGRectMake(0, 0, 320, 44));
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            [nav.navigationBar setBackgroundImage:img forBarMetrics:UIBarMetricsDefault];
        }
    } else if (self.currentTheme == YMAppThemeLightYellow) {
        // Светлая тема (кроме плеера): жёлтая шапка, белые заголовки, а кнопки — цвета как в темной теме ([self accentColor])
        nav.navigationBar.barStyle = UIBarStyleDefault;
        nav.navigationBar.tintColor = [self accentColor];
        nav.navigationBar.titleTextAttributes = @{
            UITextAttributeTextColor: [UIColor whiteColor],
            UITextAttributeTextShadowColor: [UIColor clearColor]
        };
        if ([nav.navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
            CGSize size = CGSizeMake(320, 44);
            UIGraphicsBeginImageContext(size);
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextSetRGBFillColor(ctx, 0.95, 0.75, 0.10, 1.0);
            CGContextFillRect(ctx, CGRectMake(0, 0, 320, 44));
            CGContextSetRGBFillColor(ctx, 0.82, 0.62, 0.05, 1.0);
            CGContextFillRect(ctx, CGRectMake(0, 43, 320, 1));
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            [nav.navigationBar setBackgroundImage:img forBarMetrics:UIBarMetricsDefault];
        }
    } else {
        // Классическая синяя тема iOS 6: базовый цвет хедера и базовый цвет кнопок (не белый)
        nav.navigationBar.barStyle = UIBarStyleDefault;
        nav.navigationBar.tintColor = nil; // Базовый системный цвет кнопок
        nav.navigationBar.titleTextAttributes = @{
            UITextAttributeTextColor: [UIColor colorWithRed:0.95 green:0.97 blue:1.0 alpha:1.0], // Базовый светлый оттенок текста заголовка
            UITextAttributeTextShadowColor: [UIColor colorWithWhite:0.0 alpha:0.5]
        };
        if ([nav.navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
            [nav.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        }
    }
    [nav.navigationBar setNeedsLayout];
    [nav.navigationBar setNeedsDisplay];
}

- (void)applyThemeToSearchBar:(UISearchBar *)searchBar {
    if (!searchBar) return;
    if (self.currentTheme == YMAppThemeDarkYellow) {
        searchBar.barStyle = UIBarStyleBlack;
        searchBar.tintColor = [self accentColor];
        searchBar.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    } else if (self.currentTheme == YMAppThemeLightYellow) {
        searchBar.barStyle = UIBarStyleDefault;
        searchBar.tintColor = [self accentColor];
        searchBar.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];
    } else {
        searchBar.barStyle = UIBarStyleDefault;
        searchBar.tintColor = [UIColor colorWithRed:0.22 green:0.45 blue:0.74 alpha:1.0];
        searchBar.backgroundColor = [UIColor clearColor];
    }

    BOOL hideSkeuomorphicBg = [self isFlatTheme];
    for (UIView *subview in searchBar.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"UISearchBarBackground")]) {
            subview.hidden = hideSkeuomorphicBg;
            subview.alpha = hideSkeuomorphicBg ? 0.0 : 1.0;
        }
    }
    [searchBar setNeedsLayout];
    [searchBar setNeedsDisplay];
}

- (void)applyThemeToTabBarController:(UITabBarController *)tabBarController {
    if (!tabBarController) return;
    UITabBar *tabBar = tabBarController.tabBar;

    UIColor *yellowColor = [self accentColor];
    UIColor *whiteColor = [UIColor whiteColor];
    UIColor *ios6BlueColor = [UIColor colorWithRed:0.25 green:0.62 blue:0.98 alpha:1.0];
    UIColor *ios6GrayColor = [UIColor colorWithWhite:0.68 alpha:1.0];

    NSArray *imgNames = @[@"tab_likes.png", @"tab_player.png", @"tab_search.png", @"tab_downloads.png", @"tab_settings.png"];

    for (NSUInteger i = 0; i < tabBarController.viewControllers.count; i++) {
        UIViewController *vc = tabBarController.viewControllers[i];
        if ([vc isKindOfClass:[UINavigationController class]]) {
            [self applyThemeToNavigationController:(UINavigationController *)vc];
        }

        if (i < imgNames.count) {
            UIImage *rawImg = [UIImage imageNamed:imgNames[i]];
            UITabBarItem *item = vc.tabBarItem;

            if (self.currentTheme == YMAppThemeDarkYellow || self.currentTheme == YMAppThemeLightYellow) {
                UIImage *unselectedImg = [rawImg ym_tintedImageWithColor:whiteColor];
                UIImage *selectedImg = [rawImg ym_tintedImageWithColor:yellowColor];
                if ([item respondsToSelector:@selector(setFinishedSelectedImage:withFinishedUnselectedImage:)]) {
                    [item setFinishedSelectedImage:selectedImg withFinishedUnselectedImage:unselectedImg];
                } else if ([item respondsToSelector:@selector(setSelectedImage:)]) {
                    item.image = unselectedImg;
                    item.selectedImage = selectedImg;
                }
                [item setTitleTextAttributes:@{UITextAttributeTextColor: whiteColor, UITextAttributeTextShadowColor: [UIColor clearColor]} forState:UIControlStateNormal];
                [item setTitleTextAttributes:@{UITextAttributeTextColor: whiteColor, UITextAttributeTextShadowColor: [UIColor clearColor]} forState:UIControlStateSelected];
            } else {
                UIImage *unselectedImg = [rawImg ym_tintedImageWithColor:ios6GrayColor];
                UIImage *selectedImg = [rawImg ym_tintedImageWithColor:ios6BlueColor];
                if ([item respondsToSelector:@selector(setFinishedSelectedImage:withFinishedUnselectedImage:)]) {
                    [item setFinishedSelectedImage:selectedImg withFinishedUnselectedImage:unselectedImg];
                } else if ([item respondsToSelector:@selector(setSelectedImage:)]) {
                    item.image = unselectedImg;
                    item.selectedImage = selectedImg;
                }
                [item setTitleTextAttributes:@{UITextAttributeTextColor: ios6GrayColor} forState:UIControlStateNormal];
                [item setTitleTextAttributes:@{UITextAttributeTextColor: whiteColor} forState:UIControlStateSelected];
            }
        }
    }

    if (self.currentTheme == YMAppThemeDarkYellow || self.currentTheme == YMAppThemeLightYellow) {
        CGSize size = CGSizeMake(320, 49);
        UIGraphicsBeginImageContext(size);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetRGBFillColor(ctx, 0.06, 0.06, 0.06, 1.0);
        CGContextFillRect(ctx, CGRectMake(0, 0, 320, 49));
        UIImage *darkBgImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        if ([tabBar respondsToSelector:@selector(setBackgroundImage:)]) {
            tabBar.backgroundImage = darkBgImg;
        }
        if ([tabBar respondsToSelector:@selector(setSelectionIndicatorImage:)]) {
            tabBar.selectionIndicatorImage = [[UIImage alloc] init];
        }
    } else {
        if ([tabBar respondsToSelector:@selector(setBackgroundImage:)]) {
            tabBar.backgroundImage = nil;
        }
        if ([tabBar respondsToSelector:@selector(setSelectionIndicatorImage:)]) {
            tabBar.selectionIndicatorImage = nil;
        }
    }
    [tabBar setNeedsLayout];
    [tabBar setNeedsDisplay];
}

@end

#pragma mark - YMSwipeTrackCell

@interface YMSwipeTrackCell ()
@property (nonatomic, strong) UIView *actionsHolder;
@property (nonatomic, strong) UIButton *downloadBtn;
@property (nonatomic, strong) UIButton *deleteBtn;
@property (nonatomic, strong) UIView *frontView;
@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, assign, readwrite) BOOL isSwipeOpen;
@end

@implementation YMSwipeTrackCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleGray;

        _actionsHolder = [[UIView alloc] initWithFrame:CGRectZero];
        _actionsHolder.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:1.0];
        [self.contentView addSubview:_actionsHolder];

        _downloadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_downloadBtn setTitle:@"Скачать" forState:UIControlStateNormal];
        _downloadBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
        [_downloadBtn addTarget:self action:@selector(onDownloadTapped) forControlEvents:UIControlEventTouchUpInside];
        [_actionsHolder addSubview:_downloadBtn];

        _deleteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteBtn.backgroundColor = [UIColor colorWithRed:0.90 green:0.20 blue:0.20 alpha:1.0];
        [_deleteBtn setTitle:@"Удалить" forState:UIControlStateNormal];
        _deleteBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
        [_deleteBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_deleteBtn addTarget:self action:@selector(onDeleteTapped) forControlEvents:UIControlEventTouchUpInside];
        [_actionsHolder addSubview:_deleteBtn];

        _frontView = [[UIView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_frontView];

        _coverView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 40, 40)];
        _coverView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        _coverView.contentMode = UIViewContentModeScaleAspectFill;
        _coverView.clipsToBounds = YES;
        _coverView.layer.cornerRadius = 3.0;
        [_frontView addSubview:_coverView];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
        _titleLabel.backgroundColor = [UIColor clearColor];
        [_frontView addSubview:_titleLabel];

        _artistLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _artistLabel.font = [UIFont systemFontOfSize:12.0];
        _artistLabel.backgroundColor = [UIColor clearColor];
        [_frontView addSubview:_artistLabel];

        _durationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _durationLabel.font = [UIFont systemFontOfSize:12.0];
        _durationLabel.textAlignment = NSTextAlignmentRight;
        _durationLabel.backgroundColor = [UIColor clearColor];
        [_frontView addSubview:_durationLabel];

        _plusButton = [UIButton buttonWithType:UIButtonTypeContactAdd];
        [_plusButton addTarget:self action:@selector(onPlusTapped) forControlEvents:UIControlEventTouchUpInside];
        _plusButton.hidden = YES;
        [_frontView addSubview:_plusButton];

        UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
        swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
        [self addGestureRecognizer:swipeLeft];

        UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
        swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
        [self addGestureRecognizer:swipeRight];

        [self applyCurrentTheme];
    }
    return self;
}

- (void)applyCurrentTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    BOOL isFlat = [tm isFlatTheme];

    self.selectionStyle = isFlat ? UITableViewCellSelectionStyleGray : UITableViewCellSelectionStyleBlue;
    self.backgroundColor = [tm cellBackgroundColor];
    self.frontView.backgroundColor = [tm cellBackgroundColor];
    self.coverView.backgroundColor = [tm isDarkTheme] ? [UIColor colorWithWhite:0.15 alpha:1.0] : [UIColor colorWithWhite:0.90 alpha:1.0];
    self.titleLabel.textColor = [tm primaryTextColor];
    self.artistLabel.textColor = (tm.currentTheme == YMAppThemeLightYellow) ? [UIColor colorWithRed:0.82 green:0.60 blue:0.00 alpha:1.0] : [tm accentColor];
    self.durationLabel.textColor = [tm secondaryTextColor];

    self.downloadBtn.backgroundColor = [tm accentColor];
    [self.downloadBtn setTitleColor:(isFlat ? [UIColor blackColor] : [UIColor whiteColor]) forState:UIControlStateNormal];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.isSwipeOpen && !self.editing) {
        CGPoint ptInActions = [self convertPoint:point toView:self.actionsHolder];
        if ([self.actionsHolder pointInside:ptInActions withEvent:event]) {
            if (!self.downloadBtn.hidden && CGRectContainsPoint(self.downloadBtn.frame, ptInActions)) return self.downloadBtn;
            if (CGRectContainsPoint(self.deleteBtn.frame, ptInActions)) return self.deleteBtn;
        }
    }
    if (self.showPlusButton && !self.plusButton.hidden && !self.editing) {
        CGPoint ptInFront = [self convertPoint:point toView:self.frontView];
        if (CGRectContainsPoint(CGRectInset(self.plusButton.frame, -8, -8), ptInFront)) return self.plusButton;
    }
    return [super hitTest:point withEvent:event];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;

    CGFloat btnW = 70.0;
    CGFloat totalDrawerW = self.showDownloadButtonInSwipe ? (btnW * 2.0) : btnW;
    self.actionsHolder.frame = CGRectMake(w - totalDrawerW, 0, totalDrawerW, h);

    if (self.showDownloadButtonInSwipe) {
        self.downloadBtn.hidden = NO;
        self.downloadBtn.frame = CGRectMake(0, 0, btnW, h);
        self.deleteBtn.frame = CGRectMake(btnW, 0, btnW, h);
    } else {
        self.downloadBtn.hidden = YES;
        self.deleteBtn.frame = CGRectMake(0, 0, btnW, h);
    }

    CGFloat offsetX = (self.isSwipeOpen && !self.editing) ? -totalDrawerW : 0.0;
    self.frontView.frame = CGRectMake(offsetX, 0, w, h);
    self.coverView.frame = CGRectMake(12, (h - 40.0) / 2.0, 40.0, 40.0);

    CGFloat rightEdge = w - 12.0;
    if (self.showPlusButton) {
        self.plusButton.hidden = NO;
        self.plusButton.frame = CGRectMake(rightEdge - 30.0, (h - 30.0) / 2.0, 30.0, 30.0);
        rightEdge -= 36.0;
    } else {
        self.plusButton.hidden = YES;
    }

    self.durationLabel.frame = CGRectMake(rightEdge - 42.0, (h - 20.0) / 2.0, 42.0, 20.0);
    CGFloat textWidth = (rightEdge - 48.0) - 60.0;
    self.titleLabel.frame = CGRectMake(60.0, 8.0, textWidth, 19.0);
    self.artistLabel.frame = CGRectMake(60.0, 29.0, textWidth, 16.0);
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    if (editing && self.isSwipeOpen) [self closeSwipeAnimated:NO];
    [super setEditing:editing animated:animated];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.isSwipeOpen = NO;
    self.coverView.image = nil;
    [self applyCurrentTheme];
}

- (void)configureWithTrack:(YMTrack *)track {
    self.track = track;
    [self applyCurrentTheme];
    self.titleLabel.text = track.title;
    self.artistLabel.text = track.artist;
    self.durationLabel.text = [track formattedDuration];
    self.coverView.image = nil;

    if (track.localCoverPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:track.localCoverPath]) {
        self.coverView.image = [UIImage imageWithContentsOfFile:track.localCoverPath];
        return;
    }

    NSString *expectedId = [track.trackId copy];
    [[YMApiClient shared] loadImageWithURL:track.coverURL completion:^(UIImage *image) {
        if ([self.track.trackId isEqualToString:expectedId]) self.coverView.image = image;
    }];
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)gesture {
    if (!self.enableSwipeButtons || self.editing) return;
    if (gesture.direction == UISwipeGestureRecognizerDirectionLeft && !self.isSwipeOpen) {
        self.isSwipeOpen = YES;
        [UIView animateWithDuration:0.2 animations:^{ [self setNeedsLayout]; [self layoutIfNeeded]; }];
    } else if (gesture.direction == UISwipeGestureRecognizerDirectionRight && self.isSwipeOpen) {
        [self closeSwipeAnimated:YES];
    }
}

- (void)closeSwipeAnimated:(BOOL)animated {
    if (!self.isSwipeOpen) return;
    self.isSwipeOpen = NO;
    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{ [self setNeedsLayout]; [self layoutIfNeeded]; }];
    } else {
        [self setNeedsLayout];
    }
}

- (void)onDownloadTapped {
    [self closeSwipeAnimated:YES];
    if ([self.delegate respondsToSelector:@selector(trackCellDidTapDownload:)]) [self.delegate trackCellDidTapDownload:self];
}

- (void)onDeleteTapped {
    [self closeSwipeAnimated:YES];
    if ([self.delegate respondsToSelector:@selector(trackCellDidTapDelete:)]) [self.delegate trackCellDidTapDelete:self];
}

- (void)onPlusTapped {
    if ([self.delegate respondsToSelector:@selector(trackCellDidTapPlus:)]) [self.delegate trackCellDidTapPlus:self];
}

@end

#pragma mark - 1. YMLikesViewController

@interface YMLikesViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSArray *allTracks;
@property (nonatomic, strong) NSMutableArray *filteredTracks;
@property (nonatomic, copy) NSString *filterQuery;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation YMLikesViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Мне нравится";
    self.allTracks = @[];
    self.filteredTracks = [NSMutableArray array];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Изменить"
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(toggleEditMode)];

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44.0)];
    _searchBar.placeholder = @"Поиск";
    _searchBar.delegate = self;

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 56.0;
    _tableView.tableHeaderView = _searchBar;
    _tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.view addSubview:_tableView];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(loadLikesFromServer) forControlEvents:UIControlEventValueChanged];
    [_tableView addSubview:_refreshControl];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadLikesFromServer) name:YMLikesUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];

    [self applyTheme];
    [self loadLikesFromServer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
    if (self.allTracks.count == 0 && !self.isLoading) [self loadLikesFromServer];
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];
    [tm applyThemeToSearchBar:self.searchBar];
    self.view.backgroundColor = [tm backgroundColor];
    self.tableView.backgroundColor = [tm backgroundColor];
    self.tableView.separatorColor = [tm separatorColor];
    [self.tableView reloadData];
}

- (void)loadLikesFromServer {
    if (self.isLoading) return;
    self.isLoading = YES;
    [[YMApiClient shared] fetchLikesWithCompletion:^(NSArray *tracks, NSError *error) {
        self.isLoading = NO;
        [self.refreshControl endRefreshing];
        if (tracks) {
            self.allTracks = tracks;
            [self applyFilter];
        }
    }];
}

- (void)applyFilter {
    [self.filteredTracks removeAllObjects];
    if (!self.filterQuery || self.filterQuery.length == 0) {
        [self.filteredTracks addObjectsFromArray:self.allTracks];
    } else {
        NSString *q = [self.filterQuery lowercaseString];
        for (YMTrack *t in self.allTracks) {
            if ([[t.title lowercaseString] rangeOfString:q].location != NSNotFound ||
                [[t.artist lowercaseString] rangeOfString:q].location != NSNotFound) {
                [self.filteredTracks addObject:t];
            }
        }
    }
    [self.tableView reloadData];
}

- (void)toggleEditMode {
    BOOL newEdit = !self.tableView.editing;
    [self.tableView setEditing:newEdit animated:YES];
    self.navigationItem.rightBarButtonItem.title = newEdit ? @"Готово" : @"Изменить";
    self.navigationItem.leftBarButtonItem = newEdit ? [[UIBarButtonItem alloc] initWithTitle:@"Удалить" style:UIBarButtonItemStyleDone target:self action:@selector(deleteSelectedTracks)] : nil;
}

- (void)deleteSelectedTracks {
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    if (selectedRows.count == 0) return;
    NSMutableArray *ids = [NSMutableArray array];
    NSMutableArray *objs = [NSMutableArray array];
    for (NSIndexPath *ip in selectedRows) {
        YMTrack *t = self.filteredTracks[ip.row];
        [ids addObject:t.trackId];
        [objs addObject:t];
    }
    [[YMApiClient shared] removeTracksFromLikes:ids completion:^(BOOL success, NSError *error) {
        if (success) {
            NSMutableArray *upd = [self.allTracks mutableCopy];
            [upd removeObjectsInArray:objs];
            self.allTracks = upd;
            [self applyFilter];
            [self toggleEditMode];
        }
    }];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [searchBar setShowsCancelButton:NO animated:YES];
    self.filterQuery = @"";
    [self applyFilter];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.filterQuery = searchText;
    [self applyFilter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.filteredTracks.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"LikesTrackCell";
    YMSwipeTrackCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[YMSwipeTrackCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.delegate = self;
        cell.enableSwipeButtons = YES;
        cell.showDownloadButtonInSwipe = YES;
        cell.showPlusButton = NO;
    }
    [cell configureWithTrack:self.filteredTracks[indexPath.row]];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return tableView.editing; }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.editing) return;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    YMSwipeTrackCell *cell = (YMSwipeTrackCell *)[tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[YMSwipeTrackCell class]] && cell.isSwipeOpen) {
        [cell closeSwipeAnimated:YES];
        return;
    }
    [[YMPlayerManager shared] playQueue:self.filteredTracks startIndex:indexPath.row];
    self.tabBarController.selectedIndex = 1;
}

- (void)trackCellDidTapDownload:(YMSwipeTrackCell *)cell {
    if (!cell.track) return;
    [[YMDownloadManager shared] downloadTrack:cell.track completion:^(BOOL success, NSError *error) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Загрузки" message:success ? @"Сохранено" : @"Ошибка" delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil];
        [a show];
    }];
}

- (void)trackCellDidTapDelete:(YMSwipeTrackCell *)cell {
    if (!cell.track) return;
    [[YMApiClient shared] removeTracksFromLikes:@[cell.track.trackId] completion:^(BOOL success, NSError *error) {
        if (success) {
            NSMutableArray *upd = [self.allTracks mutableCopy];
            [upd removeObject:cell.track];
            self.allTracks = upd;
            [self applyFilter];
        }
    }];
}

@end

#pragma mark - 2. YMPlayerViewController

@interface YMPlayerViewController ()
@property (nonatomic, strong) UISlider *seekSlider;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *remainingLabel;
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, assign) BOOL isScrubbing;
@property (nonatomic, copy) NSString *displayedTrackId;
@end

@implementation YMPlayerViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // 1. Заголовок в NavigationBar (Песня, Исполнитель, Альбом в 3 строки)
    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];

    UILabel *titleTrackLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 15)];
    titleTrackLabel.tag = 101;
    titleTrackLabel.font = [UIFont boldSystemFontOfSize:13.0];
    titleTrackLabel.textAlignment = NSTextAlignmentCenter;
    titleTrackLabel.backgroundColor = [UIColor clearColor];
    [titleView addSubview:titleTrackLabel];

    UILabel *artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 14, 200, 14)];
    artistLabel.tag = 102;
    artistLabel.font = [UIFont boldSystemFontOfSize:12.0];
    artistLabel.textAlignment = NSTextAlignmentCenter;
    artistLabel.backgroundColor = [UIColor clearColor];
    [titleView addSubview:artistLabel];

    UILabel *albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 27, 200, 12)];
    albumLabel.tag = 103;
    albumLabel.font = [UIFont systemFontOfSize:10.0];
    albumLabel.textAlignment = NSTextAlignmentCenter;
    albumLabel.backgroundColor = [UIColor clearColor];
    [titleView addSubview:albumLabel];

    self.navigationItem.titleView = titleView;

    CGFloat w = self.view.bounds.size.width;

    // 2. Ползунок перемотки с таймлайном (сразу под хедером)
    CGFloat sliderY = 10.0;

    _elapsedLabel = [[UILabel alloc] initWithFrame:CGRectMake(12.0, sliderY + 2.0, 42.0, 14.0)];
    _elapsedLabel.font = [UIFont boldSystemFontOfSize:11.0];
    _elapsedLabel.backgroundColor = [UIColor clearColor];
    _elapsedLabel.text = @"0:00";
    [self.view addSubview:_elapsedLabel];

    _remainingLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 54.0, sliderY + 2.0, 42.0, 14.0)];
    _remainingLabel.font = [UIFont boldSystemFontOfSize:11.0];
    _remainingLabel.textAlignment = NSTextAlignmentRight;
    _remainingLabel.backgroundColor = [UIColor clearColor];
    _remainingLabel.text = @"-0:00";
    [self.view addSubview:_remainingLabel];

    _seekSlider = [[UISlider alloc] initWithFrame:CGRectMake(56.0, sliderY - 2.0, w - 112.0, 24.0)];
    _seekSlider.minimumValue = 0.0;
    _seekSlider.maximumValue = 1.0;
    [_seekSlider addTarget:self action:@selector(onSeekTouchDown) forControlEvents:UIControlEventTouchDown];
    [_seekSlider addTarget:self action:@selector(onSeekValueChanged) forControlEvents:UIControlEventValueChanged];
    [_seekSlider addTarget:self action:@selector(onSeekTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.view addSubview:_seekSlider];

    // 3. Нижняя панель управления строго над таббаром
    CGFloat bottomBarH = 54.0;
    CGFloat totalH = self.view.bounds.size.height;

    _bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, totalH - bottomBarH, w, bottomBarH)];
    _bottomBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_bottomBar];

    CGFloat btnW = w / 3.0;

    _prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _prevButton.frame = CGRectMake(0, 0, btnW, bottomBarH);
    [_prevButton addTarget:self action:@selector(onPrev) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_prevButton];

    _playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _playPauseButton.frame = CGRectMake(btnW, 0, btnW, bottomBarH);
    [_playPauseButton addTarget:self action:@selector(onPlayPause) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_playPauseButton];

    _nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _nextButton.frame = CGRectMake(btnW * 2.0, 0, btnW, bottomBarH);
    [_nextButton addTarget:self action:@selector(onNext) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_nextButton];

    // 4. Ползунок громкости (MPVolumeView) между обложкой и нижними кнопками
    CGFloat volumeH = 30.0;
    CGFloat volumeY = _bottomBar.frame.origin.y - volumeH - 8.0;
    _volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(36.0, volumeY, w - 72.0, volumeH)];
    [self.view addSubview:_volumeView];

    // 5. Обложка трека (между таймлайном и ползунком громкости)
    CGFloat coverY = sliderY + 28.0;
    CGFloat coverBottomLimit = _volumeView.frame.origin.y - 8.0;
    CGFloat availableH = coverBottomLimit - coverY;
    CGFloat coverSize = MIN(w - 60.0, availableH);
    CGFloat coverX = (w - coverSize) / 2.0;

    _coverImageView = [[UIImageView alloc] initWithFrame:CGRectMake(coverX, coverY, coverSize, coverSize)];
    _coverImageView.contentMode = UIViewContentModeScaleAspectFill;
    _coverImageView.clipsToBounds = YES;
    _coverImageView.layer.cornerRadius = 6.0;
    _coverImageView.layer.borderWidth = 1.0;
    [self.view addSubview:_coverImageView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshPlayerUI) name:YMPlayerStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];

    [self applyTheme];
    [self refreshPlayerUI];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat bottomBarH = 54.0;
    if (_bottomBar) {
        _bottomBar.frame = CGRectMake(0, h - bottomBarH, w, bottomBarH);
    }
    if (_volumeView && _bottomBar) {
        CGFloat volumeH = 30.0;
        CGFloat volumeY = _bottomBar.frame.origin.y - volumeH - 8.0;
        _volumeView.frame = CGRectMake(36.0, volumeY, w - 72.0, volumeH);
    }
    if (_coverImageView && _volumeView) {
        CGFloat coverY = 38.0;
        CGFloat coverBottomLimit = _volumeView.frame.origin.y - 8.0;
        CGFloat availableH = coverBottomLimit - coverY;
        CGFloat coverSize = MIN(w - 60.0, availableH);
        CGFloat coverX = (w - coverSize) / 2.0;
        _coverImageView.frame = CGRectMake(coverX, coverY, coverSize, coverSize);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];

    UIView *tv = self.navigationItem.titleView;
    UILabel *titleTrackLabel = (UILabel *)[tv viewWithTag:101];
    UILabel *artistLabel = (UILabel *)[tv viewWithTag:102];
    UILabel *albumLabel = (UILabel *)[tv viewWithTag:103];

    if (tm.currentTheme == YMAppThemeDarkYellow || tm.currentTheme == YMAppThemeLightYellow) {
        self.view.backgroundColor = [UIColor blackColor];
        titleTrackLabel.textColor = [UIColor whiteColor];
        artistLabel.textColor = [tm accentColor];
        albumLabel.textColor = [UIColor colorWithWhite:0.60 alpha:1.0];

        self.elapsedLabel.textColor = [tm accentColor];
        self.remainingLabel.textColor = [UIColor colorWithWhite:0.70 alpha:1.0];

        if ([self.seekSlider respondsToSelector:@selector(setMinimumTrackTintColor:)]) {
            self.seekSlider.minimumTrackTintColor = [tm accentColor];
        }
        if ([self.volumeView respondsToSelector:@selector(setTintColor:)]) {
            self.volumeView.tintColor = [tm accentColor];
        }

        self.coverImageView.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1.0];
        self.coverImageView.layer.borderColor = [UIColor colorWithWhite:0.20 alpha:1.0].CGColor;
        self.bottomBar.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.04 alpha:1.0];

        NSArray *btns = @[self.prevButton, self.playPauseButton, self.nextButton];
        for (UIButton *b in btns) {
            [b setBackgroundImage:nil forState:UIControlStateNormal];
            b.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
            b.layer.borderWidth = 0.0;
        }

        UIColor *yCol = [tm accentColor];
        [self.prevButton setImage:[[UIImage imageNamed:@"player_prev"] ym_tintedImageWithColor:yCol] forState:UIControlStateNormal];
        [self.nextButton setImage:[[UIImage imageNamed:@"player_next"] ym_tintedImageWithColor:yCol] forState:UIControlStateNormal];

    } else {
        self.view.backgroundColor = [UIColor colorWithRed:0.12 green:0.14 blue:0.18 alpha:1.0];
        titleTrackLabel.textColor = [UIColor whiteColor];
        artistLabel.textColor = [UIColor colorWithRed:0.82 green:0.90 blue:1.0 alpha:1.0];
        albumLabel.textColor = [UIColor colorWithWhite:0.88 alpha:1.0];

        self.elapsedLabel.textColor = [UIColor whiteColor];
        self.remainingLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];

        if ([self.seekSlider respondsToSelector:@selector(setMinimumTrackTintColor:)]) {
            self.seekSlider.minimumTrackTintColor = nil;
        }
        if ([self.volumeView respondsToSelector:@selector(setTintColor:)]) {
            self.volumeView.tintColor = nil;
        }

        self.coverImageView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        self.coverImageView.layer.borderColor = [UIColor colorWithWhite:0.45 alpha:1.0].CGColor;

        UIImage *glossImg = [tm glossyBarBackgroundWithHeight:54.0];
        NSArray *btns = @[self.prevButton, self.playPauseButton, self.nextButton];
        for (UIButton *b in btns) {
            [b setBackgroundImage:glossImg forState:UIControlStateNormal];
            b.backgroundColor = [UIColor clearColor];
            b.layer.borderWidth = 0.5;
            b.layer.borderColor = [UIColor colorWithWhite:0.05 alpha:0.8].CGColor;
        }

        UIColor *whiteCol = [UIColor colorWithRed:0.95 green:0.97 blue:1.0 alpha:1.0];
        [self.prevButton setImage:[[UIImage imageNamed:@"player_prev"] ym_tintedImageWithColor:whiteCol] forState:UIControlStateNormal];
        [self.nextButton setImage:[[UIImage imageNamed:@"player_next"] ym_tintedImageWithColor:whiteCol] forState:UIControlStateNormal];
    }

    [self refreshPlayerUI];
}

- (NSString *)formatSeconds:(NSTimeInterval)sec {
    NSInteger s = (NSInteger)MAX(0, sec);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(s / 60), (long)(s % 60)];
}

- (void)refreshPlayerUI {
    YMPlayerManager *pm = [YMPlayerManager shared];
    YMThemeManager *tm = [YMThemeManager shared];
    UIColor *iconCol = [tm isFlatTheme] ? [tm accentColor] : [UIColor colorWithRed:0.95 green:0.97 blue:1.0 alpha:1.0];

    UIImage *rawPlayImg = pm.isPlaying ? [UIImage imageNamed:@"player_pause"] : [UIImage imageNamed:@"player_play"];
    if (rawPlayImg) {
        [_playPauseButton setImage:[rawPlayImg ym_tintedImageWithColor:iconCol] forState:UIControlStateNormal];
    }

    YMTrack *t = pm.currentTrack;
    if (!t) return;

    UIView *tv = self.navigationItem.titleView;
    UILabel *titleTrackLabel = (UILabel *)[tv viewWithTag:101];
    UILabel *artistLabel = (UILabel *)[tv viewWithTag:102];
    UILabel *albumLabel = (UILabel *)[tv viewWithTag:103];

    titleTrackLabel.text = t.title;
    artistLabel.text = t.artist;
    albumLabel.text = t.album.length > 0 ? t.album : @"";

    NSTimeInterval total = MAX(1.0, pm.totalDuration);
    self.seekSlider.maximumValue = total;
    if (!self.isScrubbing) {
        self.seekSlider.value = pm.currentTime;
        self.elapsedLabel.text = [self formatSeconds:pm.currentTime];
    }
    NSTimeInterval remaining = total - pm.currentTime;
    self.remainingLabel.text = [NSString stringWithFormat:@"-%@", [self formatSeconds:remaining]];

    if (![self.displayedTrackId isEqualToString:t.trackId]) {
        self.displayedTrackId = t.trackId;
        self.coverImageView.image = nil;
        if (t.localCoverPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:t.localCoverPath]) {
            self.coverImageView.image = [UIImage imageWithContentsOfFile:t.localCoverPath];
        } else {
            [[YMApiClient shared] loadImageWithURL:t.coverURL completion:^(UIImage *image) {
                if ([self.displayedTrackId isEqualToString:t.trackId]) self.coverImageView.image = image;
            }];
        }
    }
}

- (void)onSeekTouchDown { self.isScrubbing = YES; }
- (void)onSeekValueChanged { self.elapsedLabel.text = [self formatSeconds:self.seekSlider.value]; }
- (void)onSeekTouchUp {
    [[YMPlayerManager shared] seekToSeconds:self.seekSlider.value];
    self.isScrubbing = NO;
}
- (void)onPrev { [[YMPlayerManager shared] previousTrack]; }
- (void)onPlayPause { [[YMPlayerManager shared] togglePlayPause]; }
- (void)onNext { [[YMPlayerManager shared] nextTrack]; }

@end

#pragma mark - 3. YMSearchViewController

@interface YMSearchViewController ()
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *foundTracks;
@property (nonatomic, strong) NSArray *foundArtists;
@property (nonatomic, strong) NSArray *foundAlbums;
@end

@implementation YMSearchViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Поиск";
    self.foundTracks = @[];
    self.foundArtists = @[];
    self.foundAlbums = @[];

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44.0)];
    _searchBar.placeholder = @"Треки, исполнители, альбомы";
    _searchBar.delegate = self;

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 56.0;
    _tableView.tableHeaderView = _searchBar;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];
    [self applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];
    [tm applyThemeToSearchBar:self.searchBar];
    self.view.backgroundColor = [tm backgroundColor];
    self.tableView.backgroundColor = [tm backgroundColor];
    self.tableView.separatorColor = [tm separatorColor];
    [self.tableView reloadData];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *q = searchBar.text;
    if (!q || q.length == 0) return;

    [[YMApiClient shared] searchWithQuery:q completion:^(NSArray *tracks, NSArray *artists, NSArray *albums, NSError *error) {
        if (error) return;
        self.foundTracks = tracks ?: @[];
        self.foundArtists = artists ?: @[];
        self.foundAlbums = albums ?: @[];
        [self.tableView reloadData];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return self.foundTracks.count ? @"Треки" : nil;
    if (section == 1) return self.foundArtists.count ? @"Исполнители" : nil;
    if (section == 2) return self.foundAlbums.count ? @"Альбомы" : nil;
    return nil;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.foundTracks.count;
    if (section == 1) return self.foundArtists.count;
    return self.foundAlbums.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *tCellId = @"SearchTrackCell";
        YMSwipeTrackCell *cell = [tableView dequeueReusableCellWithIdentifier:tCellId];
        if (!cell) {
            cell = [[YMSwipeTrackCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tCellId];
            cell.delegate = self;
            cell.enableSwipeButtons = NO;
            cell.showPlusButton = YES;
        }
        [cell configureWithTrack:self.foundTracks[indexPath.row]];
        return cell;
    }

    static NSString *metaId = @"MetaCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:metaId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:metaId];
    }
    YMThemeManager *tm = [YMThemeManager shared];
    cell.backgroundColor = [tm cellBackgroundColor];
    cell.contentView.backgroundColor = [tm cellBackgroundColor];
    cell.textLabel.textColor = [tm primaryTextColor];
    cell.detailTextLabel.textColor = [tm secondaryTextColor];

    if (indexPath.section == 1) {
        NSDictionary *artist = self.foundArtists[indexPath.row];
        cell.textLabel.text = artist[@"name"];
        cell.detailTextLabel.text = artist[@"genres"];
    } else {
        NSDictionary *album = self.foundAlbums[indexPath.row];
        cell.textLabel.text = album[@"title"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%@)", album[@"artist"] ?: @"", album[@"year"] ?: @""];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        [[YMPlayerManager shared] playQueue:self.foundTracks startIndex:indexPath.row];
        self.tabBarController.selectedIndex = 1;
    }
}

- (void)trackCellDidTapPlus:(YMSwipeTrackCell *)cell {
    if (!cell.track) return;
    [[YMApiClient shared] addTrackToLikes:cell.track.trackId completion:^(BOOL success, NSError *error) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Плейлист" message:success ? @"Добавлено" : @"Ошибка" delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil];
        [a show];
    }];
}

@end

#pragma mark - 4. YMDownloadsViewController

@interface YMDownloadsViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *tracks;
@end

@implementation YMDownloadsViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Загрузки";

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Изменить"
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(toggleEditMode)];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 56.0;
    _tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDownloads) name:YMDownloadsUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];

    [self applyTheme];
    [self reloadDownloads];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];
    self.view.backgroundColor = [tm backgroundColor];
    self.tableView.backgroundColor = [tm backgroundColor];
    self.tableView.separatorColor = [tm separatorColor];
    [self.tableView reloadData];
}

- (void)reloadDownloads {
    self.tracks = [[YMDownloadManager shared] downloadedTracks];
    [self.tableView reloadData];
}

- (void)toggleEditMode {
    BOOL newEdit = !self.tableView.editing;
    [self.tableView setEditing:newEdit animated:YES];
    self.navigationItem.rightBarButtonItem.title = newEdit ? @"Готово" : @"Изменить";
    self.navigationItem.leftBarButtonItem = newEdit ? [[UIBarButtonItem alloc] initWithTitle:@"Удалить" style:UIBarButtonItemStyleDone target:self action:@selector(deleteSelectedDownloads)] : nil;
}

- (void)deleteSelectedDownloads {
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    if (selectedRows.count == 0) return;
    NSMutableArray *ids = [NSMutableArray array];
    for (NSIndexPath *ip in selectedRows) {
        YMTrack *t = self.tracks[ip.row];
        [ids addObject:t.trackId];
    }
    [[YMDownloadManager shared] deleteDownloadedTracksWithIds:ids];
    [self toggleEditMode];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.tracks.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *dlCellId = @"DownloadCell";
    YMSwipeTrackCell *cell = [tableView dequeueReusableCellWithIdentifier:dlCellId];
    if (!cell) {
        cell = [[YMSwipeTrackCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:dlCellId];
        cell.delegate = self;
        cell.enableSwipeButtons = YES;
        cell.showDownloadButtonInSwipe = NO;
        cell.showPlusButton = NO;
    }
    [cell configureWithTrack:self.tracks[indexPath.row]];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return tableView.editing; }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.editing) return;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    YMSwipeTrackCell *cell = (YMSwipeTrackCell *)[tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[YMSwipeTrackCell class]] && cell.isSwipeOpen) {
        [cell closeSwipeAnimated:YES];
        return;
    }
    [[YMPlayerManager shared] playQueue:self.tracks startIndex:indexPath.row];
    self.tabBarController.selectedIndex = 1;
}

- (void)trackCellDidTapDelete:(YMSwipeTrackCell *)cell {
    if (!cell.track) return;
    [[YMDownloadManager shared] deleteDownloadedTracksWithIds:@[cell.track.trackId]];
}

@end

#pragma mark - 5. YMSettingsViewController (Выбор из 3 тем оформления)

@interface YMSettingsViewController ()
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation YMSettingsViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Настройки";

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 52.0;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];
    [self applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];
    [tm applyThemeToTabBarController:self.tabBarController];

    self.view.backgroundColor = [tm backgroundColor];
    self.tableView.backgroundColor = [tm backgroundColor];
    self.tableView.separatorColor = [tm separatorColor];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Оформление (Темы)";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *themeCellId = @"ThemeOptionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:themeCellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:themeCellId];
    }

    YMThemeManager *tm = [YMThemeManager shared];
    BOOL isFlat = [tm isFlatTheme];

    cell.backgroundColor = [tm cellBackgroundColor];
    cell.contentView.backgroundColor = [tm cellBackgroundColor];
    cell.textLabel.textColor = [tm primaryTextColor];
    cell.detailTextLabel.textColor = [tm secondaryTextColor];
    cell.selectionStyle = isFlat ? UITableViewCellSelectionStyleGray : UITableViewCellSelectionStyleBlue;

    if (indexPath.row == 0) {
        cell.textLabel.text = @"Тёмная (Жёлтый акцент)";
        cell.detailTextLabel.text = @"Тёмная тема без скевоморфизма";
        cell.accessoryType = (tm.currentTheme == YMAppThemeDarkYellow) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"Классическая iOS 6";
        cell.detailTextLabel.text = @"Интерфейс iOS 6 со скевоморфизмом";
        cell.accessoryType = (tm.currentTheme == YMAppThemeClassicIOS6) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        cell.textLabel.text = @"Светлая (Жёлтый акцент)";
        cell.detailTextLabel.text = @"Светлая тема без скевоморфизма";
        cell.accessoryType = (tm.currentTheme == YMAppThemeLightYellow) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 0) {
        [YMThemeManager shared].currentTheme = YMAppThemeDarkYellow;
    } else if (indexPath.row == 1) {
        [YMThemeManager shared].currentTheme = YMAppThemeClassicIOS6;
    } else {
        [YMThemeManager shared].currentTheme = YMAppThemeLightYellow;
    }
}

@end