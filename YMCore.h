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
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, assign) NSInteger duration;
@property (nonatomic, copy) NSString *coverURL;
@property (nonatomic, copy) NSString *streamURL;
@property (nonatomic, copy) NSString *localAudioPath;
@property (nonatomic, copy) NSString *localCoverPath;

+ (instancetype)trackFromDictionary:(NSDictionary *)dict baseURL:(NSString *)baseURL token:(NSString *)token;
- (NSDictionary *)toDictionary;
- (NSString *)formattedDuration;
@end

@interface YMApiClient : NSObject
@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy, readonly) NSString *token;
@property (nonatomic, copy, readonly) NSString *accountName;

+ (instancetype)shared;
- (void)logout;
- (void)reloadConfig;
- (BOOL)isAuthorized;
- (void)saveToken:(NSString *)token accountName:(NSString *)accountName;

- (void)startDeviceAuthWithCompletion:(void (^)(NSString *deviceCode, NSString *userCode, NSString *verificationURL, NSInteger interval, NSError *error))completion;
- (void)pollDeviceAuthWithCode:(NSString *)deviceCode completion:(void (^)(BOOL authorized, NSString *token, NSString *accountName, NSError *error))completion;
- (void)fetchAccountInfoWithCompletion:(void (^)(NSString *accountName, NSError *error))completion;

- (void)fetchLikesWithCompletion:(void (^)(NSArray *tracks, NSError *error))completion;
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
@property (nonatomic, assign, readonly) NSTimeInterval currentTime;
@property (nonatomic, assign, readonly) NSTimeInterval totalDuration;

+ (instancetype)shared;
- (void)playQueue:(NSArray *)tracks startIndex:(NSInteger)index;
- (void)togglePlayPause;
- (void)nextTrack;
- (void)previousTrack;
- (void)seekToSeconds:(NSTimeInterval)seconds;
- (float)volume;
- (void)setVolume:(float)volume;
@end