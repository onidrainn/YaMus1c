#import "YMCore.h"

NSString * const YMPlayerStateChangedNotification = @"YMPlayerStateChangedNotification";
NSString * const YMDownloadsUpdatedNotification = @"YMDownloadsUpdatedNotification";
NSString * const YMLikesUpdatedNotification = @"YMLikesUpdatedNotification";
NSString * const YMAuthStateChangedNotification = @"YMAuthStateChangedNotification";

static NSString * const kDefaultProxyBaseURL = @"http://<YOUR_SERVER_IP_AND_PORT>";
static NSString * const kYMStoredTokenKey = @"YMOAuthStoredToken";
static NSString * const kYMStoredAccountNameKey = @"YMOAuthStoredAccountName";

@implementation YMTrack

+ (NSString *)normalizeURL:(NSString *)urlStr baseURL:(NSString *)baseURL {
    if (!urlStr || urlStr.length == 0) return @"";
    if ([urlStr hasPrefix:@"/"]) {
        return [NSString stringWithFormat:@"%@%@", baseURL, urlStr];
    }
    NSURL *parsed = [NSURL URLWithString:urlStr];
    if (parsed && ([parsed.host isEqualToString:@"127.0.0.1"] || [parsed.host isEqualToString:@"localhost"])) {
        NSRange pathRange = [urlStr rangeOfString:parsed.path];
        if (pathRange.location != NSNotFound) {
            NSString *pathAndQuery = [urlStr substringFromIndex:pathRange.location];
            return [NSString stringWithFormat:@"%@%@", baseURL, pathAndQuery];
        }
    }
    return urlStr;
}

+ (instancetype)trackFromDictionary:(NSDictionary *)dict baseURL:(NSString *)baseURL token:(NSString *)token {
    YMTrack *t = [[YMTrack alloc] init];
    t.trackId = [NSString stringWithFormat:@"%@", dict[@"id"] ?: @""];
    t.title = [dict[@"title"] isKindOfClass:[NSString class]] ? dict[@"title"] : @"Без названия";
    t.artist = [dict[@"artist"] isKindOfClass:[NSString class]] ? dict[@"artist"] : @"Неизвестен";
    t.album = [dict[@"album"] isKindOfClass:[NSString class]] ? dict[@"album"] : @"";
    t.duration = [dict[@"duration"] respondsToSelector:@selector(integerValue)] ? [dict[@"duration"] integerValue] : 0;

    NSString *rawCover = [dict[@"cover_url"] isKindOfClass:[NSString class]] ? dict[@"cover_url"] : @"";
    t.coverURL = [self normalizeURL:rawCover baseURL:baseURL];

    NSString *rawStream = [NSString stringWithFormat:@"%@/get-stream/%@.mp3", baseURL, t.trackId];
    t.streamURL = rawStream;

    t.localAudioPath = [dict[@"local_audio"] isKindOfClass:[NSString class]] ? dict[@"local_audio"] : @"";
    t.localCoverPath = [dict[@"local_cover"] isKindOfClass:[NSString class]] ? dict[@"local_cover"] : @"";
    return t;
}

- (NSDictionary *)toDictionary {
    return @{
        @"id": self.trackId ?: @"",
        @"title": self.title ?: @"",
        @"artist": self.artist ?: @"",
        @"album": self.album ?: @"",
        @"duration": @(self.duration),
        @"cover_url": self.coverURL ?: @"",
        @"stream_url": self.streamURL ?: @"",
        @"local_audio": self.localAudioPath ?: @"",
        @"local_cover": self.localCoverPath ?: @""
    };
}

- (NSString *)formattedDuration {
    NSInteger mins = self.duration / 60;
    NSInteger secs = self.duration % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)mins, (long)secs];
}

@end

#pragma mark - YMApiClient

@interface YMApiClient ()
@property (nonatomic, copy, readwrite) NSString *token;
@property (nonatomic, copy, readwrite) NSString *accountName;
@property (nonatomic, strong) NSOperationQueue *netQueue;
@property (nonatomic, strong) NSCache *imageCache;
@end

@implementation YMApiClient

+ (instancetype)shared {
    static YMApiClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YMApiClient alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _baseURL = kDefaultProxyBaseURL;
        _netQueue = [[NSOperationQueue alloc] init];
        _netQueue.maxConcurrentOperationCount = 4;
        _imageCache = [[NSCache alloc] init];

        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        _token = [defs stringForKey:kYMStoredTokenKey] ?: @"";
        _accountName = [defs stringForKey:kYMStoredAccountNameKey] ?: @"";

        [self reloadConfig];
    }
    return self;
}

- (NSString *)cleanTextFromFile:(NSString *)filename {
    NSString *bundlePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:filename];
    NSString *raw = [NSString stringWithContentsOfFile:bundlePath encoding:NSUTF8StringEncoding error:nil];
    if (!raw || raw.length == 0) {
        NSString *resPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
        raw = [NSString stringWithContentsOfFile:resPath encoding:NSUTF8StringEncoding error:nil];
    }
    if (!raw || raw.length == 0) {
        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *docPath = [docs stringByAppendingPathComponent:filename];
        raw = [NSString stringWithContentsOfFile:docPath encoding:NSUTF8StringEncoding error:nil];
    }
    if (!raw) return @"";
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [[raw componentsSeparatedByCharactersInSet:ws] componentsJoinedByString:@""];
}

- (void)reloadConfig {
    NSString *customProxy = [self cleanTextFromFile:@"proxy.txt"];
    if (customProxy.length > 0 && [customProxy hasPrefix:@"http"]) {
        if ([customProxy hasSuffix:@"/"]) {
            customProxy = [customProxy substringToIndex:customProxy.length - 1];
        }
        self.baseURL = customProxy;
    } else {
        self.baseURL = kDefaultProxyBaseURL;
    }
}

- (BOOL)isAuthorized {
    return (self.token && self.token.length > 0);
}

- (void)saveToken:(NSString *)token accountName:(NSString *)accountName {
    self.token = token ?: @"";
    if (accountName && accountName.length > 0) {
        self.accountName = accountName;
    }
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:self.token forKey:kYMStoredTokenKey];
    if (self.accountName.length > 0) {
        [defs setObject:self.accountName forKey:kYMStoredAccountNameKey];
    }
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMAuthStateChangedNotification object:nil];
}

- (void)logout {
    self.token = @"";
    self.accountName = @"";
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs removeObjectForKey:kYMStoredTokenKey];
    [defs removeObjectForKey:kYMStoredAccountNameKey];
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMAuthStateChangedNotification object:nil];
}

- (NSMutableURLRequest *)requestWithPath:(NSString *)path method:(NSString *)method body:(NSDictionary *)body {
    [self reloadConfig];
    NSString *urlStr = [NSString stringWithFormat:@"%@%@", self.baseURL, path];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:25.0];
    req.HTTPMethod = method;
    req.HTTPShouldUsePipelining = NO;
    [req setValue:@"close" forHTTPHeaderField:@"Connection"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    if (self.token.length > 0) {
        [req setValue:self.token forHTTPHeaderField:@"X-Ya-Token"];
    }

    if (body) {
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        [req setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [req setValue:[NSString stringWithFormat:@"%lu", (unsigned long)bodyData.length] forHTTPHeaderField:@"Content-Length"];
        req.HTTPBody = bodyData;
    }
    return req;
}

- (NSError *)errorFromResponse:(NSURLResponse *)resp data:(NSData *)data networkError:(NSError *)netErr {
    if (netErr) return netErr;
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
    NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if ([json isKindOfClass:[NSDictionary class]] && json[@"error"]) {
        return [NSError errorWithDomain:@"YMApiError"
                                   code:(http ? http.statusCode : 500)
                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@", json[@"error"]]}];
    }
    if (http && http.statusCode >= 400) {
        NSString *msg = [NSString stringWithFormat:@"HTTP ошибка %ld", (long)http.statusCode];
        return [NSError errorWithDomain:@"YMApiError" code:http.statusCode userInfo:@{NSLocalizedDescriptionKey: msg}];
    }
    return nil;
}

- (void)startDeviceAuthWithCompletion:(void (^)(NSString *deviceCode, NSString *userCode, NSString *verificationURL, NSInteger interval, NSError *error))completion {
    NSURLRequest *req = [self requestWithPath:@"/auth/device/start" method:@"POST" body:@{}];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSError *apiErr = [self errorFromResponse:resp data:data networkError:err];
        if (apiErr || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, nil, nil, 5, apiErr);
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *devCode = [json isKindOfClass:[NSDictionary class]] ? (json[@"device_code"] ?: @"") : @"";
        NSString *usrCode = [json isKindOfClass:[NSDictionary class]] ? (json[@"user_code"] ?: @"") : @"";
        NSString *verURL = [json isKindOfClass:[NSDictionary class]] ? (json[@"verification_url"] ?: @"ya.ru/device") : @"ya.ru/device";
        NSInteger interval = ([json isKindOfClass:[NSDictionary class]] && [json[@"interval"] respondsToSelector:@selector(integerValue)]) ? [json[@"interval"] integerValue] : 5;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(devCode, usrCode, verURL, MAX(3, interval), nil);
        });
    }];
}

- (void)pollDeviceAuthWithCode:(NSString *)deviceCode completion:(void (^)(BOOL authorized, NSString *token, NSString *accountName, NSError *error))completion {
    if (!deviceCode || deviceCode.length == 0) return;
    NSURLRequest *req = [self requestWithPath:@"/auth/device/poll" method:@"POST" body:@{@"device_code": deviceCode}];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (err || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, nil, nil, err);
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, nil, nil, nil);
            });
            return;
        }
        NSString *status = json[@"status"] ?: @"";
        if ([status isEqualToString:@"ok"] && [json[@"access_token"] isKindOfClass:[NSString class]]) {
            NSString *tok = json[@"access_token"];
            NSString *accName = [json[@"account_name"] isKindOfClass:[NSString class]] ? json[@"account_name"] : @"Пользователь Яндекса";
            dispatch_async(dispatch_get_main_queue(), ^{
                [self saveToken:tok accountName:accName];
                if (completion) completion(YES, tok, accName, nil);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, nil, nil, nil);
            });
        }
    }];
}

- (void)fetchAccountInfoWithCompletion:(void (^)(NSString *accountName, NSError *error))completion {
    if (![self isAuthorized]) {
        if (completion) completion(nil, nil);
        return;
    }
    NSURLRequest *req = [self requestWithPath:@"/account" method:@"GET" body:nil];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSError *apiErr = [self errorFromResponse:resp data:data networkError:err];
        if (apiErr || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(self.accountName, apiErr);
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *accName = ([json isKindOfClass:[NSDictionary class]] && [json[@"account_name"] isKindOfClass:[NSString class]]) ? json[@"account_name"] : @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            if (accName.length > 0) {
                [self saveToken:self.token accountName:accName];
            }
            if (completion) completion(self.accountName, nil);
        });
    }];
}

- (void)fetchLikesWithCompletion:(void (^)(NSArray *tracks, NSError *error))completion {
    if (![self isAuthorized]) {
        if (completion) completion(@[], nil);
        return;
    }
    NSURLRequest *req = [self requestWithPath:@"/likes" method:@"GET" body:nil];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSError *apiErr = [self errorFromResponse:resp data:data networkError:err];
        if (apiErr || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, apiErr);
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *rawList = ([json isKindOfClass:[NSDictionary class]] && [json[@"tracks"] isKindOfClass:[NSArray class]]) ? json[@"tracks"] : @[];
        NSMutableArray *parsed = [NSMutableArray arrayWithCapacity:rawList.count];
        for (NSDictionary *d in rawList) {
            if ([d isKindOfClass:[NSDictionary class]]) {
                [parsed addObject:[YMTrack trackFromDictionary:d baseURL:self.baseURL token:self.token]];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(parsed, nil);
        });
    }];
}

- (void)addTrackToLikes:(NSString *)trackId completion:(void (^)(BOOL success, NSError *error))completion {
    if (!trackId || trackId.length == 0) return;
    NSURLRequest *req = [self requestWithPath:@"/likes/add" method:@"POST" body:@{@"track_ids": @[trackId]}];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSError *apiErr = [self errorFromResponse:resp data:data networkError:err];
        BOOL ok = (apiErr == nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) [[NSNotificationCenter defaultCenter] postNotificationName:YMLikesUpdatedNotification object:nil];
            if (completion) completion(ok, apiErr);
        });
    }];
}

- (void)removeTracksFromLikes:(NSArray *)trackIds completion:(void (^)(BOOL success, NSError *error))completion {
    if (trackIds.count == 0) return;
    NSURLRequest *req = [self requestWithPath:@"/likes/remove" method:@"POST" body:@{@"track_ids": trackIds}];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSError *apiErr = [self errorFromResponse:resp data:data networkError:err];
        BOOL ok = (apiErr == nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(ok, apiErr);
        });
    }];
}

- (void)searchWithQuery:(NSString *)query completion:(void (^)(NSArray *tracks, NSArray *artists, NSArray *albums, NSError *error))completion {
    NSString *encoded = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault,
        (CFStringRef)query,
        NULL,
        CFSTR("!*'();:@&=+$,/?#[] "),
        kCFStringEncodingUTF8
    ));
    NSString *path = [NSString stringWithFormat:@"/search?q=%@", encoded ?: @""];
    NSURLRequest *req = [self requestWithPath:path method:@"GET" body:nil];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSError *apiErr = [self errorFromResponse:resp data:data networkError:err];
        if (apiErr || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[], @[], @[], apiErr);
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSMutableArray *tracks = [NSMutableArray array];
        if ([json isKindOfClass:[NSDictionary class]] && [json[@"tracks"] isKindOfClass:[NSArray class]]) {
            for (NSDictionary *d in json[@"tracks"]) {
                if ([d isKindOfClass:[NSDictionary class]]) {
                    [tracks addObject:[YMTrack trackFromDictionary:d baseURL:self.baseURL token:self.token]];
                }
            }
        }
        NSArray *artists = ([json isKindOfClass:[NSDictionary class]] && [json[@"artists"] isKindOfClass:[NSArray class]]) ? json[@"artists"] : @[];
        NSArray *albums = ([json isKindOfClass:[NSDictionary class]] && [json[@"albums"] isKindOfClass:[NSArray class]]) ? json[@"albums"] : @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(tracks, artists, albums, nil);
        });
    }];
}

- (void)loadImageWithURL:(NSString *)urlString completion:(void (^)(UIImage *image))completion {
    if (!urlString || urlString.length == 0) {
        if (completion) completion(nil);
        return;
    }
    UIImage *cached = [self.imageCache objectForKey:urlString];
    if (cached) {
        if (completion) completion(cached);
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                                       cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                   timeoutInterval:15.0];
    [req setValue:@"close" forHTTPHeaderField:@"Connection"];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        UIImage *img = (data && !err) ? [UIImage imageWithData:data] : nil;
        if (img) {
            [self.imageCache setObject:img forKey:urlString];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(img);
        });
    }];
}

@end

#pragma mark - YMDownloadManager

@interface YMDownloadManager ()
@property (nonatomic, strong) NSMutableArray *downloads;
@property (nonatomic, copy) NSString *downloadsDir;
@property (nonatomic, copy) NSString *manifestPath;
@property (nonatomic, strong) NSOperationQueue *dlQueue;
@end

@implementation YMDownloadManager

+ (instancetype)shared {
    static YMDownloadManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YMDownloadManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        _downloadsDir = [docs stringByAppendingPathComponent:@"Downloads"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_downloadsDir withIntermediateDirectories:YES attributes:nil error:nil];
        _manifestPath = [_downloadsDir stringByAppendingPathComponent:@"manifest.json"];
        _dlQueue = [[NSOperationQueue alloc] init];
        _dlQueue.maxConcurrentOperationCount = 2;
        _downloads = [NSMutableArray array];
        [self loadManifest];
    }
    return self;
}

- (void)loadManifest {
    NSData *data = [NSData dataWithContentsOfFile:self.manifestPath];
    if (!data) return;
    NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![arr isKindOfClass:[NSArray class]]) return;
    [self.downloads removeAllObjects];
    NSString *base = [YMApiClient shared].baseURL;
    NSString *tok = [YMApiClient shared].token;
    for (NSDictionary *d in arr) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        YMTrack *t = [YMTrack trackFromDictionary:d baseURL:base token:tok];
        t.localAudioPath = [self.downloadsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3", t.trackId]];
        t.localCoverPath = [self.downloadsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg", t.trackId]];
        [self.downloads addObject:t];
    }
}

- (void)saveManifest {
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:self.downloads.count];
    for (YMTrack *t in self.downloads) {
        [arr addObject:[t toDictionary]];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:arr options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:self.manifestPath atomically:YES];
}

- (NSArray *)downloadedTracks {
    return [self.downloads copy];
}

- (BOOL)isTrackDownloaded:(NSString *)trackId {
    for (YMTrack *t in self.downloads) {
        if ([t.trackId isEqualToString:trackId]) {
            return [[NSFileManager defaultManager] fileExistsAtPath:t.localAudioPath];
        }
    }
    return NO;
}

- (void)downloadTrack:(YMTrack *)track completion:(void (^)(BOOL success, NSError *error))completion {
    if ([self isTrackDownloaded:track.trackId]) {
        if (completion) completion(YES, nil);
        return;
    }
    [[YMApiClient shared] reloadConfig];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:track.streamURL]
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:90.0];
    [req setValue:@"close" forHTTPHeaderField:@"Connection"];
    if ([YMApiClient shared].token.length > 0) {
        [req setValue:[YMApiClient shared].token forHTTPHeaderField:@"X-Ya-Token"];
    }

    [NSURLConnection sendAsynchronousRequest:req queue:self.dlQueue completionHandler:^(NSURLResponse *resp, NSData *audioData, NSError *err) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
        if (err || (http && http.statusCode >= 400) || !audioData || audioData.length < 1024) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, err);
            });
            return;
        }
        NSString *mp3Path = [self.downloadsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3", track.trackId]];
        [audioData writeToFile:mp3Path atomically:YES];

        NSString *jpgPath = [self.downloadsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg", track.trackId]];
        if (track.coverURL.length > 0) {
            NSData *imgData = [NSData dataWithContentsOfURL:[NSURL URLWithString:track.coverURL]];
            if (imgData) [imgData writeToFile:jpgPath atomically:YES];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            YMTrack *saved = [YMTrack trackFromDictionary:[track toDictionary]
                                                  baseURL:[YMApiClient shared].baseURL
                                                    token:[YMApiClient shared].token];
            saved.localAudioPath = mp3Path;
            saved.localCoverPath = jpgPath;
            [self.downloads insertObject:saved atIndex:0];
            [self saveManifest];
            [[NSNotificationCenter defaultCenter] postNotificationName:YMDownloadsUpdatedNotification object:nil];
            if (completion) completion(YES, nil);
        });
    }];
}

- (void)deleteDownloadedTracksWithIds:(NSArray *)trackIds {
    NSSet *idSet = [NSSet setWithArray:trackIds];
    NSMutableArray *toRemove = [NSMutableArray array];
    for (YMTrack *t in self.downloads) {
        if ([idSet containsObject:t.trackId]) {
            [[NSFileManager defaultManager] removeItemAtPath:t.localAudioPath error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:t.localCoverPath error:nil];
            [toRemove addObject:t];
        }
    }
    [self.downloads removeObjectsInArray:toRemove];
    [self saveManifest];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMDownloadsUpdatedNotification object:nil];
}

@end

#pragma mark - YMPlayerManager

@interface YMPlayerManager ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) NSArray *queue;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong, readwrite) YMTrack *currentTrack;
@property (nonatomic, assign, readwrite) BOOL isPlaying;
@property (nonatomic, assign, readwrite) NSTimeInterval currentTime;
@property (nonatomic, assign, readwrite) NSTimeInterval totalDuration;
@end

@implementation YMPlayerManager

+ (instancetype)shared {
    static YMPlayerManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YMPlayerManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
        [session setActive:YES error:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(itemDidFinishPlaying:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];
    }
    return self;
}

- (void)playQueue:(NSArray *)tracks startIndex:(NSInteger)index {
    if (tracks.count == 0 || index < 0 || index >= (NSInteger)tracks.count) return;
    self.queue = [tracks copy];
    self.currentIndex = index;
    [self startCurrentTrack];
}

- (void)startCurrentTrack {
    if (self.currentIndex < 0 || self.currentIndex >= (NSInteger)self.queue.count) return;
    YMTrack *track = self.queue[self.currentIndex];
    self.currentTrack = track;
    self.currentTime = 0;
    self.totalDuration = track.duration;

    if (self.player && self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }

    NSURL *playURL = nil;
    if (track.localAudioPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:track.localAudioPath]) {
        playURL = [NSURL fileURLWithPath:track.localAudioPath];
    } else {
        for (YMTrack *dl in [[YMDownloadManager shared] downloadedTracks]) {
            if ([dl.trackId isEqualToString:track.trackId] && [[NSFileManager defaultManager] fileExistsAtPath:dl.localAudioPath]) {
                playURL = [NSURL fileURLWithPath:dl.localAudioPath];
                break;
            }
        }
        if (!playURL) {
            playURL = [NSURL URLWithString:track.streamURL];
        }
    }

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:playURL];
    self.player = [AVPlayer playerWithPlayerItem:item];

    __weak typeof(self) weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2)
                                                                  queue:dispatch_get_main_queue()
                                                             usingBlock:^(CMTime time) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        double sec = CMTimeGetSeconds(time);
        if (!isnan(sec) && !isinf(sec)) {
            strongSelf.currentTime = sec;
        }
        CMTime dur = strongSelf.player.currentItem.duration;
        double dSec = CMTimeGetSeconds(dur);
        if (!isnan(dSec) && !isinf(dSec) && dSec > 0) {
            strongSelf.totalDuration = dSec;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
    }];

    [self.player play];
    self.isPlaying = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
}

- (void)togglePlayPause {
    if (!self.player) return;
    if (self.isPlaying) {
        [self.player pause];
        self.isPlaying = NO;
    } else {
        [self.player play];
        self.isPlaying = YES;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
}

- (void)nextTrack {
    if (self.queue.count == 0) return;
    self.currentIndex = (self.currentIndex + 1) % self.queue.count;
    [self startCurrentTrack];
}

- (void)previousTrack {
    if (self.queue.count == 0) return;
    if (self.currentTime > 3.0) {
        [self seekToSeconds:0];
        return;
    }
    self.currentIndex = (self.currentIndex - 1 + self.queue.count) % self.queue.count;
    [self startCurrentTrack];
}

- (void)seekToSeconds:(NSTimeInterval)seconds {
    if (!self.player) return;
    [self.player seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC)];
    self.currentTime = seconds;
    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
}

- (float)volume {
    return [[MPMusicPlayerController applicationMusicPlayer] volume];
}

- (void)setVolume:(float)volume {
    [[MPMusicPlayerController applicationMusicPlayer] setVolume:volume];
}

- (void)itemDidFinishPlaying:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self nextTrack];
    });
}

@end