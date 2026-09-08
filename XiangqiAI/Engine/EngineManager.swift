import Foundation
import Combine

struct EngineInfo: Equatable {
    var depth = 0
    var selDepth = 0
    var score = "—"
    var rawScore = 0
    var nodes = 0
    var nps = 0
    var timeMilliseconds = 0
    var hashfull = 0
    var principalVariation = ""
    var bestMove = ""
}

@MainActor
final class EngineManager: ObservableObject {
    @Published private(set) var info = EngineInfo()
    @Published private(set) var isSearching = false
    @Published private(set) var status = "正在准备 Pikafish…"
    @Published private(set) var isReady = false

    private let bridge = PikafishBridge()
    private var configuredThreads = -1
    private var configuredHash = -1

    init() {
        bridge.analysisHandler = { [weak self] dictionary in
            Task { @MainActor in self?.consume(dictionary) }
        }
    }

    func initialize(threads: Int, hashMegabytes: Int) {
        guard !isReady else { configure(threads: threads, hashMegabytes: hashMegabytes); return }
        guard let path = Bundle.main.path(forResource: "pikafish", ofType: "nnue") else {
            status = "错误：App Bundle 内缺少 pikafish.nnue。"
            return
        }
        if bridge.initialize(withNetworkPath: path) {
            isReady = true
            status = "Pikafish 已就绪（本地 NNUE）。"
            configure(threads: threads, hashMegabytes: hashMegabytes)
        } else {
            status = "引擎初始化失败：\(bridge.lastError)"
        }
    }

    func configure(threads: Int, hashMegabytes: Int) {
        guard isReady else { return }
        if configuredThreads != threads { bridge.setThreads(threads); configuredThreads = threads }
        if configuredHash != hashMegabytes { bridge.setHashMegabytes(hashMegabytes); configuredHash = hashMegabytes }
    }

    func setPosition(_ board: BoardState) -> Bool {
        guard isReady else { status = "引擎尚未准备完成。"; return false }
        let okay = bridge.setPositionFEN(board.fen())
        if !okay { status = "局面设置失败：\(bridge.lastError)" }
        return okay
    }

    func analyze(depth: Int) { start { bridge.analyzeDepth(depth) } }
    func analyze(timeMilliseconds: Int) { start { bridge.analyzeTimeMilliseconds(timeMilliseconds) } }
    func startInfiniteAnalysis() { start { bridge.startInfiniteAnalysis() } }

    func stop() {
        bridge.stop()
        isSearching = false
        if isReady { status = "分析已停止。" }
    }

    private func start(_ work: () -> Void) {
        guard isReady else { status = "引擎尚未准备完成。"; return }
        info = EngineInfo()
        status = "Pikafish 正在思考…"
        isSearching = true
        work()
    }

    private func consume(_ dictionary: [String: Any]) {
        if let best = dictionary["bestmove"] as? String {
            info.bestMove = best
            isSearching = false
            status = best == "(none)" || best.isEmpty ? "引擎未找到可走着。" : "思考完成：\(best)"
            return
        }
        info.depth = dictionary["depth"] as? Int ?? info.depth
        info.selDepth = dictionary["seldepth"] as? Int ?? info.selDepth
        info.score = dictionary["score"] as? String ?? info.score
        info.rawScore = dictionary["rawScore"] as? Int ?? info.rawScore
        info.nodes = dictionary["nodes"] as? Int ?? info.nodes
        info.nps = dictionary["nps"] as? Int ?? info.nps
        info.timeMilliseconds = dictionary["time"] as? Int ?? info.timeMilliseconds
        info.hashfull = dictionary["hashfull"] as? Int ?? info.hashfull
        info.principalVariation = dictionary["pv"] as? String ?? info.principalVariation
    }
}
