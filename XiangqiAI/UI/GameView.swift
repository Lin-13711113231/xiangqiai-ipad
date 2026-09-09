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
                    commandBar
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 12) { boardPanel; enginePanel; movesPanel }
                        VStack(spacing: 12) { boardPanel; HStack(alignment: .top, spacing: 12) { enginePanel; movesPanel } }
                    }
                    actionBar
                    if let result { resultBanner(result) }
                }
                .padding(12)
                .frame(maxWidth: 1_230, alignment: .leading)
            }
            .background(XiangqiAppearance.canvas)
            .navigationTitle("象棋 AI")
        }
        .onAppear { engine.initialize(threads: settings.engineThreads, hashMegabytes: settings.engineHashMB) }
        .onChange(of: settings.engineThreads) { engine.configure(threads: $0, hashMegabytes: settings.engineHashMB) }
        .onChange(of: settings.engineHashMB) { engine.configure(threads: settings.engineThreads, hashMegabytes: $0) }
        .onChange(of: scenePhase) { phase in if phase != .active { engine.stop() } }
        .onReceive(engine.$info) { info in
            guard !info.bestMove.isEmpty, board.sideToMove != humanColor, result == nil,
                  let move = XiangqiMove.fromUCI(info.bestMove), GameRules.legalMoves(in: board).contains(move) else { return }
            apply(move)
        }
    }

    private var commandBar: some View {
        HStack(spacing: 7) {
            Label("本地对弈", systemImage: "circle.grid.3x3.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(XiangqiAppearance.ink)
            Spacer()
            Label(engine.isSearching ? "皮卡鱼思考中" : (board.sideToMove == .red ? "红方走棋" : "黑方走棋"), systemImage: engine.isSearching ? "brain" : "flag.checkered")
                .font(.caption.weight(.medium))
                .foregroundStyle(engine.isSearching ? XiangqiAppearance.accent : .secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(XiangqiAppearance.panelBorder))
    }

    private var boardPanel: some View {
        VStack(spacing: 0) {
            BoardView(board: board, selected: selected, legalDestinations: legalFromSelection, lastMove: lastMove,
                      enabled: result == nil && !engine.isSearching && board.sideToMove == humanColor, onTap: tap)
                .frame(width: 390, height: 434)
                .padding(7)
            HStack {
                boardAction("backward.end", "开局", newGame)
                Spacer()
                boardAction("chevron.left", "悔棋", undo).disabled(game.moves.isEmpty || engine.isSearching)
                Spacer()
                boardAction("chevron.right", "AI", startAI).disabled(engine.isSearching || board.sideToMove == humanColor)
                Spacer()
                boardAction("forward.end", "终局", {})
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            .background(Color.white.opacity(0.78))
        }
        .background(XiangqiAppearance.woodDark.opacity(0.20), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(XiangqiAppearance.panelBorder))
        .frame(width: 405)
    }

    private func boardAction(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon).labelStyle(.iconOnly)
                .font(.caption.weight(.semibold))
                .foregroundStyle(XiangqiAppearance.ink.opacity(0.70))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var enginePanel: some View {
        VStack(spacing: 0) {
            panelHeader("皮卡鱼", icon: "cpu", trailing: engine.isSearching ? "分析中" : "本地 NNUE")
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline) {
                    Text(engine.info.score.isEmpty ? "—" : engine.info.score)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(XiangqiAppearance.ink)
                    Text("红方评分").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("深度 \(engine.info.depth)").font(.caption.monospaced()).foregroundStyle(XiangqiAppearance.accent)
                }
                GeometryReader { proxy in
                    let redShare = max(0.08, min(0.92, 0.5 + Double(engine.info.rawScore) / 1200.0))
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.72))
                        Capsule().fill(Color(red: 0.80, green: 0.08, blue: 0.10)).frame(width: proxy.size.width * CGFloat(redShare))
                    }
                }
                .frame(height: 7)
                Divider()
                metricRow("选择深度", "\(engine.info.selDepth)")
                metricRow("节点", engine.info.nodes.formatted())
                metricRow("速度", "\(engine.info.nps.formatted()) n/s")
                metricRow("用时", "\(engine.info.timeMilliseconds) ms")
                if !engine.info.principalVariation.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("主变").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(engine.info.principalVariation).font(.caption.monospaced()).lineLimit(4).textSelection(.enabled)
                    }
                } else {
                    Text(engine.status).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
                }
            }
            .padding(12)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(XiangqiAppearance.panelBorder))
        .frame(width: 250)
    }

    private var movesPanel: some View {
        VStack(spacing: 0) {
            panelHeader("棋谱", icon: "list.number", trailing: "\(game.moves.count) 手")
            if game.moves.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "flag.checkered").font(.title3).foregroundStyle(.secondary)
                    Text("— 开始 —").font(.subheadline.weight(.medium))
                    Text("选择红方棋子开始对局").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 265)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(game.moves.indices), id: \.self) { index in
                            HStack(spacing: 8) {
                                Text("\(index + 1)").font(.caption.monospaced()).foregroundStyle(.tertiary).frame(width: 24, alignment: .trailing)
                                Text(notation(for: index)).font(.subheadline.weight(index == game.moves.count - 1 ? .semibold : .regular))
                                Spacer()
                                Text(game.moves[index].uci).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(index.isMultiple(of: 2) ? XiangqiAppearance.canvas : .white)
                            Divider()
                        }
                    }
                }
                .frame(height: 265)
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(XiangqiAppearance.panelBorder))
        .frame(width: 270)
    }

    private var actionBar: some View {
        HStack(spacing: 9) {
            Button("新游戏", systemImage: "plus") { newGame() }.buttonStyle(.borderedProminent)
            Button("悔棋", systemImage: "arrow.uturn.backward") { undo() }.buttonStyle(.bordered).disabled(game.moves.isEmpty || engine.isSearching)
            Button(engine.isSearching ? "停止分析" : "让 AI 走") { engine.isSearching ? engine.stop() : startAI() }
                .buttonStyle(.bordered).disabled(!engine.isSearching && board.sideToMove == humanColor)
            Spacer()
            Text("\(humanColor == .red ? "你执红" : "你执黑") · \(settings.thinkTimeMs / 1_000)s/步")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func resultBanner(_ result: String) -> some View {
        Label(result, systemImage: "flag.checkered.2.crossed")
            .font(.headline).foregroundStyle(.orange)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
    }

    private func panelHeader(_ title: String, icon: String, trailing: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).foregroundStyle(XiangqiAppearance.accent)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(trailing).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11).padding(.vertical, 10)
        .background(XiangqiAppearance.canvas)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(.caption).foregroundStyle(.secondary); Spacer(); Text(value).font(.caption.monospaced()) }
    }

    private func notation(for index: Int) -> String {
        guard game.positions.indices.contains(index), game.moves.indices.contains(index), let piece = game.positions[index].piece(at: game.moves[index].from) else { return game.moves[index].uci }
        let move = game.moves[index]
        let sourceFile = piece.color == .red ? 9 - move.from.column : move.from.column + 1
        let targetFile = piece.color == .red ? 9 - move.to.column : move.to.column + 1
        if move.from.row == move.to.row { return "\(piece.glyph)\(sourceFile)平\(targetFile)" }
        let advancing = piece.color == .red ? move.to.row < move.from.row : move.to.row > move.from.row
        let action = advancing ? "进" : "退"
        let distance = abs(move.to.row - move.from.row)
        let destinationBased = piece.kind == .horse || piece.kind == .elephant || piece.kind == .advisor
        return "\(piece.glyph)\(sourceFile)\(action)\(destinationBased ? targetFile : distance)"
    }

    private func tap(_ square: Square) {
        guard board.sideToMove == humanColor else { return }
        if let selected, let move = GameRules.legalMoves(from: selected, in: board).first(where: { $0.to == square }) { apply(move); return }
        selected = board.piece(at: square)?.color == humanColor ? square : nil
    }

    private func apply(_ move: XiangqiMove) {
        game.append(move); lastMove = move; selected = nil
        let positionLoaded = engine.setPosition(game)
        result = GameRules.gameResult(in: board) ?? (positionLoaded ? engine.cyclicRuleResult(for: game) : nil)
        guard result == nil, board.sideToMove != humanColor, positionLoaded else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { engine.analyze(timeMilliseconds: settings.thinkTimeMs) }
    }

    private func newGame() { engine.stop(); game = GameHistory(); selected = nil; lastMove = nil; result = nil; if settings.aiPlaysRed { startAI() } }
    private func undo() { engine.stop(); game.undo(plies: min(2, game.moves.count)); lastMove = nil; selected = nil; result = nil }
    private func startAI() { guard result == nil, board.sideToMove != humanColor, engine.setPosition(game) else { return }; engine.analyze(timeMilliseconds: settings.thinkTimeMs) }
}
