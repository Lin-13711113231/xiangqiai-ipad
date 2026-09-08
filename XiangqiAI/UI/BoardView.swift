import SwiftUI

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
            let size = CGSize(width: square * 9, height: square * 10)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in drawBoard(context: context, square: square) }
                    .frame(width: size.width, height: size.height)
                ForEach(0..<10, id: \.self) { row in
                    ForEach(0..<9, id: \.self) { column in
                        let cell = Square(row: row, column: column)
                        Button { if enabled { onTap(cell) } } label: {
                            ZStack {
                                if selected == cell { RoundedRectangle(cornerRadius: 7).fill(.blue.opacity(0.28)).padding(2) }
                                if legalDestinations.contains(cell) { Circle().fill(.blue.opacity(0.45)).frame(width: square * 0.22, height: square * 0.22) }
                                if lastMove?.from == cell || lastMove?.to == cell { RoundedRectangle(cornerRadius: 7).stroke(.orange, lineWidth: 3).padding(3) }
                                if let piece = board.piece(at: cell) {
                                    Circle().fill(Color(red: 0.94, green: 0.82, blue: 0.55)).overlay(Circle().stroke(Color(red: 0.30, green: 0.16, blue: 0.08), lineWidth: 2))
                                    Text(piece.glyph).font(.system(size: square * 0.56, weight: .bold, design: .serif)).foregroundStyle(piece.color == .red ? .red : .black)
                                }
                            }
                            .frame(width: square, height: square)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: square * (CGFloat(column) + 0.5), y: square * (CGFloat(row) + 0.5))
                        .disabled(!enabled)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .aspectRatio(0.9, contentMode: .fit)
        .accessibilityLabel("中国象棋棋盘")
    }

    private func drawBoard(context: GraphicsContext, square: CGFloat) {
        let ink = Color(red: 0.28, green: 0.13, blue: 0.05)
        let line = StrokeStyle(lineWidth: max(1, square * 0.025))
        func point(_ row: CGFloat, _ column: CGFloat) -> CGPoint { CGPoint(x: square * (column + 0.5), y: square * (row + 0.5)) }
        for row in 0..<10 { context.stroke(Path { $0.move(to: point(CGFloat(row), 0)); $0.addLine(to: point(CGFloat(row), 8)) }, with: .color(ink), style: line) }
        for col in 0..<9 {
            context.stroke(Path { path in path.move(to: point(0, CGFloat(col))); path.addLine(to: point(4, CGFloat(col))); path.move(to: point(5, CGFloat(col))); path.addLine(to: point(9, CGFloat(col))) }, with: .color(ink), style: line)
        }
        for (start, end) in [(point(0,3), point(2,5)), (point(0,5), point(2,3)), (point(7,3), point(9,5)), (point(7,5), point(9,3))] { context.stroke(Path { $0.move(to: start); $0.addLine(to: end) }, with: .color(ink), style: line) }
        context.draw(Text("楚 河").font(.system(size: square * 0.48, weight: .bold, design: .serif)).foregroundColor(ink), at: CGPoint(x: square * 2.1, y: square * 5.0))
        context.draw(Text("汉 界").font(.system(size: square * 0.48, weight: .bold, design: .serif)).foregroundColor(ink), at: CGPoint(x: square * 6.0, y: square * 5.0))
    }
}
