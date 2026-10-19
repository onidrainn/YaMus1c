#import <UIKit/UIKit.h>
#import "YMCore.h"

typedef NS_ENUM(NSInteger, YMAppTheme) {
    YMAppThemeDarkYellow = 0,
    YMAppThemeClassicIOS6 = 1,
    YMAppThemeLightYellow = 2,
    YMAppThemeMaterialYou = 3
};

extern NSString *const YMThemeDidChangeNotification;

@interface UIImage (YMTint)
- (UIImage *)ym_tintedImageWithColor:(UIColor *)color;
@end

@interface YMThemeManager : NSObject
@property (nonatomic, assign) YMAppTheme currentTheme;

+ (instancetype)shared;
- (BOOL)isDarkTheme;
- (BOOL)isFlatTheme;
- (BOOL)isMaterialYouTheme;
- (UIColor *)accentColor;
- (UIColor *)backgroundColor;
- (UIColor *)cellBackgroundColor;
- (UIColor *)primaryTextColor;
- (UIColor *)secondaryTextColor;
- (UIColor *)separatorColor;
- (NSString *)currentThemeDisplayName;

- (void)applyThemeToNavigationController:(UINavigationController *)nav;
- (void)applyThemeToSearchBar:(UISearchBar *)searchBar;
- (void)applyThemeToTabBarController:(UITabBarController *)tabBarController;
- (UIImage *)glossyBarBackgroundWithHeight:(CGFloat)height;
@end

@interface YMAuthViewController : UIViewController
@property (nonatomic, copy) void (^onAuthSuccess)(void);
@end

@class YMSwipeTrackCell;

@protocol YMSwipeTrackCellDelegate <NSObject>
@optional
- (void)trackCellDidTapDownload:(YMSwipeTrackCell *)cell;
- (void)trackCellDidTapDelete:(YMSwipeTrackCell *)cell;
- (void)trackCellDidTapPlus:(YMSwipeTrackCell *)cell;
@end

@interface YMSwipeTrackCell : UITableViewCell
@property (nonatomic, weak) id<YMSwipeTrackCellDelegate> delegate;
@property (nonatomic, strong) YMTrack *track;
@property (nonatomic, assign) BOOL enableSwipeButtons;
@property (nonatomic, assign) BOOL showDownloadButtonInSwipe;
@property (nonatomic, assign) BOOL showPlusButton;
@property (nonatomic, assign, readonly) BOOL isSwipeOpen;

- (void)configureWithTrack:(YMTrack *)track;
- (void)applyCurrentTheme;
- (void)closeSwipeAnimated:(BOOL)animated;
@end

@interface YMLikesViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, YMSwipeTrackCellDelegate>
@end

@interface YMPlayerViewController : UIViewController
@end

@interface YMSearchViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, YMSwipeTrackCellDelegate>
@end

@interface YMDownloadsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, YMSwipeTrackCellDelegate>
@end

@interface YMThemeSettingsViewController : UIViewController
@end

@interface YMSettingsViewController : UIViewController
@end