#import "YMCore.h"

NSString * const YMPlayerStateChangedNotification = @"YMPlayerStateChangedNotification";
NSString * const YMDownloadsUpdatedNotification = @"YMDownloadsUpdatedNotification";
NSString * const YMLikesUpdatedNotification = @"YMLikesUpdatedNotification";
NSString * const YMAuthStateChangedNotification = @"YMAuthStateChangedNotification";

static NSString * const kDefaultProxyBaseURL = @"http://<YOUR_SERVER_IP>:6500";
static NSString * const kYMStoredTokenKey = @"YMOAuthStoredToken";
static NSString * const kYMStoredAccountNameKey = @"YMOAuthStoredAccountName";

static const NSTimeInterval kYMMinPrebufferSeconds = 4.0;
static void *kYMPlayerItemKVOContext = &kYMPlayerItemKVOContext;

@implementation YMTrack

+ (NSString *)upgradeCoverURLToHighRes:(NSString *)urlStr {
    if (!urlStr || urlStr.length == 0) return @"";
    NSString *res = urlStr;

    NSArray *lowResSlashes = @[
        @"/50x50", @"/100x100", @"/150x150", @"/200x200",
        @"/300x300", @"/400x400", @"/600x600", @"/700x700", @"/800x800", @"/%%"
    ];
    for (NSString *pat in lowResSlashes) {
        if ([res rangeOfString:pat].location != NSNotFound) {
            res = [res stringByReplacingOccurrencesOfString:pat withString:@"/1000x1000"];
        }
    }

    if ([res rangeOfString:@"%%"].location != NSNotFound) {
        res = [res stringByReplacingOccurrencesOfString:@"%%" withString:@"1000x1000"];
    }

    NSArray *lowResParams = @[
        @"size=50x50", @"size=100x100", @"size=150x150", @"size=200x200",
        @"size=300x300", @"size=400x400", @"size=600x600", @"size=700x700", @"size=800x800"
    ];
    for (NSString *qpat in lowResParams) {
        if ([res rangeOfString:qpat].location != NSNotFound) {
            res = [res stringByReplacingOccurrencesOfString:qpat withString:@"size=1000x1000"];
        }
    }

    return res;
}

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
    t.rotorId = [dict[@"rotor_id"] isKindOfClass:[NSString class]] ? dict[@"rotor_id"] : t.trackId;
    t.title = [dict[@"title"] isKindOfClass:[NSString class]] ? dict[@"title"] : @"Без названия";
    t.artist = [dict[@"artist"] isKindOfClass:[NSString class]] ? dict[@"artist"] : @"Неизвестен";
    t.album = [dict[@"album"] isKindOfClass:[NSString class]] ? dict[@"album"] : @"";
    t.duration = [dict[@"duration"] respondsToSelector:@selector(integerValue)] ? [dict[@"duration"] integerValue] : 0;

    NSString *rawCover = [dict[@"cover_url"] isKindOfClass:[NSString class]] ? dict[@"cover_url"] : @"";
    NSString *normalizedCover = [self normalizeURL:rawCover baseURL:baseURL];
    t.coverURL = normalizedCover;
    t.highResCoverURL = [self upgradeCoverURLToHighRes:normalizedCover];

    NSString *rawStream = [NSString stringWithFormat:@"%@/get-stream/%@.mp3", baseURL, t.trackId];
    t.streamURL = rawStream;

    t.localAudioPath = [dict[@"local_audio"] isKindOfClass:[NSString class]] ? dict[@"local_audio"] : @"";
    t.localCoverPath = [dict[@"local_cover"] isKindOfClass:[NSString class]] ? dict[@"local_cover"] : @"";
    return t;
}

- (NSDictionary *)toDictionary {
    return @{
        @"id": self.trackId ?: @"",
        @"rotor_id": self.rotorId ?: (self.trackId ?: @""),
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
@property (nonatomic, strong) NSMutableSet *likedTrackIds;
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
        _likedTrackIds = [NSMutableSet set];

        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        _token = [defs stringForKey:kYMStoredTokenKey] ?: @"";
        _accountName = [defs stringForKey:kYMStoredAccountNameKey] ?: @"";

        [self reloadConfig];
    }
    return self;
}

- (NSSet *)likedTrackIdSet {
    return [self.likedTrackIds copy];
}

- (BOOL)isTrackLiked:(NSString *)trackId {
    if (!trackId || trackId.length == 0) return NO;
    return [self.likedTrackIds containsObject:trackId];
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
    BOOL tokenChanged = ![self.token isEqualToString:(token ?: @"")];
    BOOL nameChanged = (accountName && accountName.length > 0 && ![self.accountName isEqualToString:accountName]);

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

    // Уведомляем об изменении авторизации только если реально сменился токен или имя
    if (tokenChanged || nameChanged) {
        [[NSNotificationCenter defaultCenter] postNotificationName:YMAuthStateChangedNotification object:nil];
    }
}

- (void)logout {
    self.token = @"";
    self.accountName = @"";
    [self.likedTrackIds removeAllObjects];
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
            if (accName.length > 0 && ![self.accountName isEqualToString:accName]) {
                self.accountName = accName;
                NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                [defs setObject:self.accountName forKey:kYMStoredAccountNameKey];
                [defs synchronize];
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
        NSMutableSet *freshIds = [NSMutableSet setWithCapacity:rawList.count];
        for (NSDictionary *d in rawList) {
            if ([d isKindOfClass:[NSDictionary class]]) {
                YMTrack *t = [YMTrack trackFromDictionary:d baseURL:self.baseURL token:self.token];
                [parsed addObject:t];
                if (t.trackId.length > 0) {
                    [freshIds addObject:t.trackId];
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.likedTrackIds = freshIds;
            if (completion) completion(parsed, nil);
        });
    }];
}

- (void)toggleLikeTrack:(YMTrack *)track completion:(void (^)(BOOL isLiked))completion {
    if (!track || track.trackId.length == 0 || ![self isAuthorized]) {
        if (completion) completion(NO);
        return;
    }
    BOOL currentlyLiked = [self.likedTrackIds containsObject:track.trackId];
    __weak typeof(self) weakSelf = self;

    if (currentlyLiked) {
        [self.likedTrackIds removeObject:track.trackId];
        [[NSNotificationCenter defaultCenter] postNotificationName:YMLikesUpdatedNotification object:nil];
        [self removeTracksFromLikes:@[track.trackId] completion:^(BOOL success, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!success && strongSelf) {
                [strongSelf.likedTrackIds addObject:track.trackId];
                [[NSNotificationCenter defaultCenter] postNotificationName:YMLikesUpdatedNotification object:nil];
            }
            if (completion) completion(!success);
        }];
    } else {
        [self.likedTrackIds addObject:track.trackId];
        [[NSNotificationCenter defaultCenter] postNotificationName:YMLikesUpdatedNotification object:nil];
        [self addTrackToLikes:track.trackId completion:^(BOOL success, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!success && strongSelf) {
                [strongSelf.likedTrackIds removeObject:track.trackId];
                [[NSNotificationCenter defaultCenter] postNotificationName:YMLikesUpdatedNotification object:nil];
            }
            if (completion) completion(success);
        }];
    }
}

- (void)toggleLikeForTrack:(YMTrack *)track completion:(void (^)(BOOL isLiked))completion {
    [self toggleLikeTrack:track completion:completion];
}

- (void)fetchMyWaveTracksWithReset:(BOOL)reset afterTrackId:(NSString *)lastTrackId completion:(void (^)(NSArray *tracks, NSError *error))completion {
    if (![self isAuthorized]) {
        if (completion) completion(@[], nil);
        return;
    }
    NSMutableString *path = [NSMutableString stringWithFormat:@"/rotor/wave?reset=%d", reset ? 1 : 0];
    if (lastTrackId && lastTrackId.length > 0) {
        NSString *encoded = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
            kCFAllocatorDefault,
            (CFStringRef)lastTrackId,
            NULL,
            CFSTR("!*'();:@&=+$,/?#[] "),
            kCFStringEncodingUTF8
        ));
        [path appendFormat:@"&queue=%@", encoded ?: lastTrackId];
    }
    NSURLRequest *req = [self requestWithPath:path method:@"GET" body:nil];
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

- (void)sendRotorFeedbackType:(NSString *)type trackId:(NSString *)trackId playedSeconds:(NSTimeInterval)playedSeconds {
    if (![self isAuthorized] || !type || !trackId || trackId.length == 0) return;
    NSDictionary *body = @{
        @"type": type,
        @"track_id": trackId,
        @"played_seconds": @(MAX(0.0, playedSeconds))
    };
    NSURLRequest *req = [self requestWithPath:@"/rotor/feedback" method:@"POST" body:body];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {}];
}

- (void)preloadStreamForTrackId:(NSString *)trackId {
    if (![self isAuthorized] || !trackId || trackId.length == 0) return;
    NSString *path = [NSString stringWithFormat:@"/preload/%@", trackId];
    NSURLRequest *req = [self requestWithPath:path method:@"POST" body:@{}];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {}];
}

- (void)addTrackToLikes:(NSString *)trackId completion:(void (^)(BOOL success, NSError *error))completion {
    if (!trackId || trackId.length == 0) return;
    [self.likedTrackIds addObject:trackId];
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
    for (NSString *tid in trackIds) {
        [self.likedTrackIds removeObject:tid];
    }
    NSURLRequest *req = [self requestWithPath:@"/likes/remove" method:@"POST" body:@{@"track_ids": trackIds}];
    [NSURLConnection sendAsynchronousRequest:req queue:self.netQueue completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSError *apiErr = [self errorFromResponse:resp data:data networkError:err];
        BOOL ok = (apiErr == nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) [[NSNotificationCenter defaultCenter] postNotificationName:YMLikesUpdatedNotification object:nil];
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
                                                   timeoutInterval:25.0];
    [req setValue:@"close" forHTTPHeaderField:@"Connection"];
    if (self.token.length > 0) {
        [req setValue:self.token forHTTPHeaderField:@"X-Ya-Token"];
    }
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

- (NSData *)synchronousCoverDataFromURL:(NSString *)urlStr {
    if (!urlStr || urlStr.length == 0) return nil;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:35.0];
    [req setValue:@"close" forHTTPHeaderField:@"Connection"];
    if ([YMApiClient shared].token.length > 0) {
        [req setValue:[YMApiClient shared].token forHTTPHeaderField:@"X-Ya-Token"];
    }
    NSURLResponse *resp = nil;
    NSError *err = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
    if (err || (http && http.statusCode >= 400) || !data || data.length < 256) {
        return nil;
    }
    return data;
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

        // При скачивании трека сохраняем обложку в высоком разрешении (1000x1000)
        NSString *jpgPath = [self.downloadsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg", track.trackId]];
        NSString *hiResURL = track.highResCoverURL.length > 0 ? track.highResCoverURL : [YMTrack upgradeCoverURLToHighRes:track.coverURL];
        if (hiResURL.length > 0) {
            NSData *imgData = [self synchronousCoverDataFromURL:hiResURL];
            if (!imgData && ![hiResURL isEqualToString:track.coverURL]) {
                imgData = [self synchronousCoverDataFromURL:track.coverURL];
            }
            if (imgData) {
                [imgData writeToFile:jpgPath atomically:YES];
            }
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
@property (nonatomic, strong) AVPlayerItem *observedItem;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) NSArray *originalQueue;
@property (nonatomic, strong) NSArray *queue;
@property (nonatomic, strong) NSArray *savedPlaylistOriginalQueue;
@property (nonatomic, strong) NSArray *savedPlaylistQueue;
@property (nonatomic, assign) NSInteger savedPlaylistIndex;
@property (nonatomic, assign) BOOL savedShuffleState;
@property (nonatomic, strong) NSMutableSet *seenWaveTrackIds;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong, readwrite) YMTrack *currentTrack;
@property (nonatomic, assign, readwrite) BOOL isPlaying;
@property (nonatomic, assign, readwrite) BOOL isBuffering;
@property (nonatomic, assign, readwrite) float bufferedProgress;
@property (nonatomic, assign) BOOL userWantsToPlay;
@property (nonatomic, assign) BOOL isCurrentTrackLocal;
@property (nonatomic, assign, readwrite) BOOL isShuffleEnabled;
@property (nonatomic, assign, readwrite) BOOL isRepeatTrackEnabled;
@property (nonatomic, assign, readwrite) BOOL isMyWaveMode;
@property (nonatomic, assign) BOOL isFetchingWave;
@property (nonatomic, assign) BOOL waitingForNextWaveBatch;
@property (nonatomic, assign, readwrite) NSTimeInterval currentTime;
@property (nonatomic, assign, readwrite) NSTimeInterval totalDuration;
@property (nonatomic, strong) MPMediaItemArtwork *currentArtwork;
@property (nonatomic, copy) NSString *artworkTrackId;
@property (nonatomic, assign) BOOL hasSyncedResolvedDuration;
@end

@implementation YMPlayerManager

- (void)dealloc {
    [self detachPlayerItemObservers];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

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
        _seenWaveTrackIds = [NSMutableSet set];
        [self configureAudioSession];

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(itemDidFinishPlaying:)
                   name:AVPlayerItemDidPlayToEndTimeNotification
                 object:nil];

        [nc addObserver:self
               selector:@selector(handleAudioSessionInterruption:)
                   name:AVAudioSessionInterruptionNotification
                 object:nil];

        [nc addObserver:self
               selector:@selector(handleAudioSessionRouteChange:)
                   name:AVAudioSessionRouteChangeNotification
                 object:nil];
    }
    return self;
}

- (void)configureAudioSession {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

- (void)handleAudioSessionInterruption:(NSNotification *)note {
    NSNumber *typeNum = note.userInfo[AVAudioSessionInterruptionTypeKey];
    if (!typeNum) return;
    AVAudioSessionInterruptionType type = (AVAudioSessionInterruptionType)[typeNum unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        [self pause];
    } else if (type == AVAudioSessionInterruptionTypeEnded) {
        NSNumber *optNum = note.userInfo[AVAudioSessionInterruptionOptionKey];
        if ([optNum unsignedIntegerValue] & AVAudioSessionInterruptionOptionShouldResume) {
            [self play];
        }
    }
}

- (void)handleAudioSessionRouteChange:(NSNotification *)note {
    NSNumber *reasonNum = note.userInfo[AVAudioSessionRouteChangeReasonKey];
    if (!reasonNum) return;
    AVAudioSessionRouteChangeReason reason = (AVAudioSessionRouteChangeReason)[reasonNum unsignedIntegerValue];
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pause];
        });
    }
}

- (NSArray *)shuffledArrayFromTracks:(NSArray *)tracks keepingFirstTrack:(YMTrack *)firstTrack {
    NSMutableArray *pool = [tracks mutableCopy];
    if (firstTrack) {
        NSUInteger foundIdx = [pool indexOfObjectPassingTest:^BOOL(YMTrack *obj, NSUInteger idx, BOOL *stop) {
            return [obj.trackId isEqualToString:firstTrack.trackId];
        }];
        if (foundIdx != NSNotFound) {
            [pool removeObjectAtIndex:foundIdx];
        }
    }
    for (NSUInteger i = pool.count; i > 1; i--) {
        u_int32_t j = arc4random_uniform((u_int32_t)i);
        [pool exchangeObjectAtIndex:(i - 1) withObjectAtIndex:j];
    }
    if (firstTrack) {
        [pool insertObject:firstTrack atIndex:0];
    }
    return [pool copy];
}

- (void)playQueue:(NSArray *)tracks startIndex:(NSInteger)index {
    if (tracks.count == 0 || index < 0 || index >= (NSInteger)tracks.count) return;
    self.isMyWaveMode = NO;
    self.isFetchingWave = NO;
    self.waitingForNextWaveBatch = NO;
    self.originalQueue = [tracks copy];

    if (self.isShuffleEnabled) {
        YMTrack *selected = tracks[index];
        self.queue = [self shuffledArrayFromTracks:self.originalQueue keepingFirstTrack:selected];
        self.currentIndex = 0;
    } else {
        self.queue = [self.originalQueue copy];
        self.currentIndex = index;
    }

    self.savedPlaylistOriginalQueue = [self.originalQueue copy];
    self.savedPlaylistQueue = [self.queue copy];
    self.savedPlaylistIndex = self.currentIndex;
    self.savedShuffleState = self.isShuffleEnabled;

    [self startCurrentTrack];
}

- (void)toggleMyWave {
    if (self.isMyWaveMode) {
        [self stopMyWave];
    } else {
        [self startMyWave];
    }
}

- (void)stopMyWave {
    if (!self.isMyWaveMode && !self.isFetchingWave) return;

    self.isMyWaveMode = NO;
    self.isFetchingWave = NO;
    self.waitingForNextWaveBatch = NO;
    self.userWantsToPlay = NO;
    self.isBuffering = NO;
    self.isPlaying = NO;

    if (self.player && self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    [self detachPlayerItemObservers];
    if (self.player) {
        [self.player pause];
        self.player = nil;
    }

    if (self.savedPlaylistOriginalQueue.count > 0 && self.savedPlaylistQueue.count > 0) {
        self.originalQueue = [self.savedPlaylistOriginalQueue copy];
        self.queue = [self.savedPlaylistQueue copy];
        self.isShuffleEnabled = self.savedShuffleState;
        self.currentIndex = MIN(MAX(0, self.savedPlaylistIndex), (NSInteger)self.queue.count - 1);
        self.currentTrack = self.queue[self.currentIndex];
        self.currentTime = 0;
        self.totalDuration = self.currentTrack.duration;
        [self loadArtworkForTrack:self.currentTrack];
    } else {
        self.originalQueue = @[];
        self.queue = @[];
        self.currentIndex = 0;
        self.currentTrack = nil;
        self.currentTime = 0;
        self.totalDuration = 0;
        self.currentArtwork = nil;
        self.artworkTrackId = nil;
    }

    [self updateSystemNowPlayingInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
}

- (void)startMyWave {
    if (self.isFetchingWave) return;

    if (!self.isMyWaveMode && self.originalQueue.count > 0) {
        self.savedPlaylistOriginalQueue = [self.originalQueue copy];
        self.savedPlaylistQueue = [self.queue copy];
        self.savedPlaylistIndex = self.currentIndex;
        self.savedShuffleState = self.isShuffleEnabled;
    }

    self.isFetchingWave = YES;
    self.isMyWaveMode = YES;
    self.waitingForNextWaveBatch = NO;
    self.isShuffleEnabled = NO;
    [self.seenWaveTrackIds removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];

    [[YMApiClient shared] fetchMyWaveTracksWithReset:YES afterTrackId:nil completion:^(NSArray *tracks, NSError *error) {
        self.isFetchingWave = NO;
        if (!self.isMyWaveMode) return;

        if (tracks && tracks.count > 0) {
            NSMutableArray *initial = [NSMutableArray array];
            for (YMTrack *t in tracks) {
                if (t.trackId.length > 0 && ![self.seenWaveTrackIds containsObject:t.trackId]) {
                    [self.seenWaveTrackIds addObject:t.trackId];
                    [initial addObject:t];
                }
            }
            if (initial.count == 0) {
                [initial addObjectsFromArray:tracks];
            }
            self.originalQueue = [initial copy];
            self.queue = [initial copy];
            self.currentIndex = 0;
            [self startCurrentTrack];
            [self preloadMoreWaveTracksIfNeededForced:YES];
        } else {
            [self stopMyWave];
        }
    }];
}

- (void)preloadMoreWaveTracksIfNeededForced:(BOOL)forced {
    if (!self.isMyWaveMode || self.isFetchingWave) return;
    if (!forced && self.currentIndex < (NSInteger)self.queue.count - 3) return;

    self.isFetchingWave = YES;
    YMTrack *lastTrack = self.queue.lastObject;
    NSString *queueAnchor = lastTrack ? (lastTrack.rotorId.length > 0 ? lastTrack.rotorId : lastTrack.trackId) : nil;

    [[YMApiClient shared] fetchMyWaveTracksWithReset:NO afterTrackId:queueAnchor completion:^(NSArray *tracks, NSError *error) {
        self.isFetchingWave = NO;
        if (!self.isMyWaveMode) return;

        if (tracks && tracks.count > 0) {
            NSMutableArray *extended = [self.queue mutableCopy] ?: [NSMutableArray array];
            NSUInteger addedCount = 0;
            for (YMTrack *t in tracks) {
                if (t.trackId.length > 0 && ![self.seenWaveTrackIds containsObject:t.trackId]) {
                    [self.seenWaveTrackIds addObject:t.trackId];
                    [extended addObject:t];
                    addedCount++;
                }
            }
            if (addedCount == 0) {
                [self.seenWaveTrackIds removeAllObjects];
                for (YMTrack *t in tracks) {
                    if (t.trackId.length > 0) {
                        [self.seenWaveTrackIds addObject:t.trackId];
                        [extended addObject:t];
                    }
                }
            }
            self.queue = [extended copy];
            self.originalQueue = [extended copy];

            if (self.waitingForNextWaveBatch && self.currentIndex + 1 < (NSInteger)self.queue.count) {
                self.waitingForNextWaveBatch = NO;
                self.currentIndex += 1;
                [self startCurrentTrack];
            }
        }
    }];
}

- (void)toggleShuffle {
    if (self.isMyWaveMode) return;

    self.isShuffleEnabled = !self.isShuffleEnabled;
    self.savedShuffleState = self.isShuffleEnabled;

    if (self.originalQueue.count > 0) {
        if (self.isShuffleEnabled) {
            self.queue = [self shuffledArrayFromTracks:self.originalQueue keepingFirstTrack:self.currentTrack];
            self.currentIndex = 0;
        } else {
            self.queue = [self.originalQueue copy];
            NSUInteger origIdx = 0;
            if (self.currentTrack) {
                NSUInteger found = [self.queue indexOfObjectPassingTest:^BOOL(YMTrack *obj, NSUInteger idx, BOOL *stop) {
                    return [obj.trackId isEqualToString:self.currentTrack.trackId];
                }];
                if (found != NSNotFound) {
                    origIdx = found;
                }
            }
            self.currentIndex = (NSInteger)origIdx;
        }
        self.savedPlaylistQueue = [self.queue copy];
        self.savedPlaylistIndex = self.currentIndex;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
}

- (void)toggleRepeatTrack {
    self.isRepeatTrackEnabled = !self.isRepeatTrackEnabled;
    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
}

- (void)loadArtworkForTrack:(YMTrack *)track {
    if (!track) return;
    NSString *expectedTrackId = [track.trackId copy];

    if (![self.artworkTrackId isEqualToString:expectedTrackId]) {
        self.artworkTrackId = expectedTrackId;
        self.currentArtwork = nil;
    }

    if (track.localCoverPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:track.localCoverPath]) {
        UIImage *localImg = [UIImage imageWithContentsOfFile:track.localCoverPath];
        if (localImg) {
            self.currentArtwork = [[MPMediaItemArtwork alloc] initWithImage:localImg];
            [self updateSystemNowPlayingInfo];
            return;
        }
    }

    for (YMTrack *dl in [[YMDownloadManager shared] downloadedTracks]) {
        if ([dl.trackId isEqualToString:expectedTrackId] && dl.localCoverPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:dl.localCoverPath]) {
            UIImage *dlImg = [UIImage imageWithContentsOfFile:dl.localCoverPath];
            if (dlImg) {
                self.currentArtwork = [[MPMediaItemArtwork alloc] initWithImage:dlImg];
                [self updateSystemNowPlayingInfo];
                return;
            }
        }
    }

    // Для системного плеера и экрана блокировки запрашиваем обложку в 1000x1000
    NSString *hiResURL = track.highResCoverURL.length > 0 ? track.highResCoverURL : [YMTrack upgradeCoverURLToHighRes:track.coverURL];
    if (hiResURL.length > 0) {
        [[YMApiClient shared] loadImageWithURL:hiResURL completion:^(UIImage *image) {
            if (image && [self.currentTrack.trackId isEqualToString:expectedTrackId]) {
                self.currentArtwork = [[MPMediaItemArtwork alloc] initWithImage:image];
                [self updateSystemNowPlayingInfo];
            }
        }];
    }
}

- (void)updateSystemNowPlayingInfo {
    if (!NSClassFromString(@"MPNowPlayingInfoCenter")) return;
    YMTrack *track = self.currentTrack;
    if (!track) {
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
        return;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = track.title ?: @"Без названия";
    info[MPMediaItemPropertyArtist] = track.artist ?: @"Неизвестен";

    NSString *albumTitle = self.isMyWaveMode ? @"Моя Волна" : (track.album ?: @"");
    if (albumTitle.length > 0) {
        info[MPMediaItemPropertyAlbumTitle] = albumTitle;
    }

    NSTimeInterval dur = (self.totalDuration > 0) ? self.totalDuration : (NSTimeInterval)MAX(1, track.duration);
    info[MPMediaItemPropertyPlaybackDuration] = @(dur);
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(MAX(0.0, self.currentTime));
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(self.isPlaying ? 1.0 : 0.0);

    if (self.currentArtwork) {
        info[MPMediaItemPropertyArtwork] = self.currentArtwork;
    }

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
}

- (void)handleRemoteControlEvent:(UIEvent *)event {
    if (event.type != UIEventTypeRemoteControl) return;
    switch (event.subtype) {
        case UIEventSubtypeRemoteControlPlay:
            [self play];
            break;
        case UIEventSubtypeRemoteControlPause:
        case UIEventSubtypeRemoteControlStop:
            [self pause];
            break;
        case UIEventSubtypeRemoteControlTogglePlayPause:
            [self togglePlayPause];
            break;
        case UIEventSubtypeRemoteControlNextTrack:
            [self nextTrack];
            break;
        case UIEventSubtypeRemoteControlPreviousTrack:
            [self previousTrack];
            break;
        default:
            break;
    }
}

#pragma mark - Потоковая буферизация (KVO AVPlayerItem)

- (void)detachPlayerItemObservers {
    if (self.observedItem) {
        @try {
            [self.observedItem removeObserver:self forKeyPath:@"status" context:kYMPlayerItemKVOContext];
            [self.observedItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:kYMPlayerItemKVOContext];
            [self.observedItem removeObserver:self forKeyPath:@"playbackBufferEmpty" context:kYMPlayerItemKVOContext];
            [self.observedItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp" context:kYMPlayerItemKVOContext];
        } @catch (NSException *exception) {}
        self.observedItem = nil;
    }
}

- (void)attachObserversToPlayerItem:(AVPlayerItem *)item {
    [self detachPlayerItemObservers];
    if (!item) return;
    self.observedItem = item;
    NSKeyValueObservingOptions opts = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial;
    [item addObserver:self forKeyPath:@"status" options:opts context:kYMPlayerItemKVOContext];
    [item addObserver:self forKeyPath:@"loadedTimeRanges" options:opts context:kYMPlayerItemKVOContext];
    [item addObserver:self forKeyPath:@"playbackBufferEmpty" options:opts context:kYMPlayerItemKVOContext];
    [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:opts context:kYMPlayerItemKVOContext];
}

- (NSTimeInterval)availableBufferedSecondsForItem:(AVPlayerItem *)item {
    NSArray *ranges = item.loadedTimeRanges;
    if (!ranges || ranges.count == 0) return 0.0;
    CMTimeRange timeRange = [ranges.firstObject CMTimeRangeValue];
    double startSeconds = CMTimeGetSeconds(timeRange.start);
    double durationSeconds = CMTimeGetSeconds(timeRange.duration);
    if (isnan(startSeconds) || isnan(durationSeconds)) return 0.0;
    return startSeconds + durationSeconds;
}

- (void)evaluateBufferAndResumeIfNeeded {
    if (!self.player || !self.observedItem) return;
    AVPlayerItem *item = self.observedItem;

    NSTimeInterval bufferedEnd = [self availableBufferedSecondsForItem:item];
    NSTimeInterval total = MAX(1.0, self.totalDuration);
    self.bufferedProgress = (float)MIN(1.0, MAX(0.0, bufferedEnd / total));

    if (self.isCurrentTrackLocal) {
        if (self.userWantsToPlay && item.status == AVPlayerItemStatusReadyToPlay && !self.isPlaying) {
            self.isBuffering = NO;
            [self.player play];
            self.isPlaying = YES;
            [self updateSystemNowPlayingInfo];
            [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
        }
        return;
    }

    NSTimeInterval bufferedAhead = bufferedEnd - self.currentTime;
    BOOL enoughChunkLoaded = (bufferedAhead >= kYMMinPrebufferSeconds) ||
                             (bufferedEnd >= total - 1.5) ||
                             item.isPlaybackLikelyToKeepUp;

    if (self.userWantsToPlay && item.status == AVPlayerItemStatusReadyToPlay && enoughChunkLoaded) {
        if (self.isBuffering || !self.isPlaying) {
            self.isBuffering = NO;
            [self.player play];
            self.isPlaying = YES;
            [self updateSystemNowPlayingInfo];
            [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
        }
    } else if (self.userWantsToPlay && item.isPlaybackBufferEmpty && bufferedAhead < 1.0) {
        self.isBuffering = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != kYMPlayerItemKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (object != self.observedItem) return;
        [self evaluateBufferAndResumeIfNeeded];
    });
}

- (void)preloadNextTrackInQueue {
    if (self.currentIndex + 1 < (NSInteger)self.queue.count) {
        YMTrack *nextTrack = self.queue[self.currentIndex + 1];
        if (![[YMDownloadManager shared] isTrackDownloaded:nextTrack.trackId]) {
            [[YMApiClient shared] preloadStreamForTrackId:nextTrack.trackId];
        }
    }
}

- (void)startCurrentTrack {
    if (self.currentIndex < 0 || self.currentIndex >= (NSInteger)self.queue.count) return;
    [self configureAudioSession];

    if (!self.isMyWaveMode) {
        self.savedPlaylistIndex = self.currentIndex;
    }

    YMTrack *track = self.queue[self.currentIndex];
    self.currentTrack = track;
    self.currentTime = 0;
    self.totalDuration = track.duration;
    self.bufferedProgress = 0.0;
    self.hasSyncedResolvedDuration = NO;
    self.userWantsToPlay = YES;

    if (self.player && self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    [self detachPlayerItemObservers];

    NSURL *playURL = nil;
    BOOL isLocal = NO;
    if (track.localAudioPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:track.localAudioPath]) {
        playURL = [NSURL fileURLWithPath:track.localAudioPath];
        isLocal = YES;
    } else {
        for (YMTrack *dl in [[YMDownloadManager shared] downloadedTracks]) {
            if ([dl.trackId isEqualToString:track.trackId] && [[NSFileManager defaultManager] fileExistsAtPath:dl.localAudioPath]) {
                playURL = [NSURL fileURLWithPath:dl.localAudioPath];
                isLocal = YES;
                break;
            }
        }
        if (!playURL) {
            playURL = [NSURL URLWithString:track.streamURL];
            isLocal = NO;
        }
    }

    self.isCurrentTrackLocal = isLocal;
    self.isBuffering = !isLocal;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:playURL options:nil];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];

    if (self.player) {
        [self.player pause];
        [self.player replaceCurrentItemWithPlayerItem:item];
    } else {
        self.player = [AVPlayer playerWithPlayerItem:item];
    }

    [self attachObserversToPlayerItem:item];

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
            if (!strongSelf.hasSyncedResolvedDuration) {
                strongSelf.hasSyncedResolvedDuration = YES;
                [strongSelf updateSystemNowPlayingInfo];
            }
        }
        [strongSelf evaluateBufferAndResumeIfNeeded];
        [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
    }];

    if (isLocal) {
        [self.player play];
        self.isPlaying = YES;
        self.isBuffering = NO;
    } else {
        self.isPlaying = YES;
        [self evaluateBufferAndResumeIfNeeded];
    }

    if (self.isMyWaveMode) {
        [[YMApiClient shared] sendRotorFeedbackType:@"trackStarted" trackId:track.trackId playedSeconds:0];
    }

    [self loadArtworkForTrack:track];
    [self updateSystemNowPlayingInfo];
    [self preloadMoreWaveTracksIfNeededForced:NO];
    [self preloadNextTrackInQueue];

    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
}

- (void)play {
    if (!self.player) {
        if (self.queue.count > 0 && self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.queue.count) {
            [self startCurrentTrack];
        }
        return;
    }
    [self configureAudioSession];
    self.userWantsToPlay = YES;
    [self.player play];
    self.isPlaying = YES;
    self.isBuffering = NO;
    [self updateSystemNowPlayingInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
}

- (void)pause {
    if (!self.player) return;
    self.userWantsToPlay = NO;
    self.isBuffering = NO;
    [self.player pause];
    self.isPlaying = NO;
    [self updateSystemNowPlayingInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
}

- (void)togglePlayPause {
    if (!self.player) {
        if (self.queue.count > 0) {
            [self startCurrentTrack];
        }
        return;
    }
    if (self.isPlaying || self.userWantsToPlay) {
        [self pause];
    } else {
        [self play];
    }
}

- (void)nextTrack {
    if (self.queue.count == 0) return;

    if (self.isMyWaveMode && self.currentTrack) {
        NSString *fbType = (self.currentTime > 30.0) ? @"trackFinished" : @"skip";
        [[YMApiClient shared] sendRotorFeedbackType:fbType trackId:self.currentTrack.trackId playedSeconds:self.currentTime];
    }

    if (self.isMyWaveMode) {
        if (self.currentIndex + 1 < (NSInteger)self.queue.count) {
            self.currentIndex += 1;
            [self startCurrentTrack];
        } else {
            self.waitingForNextWaveBatch = YES;
            self.isBuffering = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
            [self preloadMoreWaveTracksIfNeededForced:YES];
        }
        return;
    }

    self.currentIndex = (self.currentIndex + 1) % self.queue.count;
    [self startCurrentTrack];
}

- (void)previousTrack {
    if (self.queue.count == 0) return;
    if (self.currentTime > 3.0) {
        [self seekToSeconds:0];
        return;
    }
    if (self.isMyWaveMode) {
        if (self.currentIndex > 0) {
            self.currentIndex -= 1;
            [self startCurrentTrack];
        } else {
            [self seekToSeconds:0];
        }
        return;
    }
    self.currentIndex = (self.currentIndex - 1 + self.queue.count) % self.queue.count;
    [self startCurrentTrack];
}

- (void)seekToSeconds:(NSTimeInterval)seconds {
    if (!self.player) return;
    if (!self.isCurrentTrackLocal) {
        self.isBuffering = YES;
    }
    [self.player seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC)];
    self.currentTime = seconds;
    [self evaluateBufferAndResumeIfNeeded];
    [self updateSystemNowPlayingInfo];
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
        if (self.isRepeatTrackEnabled && self.player && self.currentTrack) {
            [self.player seekToTime:kCMTimeZero];
            self.currentTime = 0;
            self.userWantsToPlay = YES;
            [self.player play];
            self.isPlaying = YES;
            [self updateSystemNowPlayingInfo];
            [[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateChangedNotification object:nil];
            return;
        }

        if (self.isMyWaveMode && self.currentTrack) {
            [[YMApiClient shared] sendRotorFeedbackType:@"trackFinished"
                                                trackId:self.currentTrack.trackId
                                          playedSeconds:MAX(30.0, self.totalDuration)];
        }
        [self nextTrack];
    });
}

@end