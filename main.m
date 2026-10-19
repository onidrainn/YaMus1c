#import <UIKit/UIKit.h>
#import "YMControllers.h"

@interface YMAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, strong) YMAuthViewController *authVC;
@end

@implementation YMAppDelegate

- (void)onAuthStateChanged {
    if (![[YMApiClient shared] isAuthorized]) {
        [self showAuthOverlay];
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    UINavigationController *likesNav = [[UINavigationController alloc] initWithRootViewController:[[YMLikesViewController alloc] init]];
    likesNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Мне нравится" image:[UIImage imageNamed:@"tab_likes.png"] tag:0];

    UINavigationController *playerNav = [[UINavigationController alloc] initWithRootViewController:[[YMPlayerViewController alloc] init]];
    playerNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Плеер" image:[UIImage imageNamed:@"tab_player.png"] tag:1];

    UINavigationController *searchNav = [[UINavigationController alloc] initWithRootViewController:[[YMSearchViewController alloc] init]];
    searchNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Поиск" image:[UIImage imageNamed:@"tab_search.png"] tag:2];

    UINavigationController *downloadsNav = [[UINavigationController alloc] initWithRootViewController:[[YMDownloadsViewController alloc] init]];
    downloadsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Загрузки" image:[UIImage imageNamed:@"tab_downloads.png"] tag:3];

    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:[[YMSettingsViewController alloc] init]];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Настройки" image:[UIImage imageNamed:@"tab_settings.png"] tag:4];

    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = @[likesNav, playerNav, searchNav, downloadsNav, settingsNav];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onThemeChanged)
                                                 name:YMThemeDidChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(onAuthStateChanged)
                                             name:YMAuthStateChangedNotification
                                           object:nil];

    [[YMThemeManager shared] applyThemeToTabBarController:self.tabBarController];

    self.window.rootViewController = self.tabBarController;
    [self.window makeKeyAndVisible];

    if (![[YMApiClient shared] isAuthorized]) {
        [self showAuthOverlay];
    } else {
        [[YMApiClient shared] fetchAccountInfoWithCompletion:nil];
    }

    return YES;
}

- (void)showAuthOverlay {
    if (self.authVC) return;
    self.authVC = [[YMAuthViewController alloc] init];
    self.authVC.view.frame = self.window.bounds;
    self.authVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    __weak typeof(self) weakSelf = self;
    self.authVC.onAuthSuccess = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [UIView animateWithDuration:0.25 animations:^{
            strongSelf.authVC.view.alpha = 0.0;
        } completion:^(BOOL finished) {
            [strongSelf.authVC.view removeFromSuperview];
            strongSelf.authVC = nil;
        }];
    };

    [self.window addSubview:self.authVC.view];
}

- (void)onThemeChanged {
    [[YMThemeManager shared] applyThemeToTabBarController:self.tabBarController];
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([YMAppDelegate class]));
    }
}