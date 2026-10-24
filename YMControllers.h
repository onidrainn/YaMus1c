#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "YMCore.h"

typedef NS_ENUM(NSInteger, YMAccentColor) {
    YMAccentColorRed = 0,
    YMAccentColorOrange = 1,
    YMAccentColorYellow = 2,
    YMAccentColorGreen = 3,
    YMAccentColorBlue = 4,      // Стандартный синий акцент iOS 6
    YMAccentColorLilac = 5,
    YMAccentColorPink = 6,
    YMAccentColorGraphite = 7
};

typedef NS_ENUM(NSInteger, YMIconSetType) {
    YMIconSetTypeFiles = 0,     // 1. Основные из файлов приложения
    YMIconSetTypeVector = 1     // 2. Векторные в коде
};

extern NSString *const YMThemeDidChangeNotification;

@interface UIImage (YMTint)
- (UIImage *)ym_tintedImageWithColor:(UIColor *)color;
@end

@interface YMThemeManager : NSObject
@property (nonatomic, assign) YMAccentColor currentAccentColor;
@property (nonatomic, assign) YMIconSetType currentIconSet;

+ (instancetype)shared;

- (UIColor *)accentColor;
- (UIColor *)playerAccentColor;
- (UIColor *)swatchColorForAccent:(YMAccentColor)accent;
- (UIImage *)swatchImageForAccent:(YMAccentColor)accent;
- (NSString *)accentNameForColor:(YMAccentColor)accent;
- (NSString *)currentAppearanceSummary;

- (UIImage *)tabBarIconForIndex:(NSUInteger)index selected:(BOOL)selected;
- (UIImage *)playerPlayIconWithColor:(UIColor *)color;
- (UIImage *)playerPauseIconWithColor:(UIColor *)color;
- (UIImage *)playerPrevIconWithColor:(UIColor *)color;
- (UIImage *)playerNextIconWithColor:(UIColor *)color;
- (UIImage *)playerShuffleIconWithColor:(UIColor *)color;
- (UIImage *)playerRepeatIconWithColor:(UIColor *)color;
- (UIImage *)vectorHeartImageFilled:(BOOL)filled color:(UIColor *)color size:(CGSize)size;

- (UIImage *)defaultAlbumPlaceholderWithSize:(CGSize)size;
- (UIImage *)framedAlbumImageFromImage:(UIImage *)rawImage side:(CGFloat)side;
- (UIImage *)reflectionImageFromAlbumImage:(UIImage *)albumImage side:(CGFloat)side reflectionHeight:(CGFloat)reflH;

- (void)applyThemeToNavigationController:(UINavigationController *)nav;
- (void)applyThemeToSearchBar:(UISearchBar *)searchBar;
- (void)applyThemeToTabBarController:(UITabBarController *)tabBarController;
@end

@interface YMAuthViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
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
@property (nonatomic, assign) BOOL showPlusButton;

- (void)configureWithTrack:(YMTrack *)track;
@end

@interface YMLikesViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIActionSheetDelegate>
@end

@interface YMPlayerViewController : UIViewController
@end

@interface YMSearchViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, YMSwipeTrackCellDelegate>
@end

@interface YMDownloadsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@end

@interface YMThemeSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>
@end

@interface YMSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>
@end