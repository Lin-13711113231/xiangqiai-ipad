import Foundation

enum GameRules {
    static func legalMoves(in board: BoardState, for color: PieceColor? = nil) -> [XiangqiMove] {
        let movingColor = color ?? board.sideToMove
        return pseudoLegalMoves(in: board, for: movingColor).filter { move in
            let next = board.applying(move)
            return !isInCheck(movingColor, in: next)
        }
    }

    static func legalMoves(from square: Square, in board: BoardState) -> [XiangqiMove] {
        legalMoves(in: board).filter { $0.from == square }
    }

    static func isInCheck(_ color: PieceColor, in board: BoardState) -> Bool {
        guard let general = findGeneral(color, in: board) else { return true }
        return isSquare(general, attackedBy: color.opponent, in: board)
    }

    static func gameResult(in board: BoardState, repetitions: Int = 0) -> String? {
        if repetitions >= 3 { return "和棋（重复局面）" }
        if legalMoves(in: board).isEmpty { return board.sideToMove == .red ? "黑方胜" : "红方胜" }
        return nil
    }

    static func isSquare(_ target: Square, attackedBy color: PieceColor, in board: BoardState) -> Bool {
        pseudoLegalMoves(in: board, for: color).contains { $0.to == target }
    }

    private static func findGeneral(_ color: PieceColor, in board: BoardState) -> Square? {
        for row in 0..<10 { for col in 0..<9 where board.squares[row][col] == Piece(color: color, kind: .general) { return Square(row: row, column: col) } }
        return nil
    }

    private static func pseudoLegalMoves(in board: BoardState, for color: PieceColor) -> [XiangqiMove] {
        var all: [XiangqiMove] = []
        for row in 0..<10 {
            for col in 0..<9 {
                let from = Square(row: row, column: col)
                guard let piece = board.piece(at: from), piece.color == color else { continue }
                all += moves(for: piece, from: from, in: board)
            }
        }
        return all
    }

    private static func moves(for piece: Piece, from: Square, in board: BoardState) -> [XiangqiMove] {
        var result: [XiangqiMove] = []
        func add(_ row: Int, _ col: Int) {
            let to = Square(row: row, column: col)
            guard BoardState.isOnBoard(to), board.piece(at: to)?.color != piece.color else { return }
            result.append(XiangqiMove(from: from, to: to))
        }
        func sliding(_ deltas: [(Int, Int)], cannon: Bool = false) {
            for (dr, dc) in deltas {
                var row = from.row + dr, col = from.column + dc, jumped = false
                while BoardState.isOnBoard(Square(row: row, column: col)) {
                    let to = Square(row: row, column: col)
                    if let target = board.piece(at: to) {
                        if cannon {
                            if jumped { if target.color != piece.color { result.append(XiangqiMove(from: from, to: to)) }; break }
                            jumped = true
                        } else { if target.color != piece.color { result.append(XiangqiMove(from: from, to: to)) }; break }
                    } else if !cannon || !jumped { result.append(XiangqiMove(from: from, to: to)) }
                    row += dr; col += dc
                }
            }
        }
        switch piece.kind {
        case .rook: sliding([(1,0),(-1,0),(0,1),(0,-1)])
        case .cannon: sliding([(1,0),(-1,0),(0,1),(0,-1)], cannon: true)
        case .horse:
            for (dr, dc, lr, lc) in [(2,1,1,0),(2,-1,1,0),(-2,1,-1,0),(-2,-1,-1,0),(1,2,0,1),(-1,2,0,1),(1,-2,0,-1),(-1,-2,0,-1)] where board.piece(at: Square(row: from.row + lr, column: from.column + lc)) == nil { add(from.row + dr, from.column + dc) }
        case .elephant:
            for (dr, dc) in [(2,2),(2,-2),(-2,2),(-2,-2)] {
                let to = Square(row: from.row + dr, column: from.column + dc)
                let eye = Square(row: from.row + dr / 2, column: from.column + dc / 2)
                let staysOwnSide = piece.color == .red ? to.row >= 5 : to.row <= 4
                if BoardState.isOnBoard(to), staysOwnSide, board.piece(at: eye) == nil { add(to.row, to.column) }
            }
        case .advisor:
            for (dr, dc) in [(1,1),(1,-1),(-1,1),(-1,-1)] { let to = Square(row: from.row + dr, column: from.column + dc); if inPalace(to, color: piece.color) { add(to.row, to.column) } }
        case .general:
            for (dr, dc) in [(1,0),(-1,0),(0,1),(0,-1)] { let to = Square(row: from.row + dr, column: from.column + dc); if inPalace(to, color: piece.color) { add(to.row, to.column) } }
            // Flying-general capture is a legal pseudo move; post-move safety filtering handles exposure.
            let step = piece.color == .red ? -1 : 1
            var row = from.row + step
            while (0..<10).contains(row) {
                let to = Square(row: row, column: from.column)
                if let target = board.piece(at: to) { if target.kind == .general && target.color != piece.color { result.append(XiangqiMove(from: from, to: to)) }; break }
                row += step
            }
        case .pawn:
            let forward = piece.color == .red ? -1 : 1
            add(from.row + forward, from.column)
            let crossed = piece.color == .red ? from.row <= 4 : from.row >= 5
            if crossed { add(from.row, from.column - 1); add(from.row, from.column + 1) }
        }
        return result
    }

    private static func inPalace(_ square: Square, color: PieceColor) -> Bool {
        (3...5).contains(square.column) && (color == .red ? (7...9).contains(square.row) : (0...2).contains(square.row))
    }
}
