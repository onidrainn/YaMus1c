#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

extern NSString * const YMPlayerStateChangedNotification;
extern NSString * const YMDownloadsUpdatedNotification;
extern NSString * const YMLikesUpdatedNotification;
extern NSString * const YMAuthStateChangedNotification;

@interface YMTrack : NSObject
@property (nonatomic, copy) NSString *trackId;
@property (nonatomic, copy) NSString *rotorId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, assign) NSInteger duration;
@property (nonatomic, copy) NSString *coverURL;        // Лёгкая обложка 200x200 для таблиц
@property (nonatomic, copy) NSString *highResCoverURL; // HD-обложка 1000x1000 для плеера и загрузок
@property (nonatomic, copy) NSString *streamURL;
@property (nonatomic, copy) NSString *localAudioPath;
@property (nonatomic, copy) NSString *localCoverPath;

+ (NSString *)upgradeCoverURLToHighRes:(NSString *)urlStr;
+ (instancetype)trackFromDictionary:(NSDictionary *)dict baseURL:(NSString *)baseURL token:(NSString *)token;
- (NSDictionary *)toDictionary;
- (NSString *)formattedDuration;
@end

@interface YMApiClient : NSObject
@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy, readonly) NSString *token;
@property (nonatomic, copy, readonly) NSString *accountName;
@property (nonatomic, strong, readonly) NSSet *likedTrackIdSet;

+ (instancetype)shared;
- (void)reloadConfig;
- (BOOL)isAuthorized;
- (void)saveToken:(NSString *)token accountName:(NSString *)accountName;
- (void)logout;

- (void)startDeviceAuthWithCompletion:(void (^)(NSString *deviceCode, NSString *userCode, NSString *verificationURL, NSInteger interval, NSError *error))completion;
- (void)pollDeviceAuthWithCode:(NSString *)deviceCode completion:(void (^)(BOOL authorized, NSString *token, NSString *accountName, NSError *error))completion;
- (void)fetchAccountInfoWithCompletion:(void (^)(NSString *accountName, NSError *error))completion;

- (void)fetchLikesWithCompletion:(void (^)(NSArray *tracks, NSError *error))completion;
- (BOOL)isTrackLiked:(NSString *)trackId;
- (void)toggleLikeTrack:(YMTrack *)track completion:(void (^)(BOOL isLiked))completion;
- (void)toggleLikeForTrack:(YMTrack *)track completion:(void (^)(BOOL isLiked))completion;

- (void)fetchMyWaveTracksWithReset:(BOOL)reset afterTrackId:(NSString *)lastTrackId completion:(void (^)(NSArray *tracks, NSError *error))completion;
- (void)sendRotorFeedbackType:(NSString *)type trackId:(NSString *)trackId playedSeconds:(NSTimeInterval)playedSeconds;
- (void)preloadStreamForTrackId:(NSString *)trackId;

- (void)addTrackToLikes:(NSString *)trackId completion:(void (^)(BOOL success, NSError *error))completion;
- (void)removeTracksFromLikes:(NSArray *)trackIds completion:(void (^)(BOOL success, NSError *error))completion;
- (void)searchWithQuery:(NSString *)query completion:(void (^)(NSArray *tracks, NSArray *artists, NSArray *albums, NSError *error))completion;
- (void)loadImageWithURL:(NSString *)urlString completion:(void (^)(UIImage *image))completion;
@end

@interface YMDownloadManager : NSObject
+ (instancetype)shared;
- (NSArray *)downloadedTracks;
- (BOOL)isTrackDownloaded:(NSString *)trackId;
- (void)downloadTrack:(YMTrack *)track completion:(void (^)(BOOL success, NSError *error))completion;
- (void)deleteDownloadedTracksWithIds:(NSArray *)trackIds;
@end

@interface YMPlayerManager : NSObject
@property (nonatomic, strong, readonly) YMTrack *currentTrack;
@property (nonatomic, assign, readonly) BOOL isPlaying;
@property (nonatomic, assign, readonly) BOOL isBuffering;
@property (nonatomic, assign, readonly) float bufferedProgress;
@property (nonatomic, assign, readonly) BOOL isShuffleEnabled;
@property (nonatomic, assign, readonly) BOOL isRepeatTrackEnabled;
@property (nonatomic, assign, readonly) BOOL isMyWaveMode;
@property (nonatomic, assign, readonly) NSTimeInterval currentTime;
@property (nonatomic, assign, readonly) NSTimeInterval totalDuration;

+ (instancetype)shared;
- (void)playQueue:(NSArray *)tracks startIndex:(NSInteger)index;
- (void)startMyWave;
- (void)stopMyWave;
- (void)toggleMyWave;
- (void)togglePlayPause;
- (void)play;
- (void)pause;
- (void)toggleShuffle;
- (void)toggleRepeatTrack;
- (void)nextTrack;
- (void)previousTrack;
- (void)seekToSeconds:(NSTimeInterval)seconds;
- (float)volume;
- (void)setVolume:(float)volume;

- (void)updateSystemNowPlayingInfo;
- (void)handleRemoteControlEvent:(UIEvent *)event;
@end