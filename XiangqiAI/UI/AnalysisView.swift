import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var engine = EngineManager()
    @State private var board = BoardState()
    @State private var selected: Square?
    @State private var editing = false
    @State private var palettePiece: Piece?
    @State private var fenText = BoardState.initialFEN

    private var destinations: Set<Square> { guard !editing, let selected else { return [] }; return Set(GameRules.legalMoves(from: selected, in: board).map(\.to)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    BoardView(board: board, selected: selected, legalDestinations: destinations, lastMove: nil, enabled: !engine.isSearching, onTap: tap)
                        .frame(maxWidth: 680).padding(8).background(Color(red: 0.90, green: 0.72, blue: 0.42).opacity(0.56), in: RoundedRectangle(cornerRadius: 14))
                    Toggle("自由摆子模式", isOn: $editing).onChange(of: editing) { if $0 { selected = nil } }
                    if editing { palette }
                    HStack {
                        Button("固定深度 18") { analyzeDepth() }.buttonStyle(.borderedProminent)
                        Button(engine.isSearching ? "停止" : "无限分析") { engine.isSearching ? engine.stop() : analyzeInfinite() }.buttonStyle(.bordered)
                        Button("初始局面") { board = BoardState(); fenText = board.fen(); engine.stop() }.buttonStyle(.bordered)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FEN（可粘贴局面）").font(.caption)
                        TextField("FEN", text: $fenText, axis: .vertical).textFieldStyle(.roundedBorder).font(.caption.monospaced())
                        Button("载入 FEN") { let candidate = BoardState(fen: fenText); if candidate.fen() == fenText || !fenText.isEmpty { board = candidate; selected = nil } }.buttonStyle(.bordered)
                    }.frame(maxWidth: 680)
                    analysisInfo
                }.padding()
            }.navigationTitle("局面分析")
        }
        .onAppear { engine.initialize(threads: settings.engineThreads, hashMegabytes: settings.engineHashMB) }
        .onChange(of: settings.engineThreads) { engine.configure(threads: $0, hashMegabytes: settings.engineHashMB) }
        .onChange(of: settings.engineHashMB) { engine.configure(threads: settings.engineThreads, hashMegabytes: $0) }
    }

    private var palette: some View {
        VStack(alignment: .leading) {
            Text("选择棋子后点棋盘放置；选择“清空”可移除棋子。").font(.caption).foregroundStyle(.secondary)
            ForEach(PieceColor.allCases, id: \.self) { color in
                HStack { ForEach(PieceKind.allCases, id: \.self) { kind in
                    Button(Piece(color: color, kind: kind).glyph) { palettePiece = Piece(color: color, kind: kind) }
                        .font(.title2).buttonStyle(.bordered).tint(palettePiece == Piece(color: color, kind: kind) ? .blue : .gray)
                } }
            }
            Button("清空格") { palettePiece = nil }.buttonStyle(.bordered)
        }.frame(maxWidth: 680, alignment: .leading)
    }

    private var analysisInfo: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(engine.status).font(.footnote).foregroundStyle(.secondary)
            HStack { Text("评价：\(engine.info.score)"); Spacer(); Text("深度：\(engine.info.depth) / \(engine.info.selDepth)") }
            HStack { Text("节点：\(engine.info.nodes.formatted())"); Spacer(); Text("NPS：\(engine.info.nps.formatted()) · \(engine.info.timeMilliseconds) ms") }
            Text("PV：\(engine.info.principalVariation.isEmpty ? "—" : engine.info.principalVariation)").font(.caption.monospaced())
        }.padding(12).frame(maxWidth: 680).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func tap(_ square: Square) {
        if editing { board[square] = palettePiece; fenText = board.fen(); return }
        if let selected, let move = GameRules.legalMoves(from: selected, in: board).first(where: { $0.to == square }) { board = board.applying(move); self.selected = nil; fenText = board.fen(); return }
        selected = board.piece(at: square)?.color == board.sideToMove ? square : nil
    }
    private func analyzeDepth() { guard engine.setPosition(board) else { return }; engine.analyze(depth: 18) }
    private func analyzeInfinite() { guard engine.setPosition(board) else { return }; engine.startInfiniteAnalysis() }
}
