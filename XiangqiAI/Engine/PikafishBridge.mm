#import "PikafishBridge.h"

#include <memory>
#include <sstream>
#include <filesystem>
#include <type_traits>

#include "engine.h"
#include "search.h"
#include "misc.h"

using namespace Stockfish;

static NSNumber *rawScore(const Score& score);
static NSString *scoreText(const Score& score);

@interface PikafishBridge () {
    std::unique_ptr<Engine> _engine;
    dispatch_queue_t _engineQueue;
    NSString *_bestMove;
    NSString *_lastError;
    BOOL _searching;
}
@end

@implementation PikafishBridge

- (instancetype)init {
    self = [super init];
    if (self) {
        _engineQueue = dispatch_queue_create("com.xiangqiai.pikafish", DISPATCH_QUEUE_SERIAL);
        _bestMove = @"";
        _lastError = @"";
    }
    return self;
}

- (NSString *)bestMove { @synchronized (self) { return _bestMove; } }
- (NSString *)lastError { @synchronized (self) { return _lastError; } }
- (BOOL)isSearching { @synchronized (self) { return _searching; } }

- (void)setError:(NSString *)error {
    @synchronized (self) { _lastError = [error copy] ?: @""; }
}

- (void)publishInfo:(NSDictionary<NSString *, id> *)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^handler)(NSDictionary<NSString *, id> *) = self.analysisHandler;
        if (handler) { handler(info); }
    });
}

- (BOOL)initializeWithNetworkPath:(NSString *)networkPath {
    if (![[NSFileManager defaultManager] fileExistsAtPath:networkPath]) {
        [self setError:@"未找到内置 pikafish.nnue 网络文件。"];
        return NO;
    }
    __block BOOL success = YES;
    dispatch_sync(_engineQueue, ^{
        try {
            _engine.reset();
            const std::filesystem::path netPath([networkPath fileSystemRepresentation]);
            // Engine uses this parent as one of its native NNUE lookup locations; EvalFile is then absolute.
            _engine = std::make_unique<Engine>(netPath.parent_path() / "XiangqiAI");
            _engine->set_on_verify_network([weakSelf = self](std::string_view message) {
                NSString *text = [[NSString alloc] initWithBytes:message.data() length:message.size() encoding:NSUTF8StringEncoding] ?: @"NNUE 验证失败";
                if ([text rangeOfString:@"failed" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [text rangeOfString:@"error" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [weakSelf setError:text];
                }
            });
            _engine->set_on_update_full([weakSelf = self](const Engine::InfoFull& info) {
                auto stringFromView = [](std::string_view value) {
                    return [[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding] ?: @"";
                };
                NSString *pv = stringFromView(info.pv);
                NSDictionary *message = @{
                    @"depth": @(info.depth), @"seldepth": @(info.selDepth), @"nodes": @(info.nodes),
                    @"nps": @(info.nps), @"time": @(info.timeMs), @"hashfull": @(info.hashfull),
                    @"pv": pv, @"score": scoreText(info.score), @"rawScore": rawScore(info.score)
                };
                [weakSelf publishInfo:message];
            });
            _engine->set_on_bestmove([weakSelf = self](std::string_view best, std::string_view) {
                NSString *move = [[NSString alloc] initWithBytes:best.data() length:best.size() encoding:NSUTF8StringEncoding] ?: @"";
                @synchronized (weakSelf) { weakSelf->_bestMove = move; weakSelf->_searching = NO; }
                [weakSelf publishInfo:@{ @"bestmove": move }];
            });
            std::istringstream evalCommand("name EvalFile value " + netPath.string());
            _engine->get_options().setoption(evalCommand);
            _engine->verify_network();
            [self setError:@""];
        } catch (const std::exception& exception) {
            success = NO;
            [self setError:[NSString stringWithUTF8String:exception.what()]];
            _engine.reset();
        }
    });
    return success && _engine != nullptr;
}

- (BOOL)setPositionFEN:(NSString *)fen {
    if (!_engine) { [self setError:@"Pikafish 尚未初始化。" ]; return NO; }
    __block BOOL success = YES;
    dispatch_sync(_engineQueue, ^{
        _engine->stop();
        _engine->wait_for_search_finished();
        @synchronized (self) { _searching = NO; _bestMove = @""; }
        const auto error = _engine->set_position(std::string([fen UTF8String]), {});
        if (error) { success = NO; [self setError:[NSString stringWithUTF8String:error->what()]]; }
        else { [self setError:@""]; }
    });
    return success;
}

- (void)setThreads:(NSInteger)count {
    if (!_engine) { return; }
    dispatch_sync(_engineQueue, ^{
        _engine->stop(); _engine->wait_for_search_finished();
        std::istringstream command("name Threads value " + std::to_string(std::max<NSInteger>(1, count)));
        _engine->get_options().setoption(command);
    });
}

- (void)setHashMegabytes:(NSInteger)megabytes {
    if (!_engine) { return; }
    dispatch_sync(_engineQueue, ^{
        _engine->set_tt_size(static_cast<usize>(std::max<NSInteger>(1, megabytes)));
    });
}

- (void)begin:(Search::LimitsType)limits {
    if (!_engine) { [self setError:@"Pikafish 尚未初始化。" ]; return; }
    dispatch_async(_engineQueue, ^{
        _engine->stop(); _engine->wait_for_search_finished();
        limits.startTime = now();
        @synchronized (self) { _searching = YES; _bestMove = @""; }
        try { _engine->go(limits); }
        catch (const std::exception& exception) { @synchronized (self) { _searching = NO; }; [self setError:[NSString stringWithUTF8String:exception.what()]]; }
    });
}

- (void)analyzeDepth:(NSInteger)depth { Search::LimitsType limits; limits.depth = std::max<NSInteger>(1, depth); [self begin:limits]; }
- (void)analyzeTimeMilliseconds:(NSInteger)milliseconds { Search::LimitsType limits; limits.movetime = std::max<NSInteger>(1, milliseconds); [self begin:limits]; }
- (void)startInfiniteAnalysis { Search::LimitsType limits; limits.infinite = 1; [self begin:limits]; }

- (void)stop {
    if (!_engine) { return; }
    _engine->stop();
    @synchronized (self) { _searching = NO; }
}

static NSNumber *rawScore(const Score& score) {
    return @(score.visit([](const auto& value) -> int {
        using T = std::decay_t<decltype(value)>;
        if constexpr (std::is_same_v<T, Score::Mate>) { return value.plies > 0 ? 32000 - value.plies : -32000 - value.plies; }
        else { return value.value; }
    }));
}

static NSString *scoreText(const Score& score) {
    return score.visit([](const auto& value) -> NSString * {
        using T = std::decay_t<decltype(value)>;
        if constexpr (std::is_same_v<T, Score::Mate>) { return [NSString stringWithFormat:@"杀 %d", (value.plies + (value.plies > 0 ? 1 : -1)) / 2]; }
        else { return [NSString stringWithFormat:@"%+.2f", value.value / 100.0]; }
    });
}
@end


