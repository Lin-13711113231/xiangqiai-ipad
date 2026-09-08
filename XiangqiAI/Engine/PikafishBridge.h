#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A deliberately thin Objective-C++ façade over Pikafish's public C++ Engine API.
@interface PikafishBridge : NSObject
@property (nonatomic, copy, nullable) void (^analysisHandler)(NSDictionary<NSString *, id> *info);
@property (nonatomic, copy, readonly) NSString *bestMove;
@property (nonatomic, copy, readonly) NSString *lastError;
@property (nonatomic, readonly, getter=isSearching) BOOL searching;

- (BOOL)initializeWithNetworkPath:(NSString *)networkPath;
- (BOOL)setPositionFEN:(NSString *)fen;
- (BOOL)setPositionInitialFEN:(NSString *)fen moves:(NSArray<NSString *> *)moves;
/// `none`, `draw`, `side-to-move-wins`, or `side-to-move-loses` from Pikafish WXF rules.
- (NSString *)ruleJudgement;
- (void)setThreads:(NSInteger)count;
- (void)setHashMegabytes:(NSInteger)megabytes;
- (void)analyzeDepth:(NSInteger)depth;
- (void)analyzeTimeMilliseconds:(NSInteger)milliseconds;
- (void)startInfiniteAnalysis;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
