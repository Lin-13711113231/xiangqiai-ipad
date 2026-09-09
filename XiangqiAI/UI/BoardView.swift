import SwiftUI

/// Native visual language inspired by the compact three-panel analysis workflow:
/// warm wood board, restrained light panels, and high-contrast red/black pieces.
enum XiangqiAppearance {
    static let ink = Color(red: 0.18, green: 0.16, blue: 0.13)
    static let accent = Color(red: 0.12, green: 0.35, blue: 0.68)
    static let canvas = Color(red: 0.96, green: 0.965, blue: 0.97)
    static let panelBorder = Color.black.opacity(0.12)
    static let woodDark = Color(red: 0.55, green: 0.31, blue: 0.14)
    static let woodLight = Color(red: 0.88, green: 0.64, blue: 0.35)
}

struct BoardView: View {
    let board: BoardState
    let selected: Square?
    let legalDestinations: Set<Square>
    let lastMove: XiangqiMove?
    let enabled: Bool
    let onTap: (Square) -> Void

    var body: some View {
        GeometryReader { geometry in
            let square = min(geometry.size.width / 9, geometry.size.height / 10)
            let boardSize = CGSize(width: square * 9, height: square * 10)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    drawBoard(context: context, square: square, size: boardSize)
                }
                .frame(width: boardSize.width, height: boardSize.height)

                ForEach(0..<10, id: \.self) { row in
                    ForEach(0..<9, id: \.self) { column in
                        let cell = Square(row: row, column: column)
                        Button { if enabled { onTap(cell) } } label: {
                            ZStack {
                                if lastMove?.from == cell || lastMove?.to == cell {
                                    RoundedRectangle(cornerRadius: square * 0.16)
                                        .fill(Color.yellow.opacity(0.30))
                                        .padding(square * 0.035)
                                }
                                if selected == cell {
                                    RoundedRectangle(cornerRadius: square * 0.16)
                                        .stroke(XiangqiAppearance.accent, lineWidth: max(2, square * 0.06))
                                        .padding(square * 0.045)
                                }
                                if legalDestinations.contains(cell) && board.piece(at: cell) == nil {
                                    Circle()
                                        .fill(XiangqiAppearance.accent.opacity(0.68))
                                        .frame(width: square * 0.18, height: square * 0.18)
                                }
                                if let piece = board.piece(at: cell) {
                                    PieceToken(piece: piece, square: square)
                                }
                            }
                            .frame(width: square, height: square)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: square * (CGFloat(column) + 0.5), y: square * (CGFloat(row) + 0.5))
                        .disabled(!enabled)
                        .accessibilityLabel(accessibilityLabel(for: cell))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .aspectRatio(0.9, contentMode: .fit)
        .accessibilityLabel("中国象棋棋盘")
    }

    private func accessibilityLabel(for square: Square) -> String {
        if let piece = board.piece(at: square) { return "\(piece.color == .red ? "红方" : "黑方")\(piece.glyph)" }
        return "空格"
    }

    private func drawBoard(context: GraphicsContext, square: CGFloat, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        context.fill(Path(roundedRect: bounds, cornerRadius: square * 0.12), with: .color(XiangqiAppearance.woodDark))
        let inner = bounds.insetBy(dx: square * 0.10, dy: square * 0.10)
        context.fill(Path(roundedRect: inner, cornerRadius: square * 0.05), with: .linearGradient(
            Gradient(colors: [XiangqiAppearance.woodLight, Color(red: 0.78, green: 0.48, blue: 0.22)]),
            startPoint: CGPoint(x: inner.minX, y: inner.minY), endPoint: CGPoint(x: inner.maxX, y: inner.maxY)
        ))

        // Narrow translucent grain strips create a wood character without external image assets.
        for column in 0..<18 {
            let x = inner.minX + inner.width * CGFloat(column) / 18
            let strip = CGRect(x: x, y: inner.minY, width: max(1, square * 0.028), height: inner.height)
            context.fill(Path(strip), with: .color((column.isMultiple(of: 2) ? Color.white : Color.black).opacity(0.045)))
        }

        let ink = XiangqiAppearance.ink.opacity(0.80)
        let line = StrokeStyle(lineWidth: max(1.1, square * 0.022), lineCap: .round)
        func point(_ row: CGFloat, _ column: CGFloat) -> CGPoint {
            CGPoint(x: square * (column + 0.5), y: square * (row + 0.5))
        }

        for row in 0..<10 {
            context.stroke(Path { path in
                path.move(to: point(CGFloat(row), 0))
                path.addLine(to: point(CGFloat(row), 8))
            }, with: .color(ink), style: line)
        }
        for column in 0..<9 {
            context.stroke(Path { path in
                path.move(to: point(0, CGFloat(column)))
                path.addLine(to: point(4, CGFloat(column)))
                path.move(to: point(5, CGFloat(column)))
                path.addLine(to: point(9, CGFloat(column)))
            }, with: .color(ink), style: line)
        }
        for (start, end) in [
            (point(0, 3), point(2, 5)), (point(0, 5), point(2, 3)),
            (point(7, 3), point(9, 5)), (point(7, 5), point(9, 3))
        ] {
            context.stroke(Path { path in path.move(to: start); path.addLine(to: end) }, with: .color(ink), style: line)
        }
        context.draw(
            Text("皮 卡 鱼 象 棋").font(.system(size: square * 0.32, weight: .semibold, design: .serif)).foregroundColor(ink.opacity(0.70)),
            at: CGPoint(x: square * 4.5, y: square * 5.0)
        )
    }
}

private struct PieceToken: View {
    let piece: Piece
    let square: CGFloat

    private var top: Color { piece.color == .red ? Color(red: 0.78, green: 0.03, blue: 0.08) : Color(red: 0.20, green: 0.21, blue: 0.22) }
    private var bottom: Color { piece.color == .red ? Color(red: 0.43, green: 0.00, blue: 0.03) : Color.black }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(Color.white.opacity(0.34), lineWidth: max(1, square * 0.025)).padding(square * 0.045))
                .overlay(Circle().stroke(Color.black.opacity(0.52), lineWidth: max(1, square * 0.035)))
                .shadow(color: .black.opacity(0.34), radius: square * 0.06, y: square * 0.05)
            Text(piece.glyph)
                .font(.system(size: square * 0.53, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
        }
        .frame(width: square * 0.77, height: square * 0.77)
    }
}
