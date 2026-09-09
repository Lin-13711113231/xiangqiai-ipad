import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var engine = EngineManager()
    @State private var board = BoardState()
    @State private var selected: Square?
    @State private var editing = false
    @State private var palettePiece: Piece?
    @State private var fenText = BoardState.initialFEN
    @State private var detailTab = 0
    @AppStorage("analysisNotes") private var analysisNotes = ""

    private var destinations: Set<Square> {
        guard !editing, let selected else { return [] }
        return Set(GameRules.legalMoves(from: selected, in: board).map(\.to))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 12) { boardPanel; analysisPanel; positionPanel }
                        VStack(spacing: 12) { boardPanel; HStack(alignment: .top, spacing: 12) { analysisPanel; positionPanel } }
                    }
                    controls
                }
                .padding(12)
                .frame(maxWidth: 1_230, alignment: .leading)
            }
            .background(XiangqiAppearance.canvas)
            .navigationTitle("局面分析")
        }
        .onAppear { engine.initialize(threads: settings.engineThreads, hashMegabytes: settings.engineHashMB) }
        .onChange(of: settings.engineThreads) { engine.configure(threads: $0, hashMegabytes: settings.engineHashMB) }
        .onChange(of: settings.engineHashMB) { engine.configure(threads: settings.engineThreads, hashMegabytes: $0) }
        .onChange(of: scenePhase) { phase in if phase != .active { engine.stop() } }
    }

    private var header: some View {
        HStack {
            Label("分析棋盘", systemImage: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(engine.isSearching ? "皮卡鱼正在计算" : "本地离线分析")
                .font(.caption.weight(.medium)).foregroundStyle(engine.isSearching ? XiangqiAppearance.accent : .secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(XiangqiAppearance.panelBorder))
    }

    private var boardPanel: some View {
        VStack(spacing: 0) {
            BoardView(board: board, selected: selected, legalDestinations: destinations, lastMove: nil, enabled: !engine.isSearching, onTap: tap)
                .frame(width: 390, height: 434)
                .padding(7)
            HStack {
                Label(editing ? "自由摆子" : "走子预览", systemImage: editing ? "square.and.pencil" : "hand.tap")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(board.sideToMove == .red ? "红方行棋" : "黑方行棋").font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(.white.opacity(0.78))
        }
        .background(XiangqiAppearance.woodDark.opacity(0.20), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(XiangqiAppearance.panelBorder))
        .frame(width: 405)
    }

    private var analysisPanel: some View {
        VStack(spacing: 0) {
            panelHeader("皮卡鱼", icon: "cpu", trailing: engine.isSearching ? "分析中" : "待命")
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(engine.info.score).font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("红方评分").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("D\(engine.info.depth)").font(.caption.monospaced()).foregroundStyle(XiangqiAppearance.accent)
                }
                Divider()
                metricRow("选择深度", "\(engine.info.selDepth)")
                metricRow("节点", engine.info.nodes.formatted())
                metricRow("速度", "\(engine.info.nps.formatted()) n/s")
                metricRow("用时", "\(engine.info.timeMilliseconds) ms")
                Divider()
                Text("主变").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(engine.info.principalVariation.isEmpty ? "暂无分析结果" : engine.info.principalVariation)
                    .font(.caption.monospaced()).lineLimit(7).textSelection(.enabled)
                Spacer(minLength: 0)
                Text(engine.status).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12).frame(height: 316, alignment: .top)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(XiangqiAppearance.panelBorder))
        .frame(width: 250)
    }

    private var positionPanel: some View {
        VStack(spacing: 0) {
            // These native tabs deliberately mirror the reference product's workspace:
            // Pikafish occupies the adjacent live-engine panel; the remaining views are
            // local/offline equivalents so the app never needs a web service.
            Picker("工作区", selection: $detailTab) {
                Text("云库").tag(0)
                Text("局势").tag(1)
                Text("注释").tag(2)
            }
            .pickerStyle(.segmented).padding(9)
            Divider()
            Group {
                switch detailTab {
                case 0: localLibraryControls
                case 1: situationInfo
                default: notesControls
                }
            }
            .frame(height: 270, alignment: .top)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(XiangqiAppearance.panelBorder))
        .frame(width: 270)
    }

    private var localLibraryControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本地局面库").font(.subheadline.weight(.semibold))
            Text("保持离线：可载入 FEN、自由摆子和保存本机注释；不会访问云端。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            TextField("FEN", text: $fenText, axis: .vertical)
                .textFieldStyle(.roundedBorder).font(.caption.monospaced()).lineLimit(2)
            HStack(spacing: 7) {
                Button("载入", systemImage: "square.and.arrow.down") {
                    guard let candidate = BoardState(validatingFEN: fenText) else { return }
                    engine.stop(); board = candidate; selected = nil; fenText = candidate.fen()
                }
                .buttonStyle(.borderedProminent)
                Button("初始", systemImage: "arrow.counterclockwise") {
                    engine.stop(); board = BoardState(); selected = nil; fenText = board.fen()
                }
                .buttonStyle(.bordered)
            }
            Toggle("自由摆子", isOn: $editing).onChange(of: editing) { if $0 { selected = nil } }
            ForEach(PieceColor.allCases, id: \.self) { color in
                HStack(spacing: 4) {
                    ForEach(PieceKind.allCases, id: \.self) { kind in
                        let piece = Piece(color: color, kind: kind)
                        Button(piece.glyph) { palettePiece = piece }
                            .font(.system(size: 15, weight: .bold, design: .serif))
                            .foregroundStyle(piece.color == .red ? .red : XiangqiAppearance.ink)
                            .frame(width: 24, height: 22)
                            .background(palettePiece == piece ? XiangqiAppearance.accent.opacity(0.16) : XiangqiAppearance.canvas, in: RoundedRectangle(cornerRadius: 4))
                            .buttonStyle(.plain)
                    }
                    Button("清") { palettePiece = nil }
                        .font(.caption2.weight(.semibold)).buttonStyle(.borderless)
                }
            }
        }
        .padding(12)
    }

    private var notesControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("注释").font(.subheadline.weight(.semibold))
            Text("本机保存，可用于记录变例、计划与评估。")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $analysisNotes)
                .font(.caption)
                .scrollContentBackground(.hidden)
                .padding(5)
                .background(XiangqiAppearance.canvas, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(XiangqiAppearance.panelBorder))
        }
        .padding(12)
    }

    private var situationInfo: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("局面").font(.subheadline.weight(.semibold))
            metricRow("轮到", board.sideToMove == .red ? "红方" : "黑方")
            metricRow("合法着", "\(GameRules.legalMoves(in: board).count)")
            Divider()
            Text("分析页允许从任意合法 FEN 开始，也可直接在棋盘上试走。长将、长捉等循环裁定仅对完整实战棋谱生效。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(12)
    }

    private var editingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("自由摆子模式", isOn: $editing).onChange(of: editing) { if $0 { selected = nil } }
            Text("先选择棋子，再点棋盘放置；“清空”会删除格内棋子。")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(PieceColor.allCases, id: \.self) { color in
                HStack(spacing: 5) {
                    ForEach(PieceKind.allCases, id: \.self) { kind in
                        let piece = Piece(color: color, kind: kind)
                        Button(piece.glyph) { palettePiece = piece }
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(piece.color == .red ? .red : XiangqiAppearance.ink)
                            .frame(width: 27, height: 27)
                            .background(palettePiece == piece ? XiangqiAppearance.accent.opacity(0.16) : XiangqiAppearance.canvas, in: RoundedRectangle(cornerRadius: 5))
                            .buttonStyle(.plain)
                    }
                }
            }
            Button("清空格", systemImage: "eraser") { palettePiece = nil }.buttonStyle(.bordered)
            Spacer()
        }
        .padding(12)
    }

    private var fenControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FEN（可粘贴局面）").font(.caption.weight(.semibold))
            TextField("FEN", text: $fenText, axis: .vertical)
                .textFieldStyle(.roundedBorder).font(.caption.monospaced()).lineLimit(5)
            Button("载入 FEN", systemImage: "square.and.arrow.down") {
                guard let candidate = BoardState(validatingFEN: fenText) else { return }
                engine.stop(); board = candidate; selected = nil; fenText = candidate.fen()
            }
            .buttonStyle(.borderedProminent)
            Text("无效 FEN 不会覆盖当前局面。")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
    }

    private var controls: some View {
        HStack(spacing: 9) {
            Button("固定深度 18", systemImage: "target") { analyzeDepth() }.buttonStyle(.borderedProminent)
            Button(engine.isSearching ? "停止" : "无限分析", systemImage: engine.isSearching ? "stop.fill" : "waveform.path.ecg") {
                engine.isSearching ? engine.stop() : analyzeInfinite()
            }.buttonStyle(.bordered)
            Button("初始局面", systemImage: "arrow.counterclockwise") { engine.stop(); board = BoardState(); selected = nil; fenText = board.fen() }
                .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func panelHeader(_ title: String, icon: String, trailing: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).foregroundStyle(XiangqiAppearance.accent)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(trailing).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11).padding(.vertical, 10)
        .background(XiangqiAppearance.canvas).overlay(alignment: .bottom) { Divider() }
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(.caption).foregroundStyle(.secondary); Spacer(); Text(value).font(.caption.monospaced()) }
    }

    private func tap(_ square: Square) {
        if editing { board[square] = palettePiece; fenText = board.fen(); return }
        if let selected, let move = GameRules.legalMoves(from: selected, in: board).first(where: { $0.to == square }) {
            board = board.applying(move); self.selected = nil; fenText = board.fen(); return
        }
        selected = board.piece(at: square)?.color == board.sideToMove ? square : nil
    }

    private func analyzeDepth() { guard engine.setPosition(board) else { return }; engine.analyze(depth: 18) }
    private func analyzeInfinite() { guard engine.setPosition(board) else { return }; engine.startInfiniteAnalysis() }
}
