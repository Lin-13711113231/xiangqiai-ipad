import SwiftUI

struct GameView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var engine = EngineManager()
    @State private var game = GameHistory()
    @State private var selected: Square?
    @State private var lastMove: XiangqiMove?
    @State private var result: String?

    private var board: BoardState { game.current }
    private var humanColor: PieceColor { settings.aiPlaysRed ? .black : .red }
    private var legalFromSelection: Set<Square> {
        guard let selected else { return [] }
        return Set(GameRules.legalMoves(from: selected, in: board).map(\.to))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Label(board.sideToMove == .red ? "红方走棋" : "黑方走棋", systemImage: "flag.checkered")
                        Spacer()
                        if engine.isSearching { ProgressView().controlSize(.small); Text("AI 思考中") }
                    }
                    .font(.headline)
                    BoardView(board: board, selected: selected, legalDestinations: legalFromSelection, lastMove: lastMove,
                              enabled: result == nil && !engine.isSearching && board.sideToMove == humanColor, onTap: tap)
                    .frame(maxWidth: 680)
                    .padding(8)
                    .background(Color(red: 0.90, green: 0.72, blue: 0.42).opacity(0.56), in: RoundedRectangle(cornerRadius: 14))

                    if let result { Text(result).font(.title3.bold()).foregroundStyle(.orange) }
                    Text(engine.status).font(.footnote).foregroundStyle(engine.status.contains("失败") || engine.status.contains("错误") ? .red : .secondary).multilineTextAlignment(.center)
                    engineSummary
                    HStack {
                        Button("新游戏", systemImage: "plus.circle", action: newGame)
                        Button("悔棋", systemImage: "arrow.uturn.backward", action: undo).disabled(game.count <= 1 || engine.isSearching)
                        Button("停止 AI", systemImage: "stop.circle", action: engine.stop).disabled(!engine.isSearching)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("象棋 AI")
        }
        .onAppear { engine.initialize(threads: settings.engineThreads, hashMegabytes: settings.engineHashMB) }
        .onChange(of: settings.engineThreads) { engine.configure(threads: $0, hashMegabytes: settings.engineHashMB) }
        .onChange(of: settings.engineHashMB) { engine.configure(threads: settings.engineThreads, hashMegabytes: $0) }
        .onChange(of: scenePhase) { phase in
            if phase != .active { engine.stop() }
        }
        .onReceive(engine.$info) { info in
            guard !info.bestMove.isEmpty, board.sideToMove != humanColor, result == nil,
                  let move = XiangqiMove.fromUCI(info.bestMove), GameRules.legalMoves(in: board).contains(move) else { return }
            apply(move)
        }
    }

    private var engineSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text("评价 \(engine.info.score)"); Spacer(); Text("深度 \(engine.info.depth)/\(engine.info.selDepth)") }
            HStack { Text("\(engine.info.nodes.formatted()) 节点"); Spacer(); Text("\(engine.info.nps.formatted()) NPS · \(engine.info.timeMilliseconds) ms") }
            if !engine.info.principalVariation.isEmpty { Text("PV  \(engine.info.principalVariation)").font(.caption.monospaced()).lineLimit(2) }
        }
        .padding(12).frame(maxWidth: 680).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func tap(_ square: Square) {
        guard board.sideToMove == humanColor else { return }
        if let selected, let move = GameRules.legalMoves(from: selected, in: board).first(where: { $0.to == square }) { apply(move); return }
        selected = board.piece(at: square)?.color == humanColor ? square : nil
    }

    private func apply(_ move: XiangqiMove) {
        game.append(move); lastMove = move; selected = nil
        // Keep rule adjudication separate from normal legal-move generation.
        // The native Pikafish state chain implements the WXF long-check and
        // long-chase decision, including the engine's protected-piece logic.
        let positionLoaded = engine.setPosition(game)
        result = GameRules.gameResult(in: board) ?? (positionLoaded ? engine.cyclicRuleResult(for: game) : nil)
        guard result == nil, board.sideToMove != humanColor, positionLoaded else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            engine.analyze(timeMilliseconds: settings.thinkTimeMs)
        }
    }

    private func newGame() { engine.stop(); game = GameHistory(); selected = nil; lastMove = nil; result = nil; if settings.aiPlaysRed { startAI() } }
    private func undo() { engine.stop(); game.undo(plies: min(2, game.moves.count)); lastMove = nil; selected = nil; result = nil }
    private func startAI() { guard engine.setPosition(game) else { return }; engine.analyze(timeMilliseconds: settings.thinkTimeMs) }
}
