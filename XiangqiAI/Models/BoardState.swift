import Foundation

struct BoardState: Equatable, Codable {
    static let initialFEN = "rheakaehr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RHEAKAEHR w - - 0 1"

    var squares: [[Piece?]]
    var sideToMove: PieceColor
    var halfmoveClock: Int
    var fullmoveNumber: Int

    init(fen: String = BoardState.initialFEN) {
        let parsed = Self.parseFEN(fen) ?? Self.parseFEN(BoardState.initialFEN)!
        squares = parsed.squares
        sideToMove = parsed.sideToMove
        halfmoveClock = parsed.halfmoveClock
        fullmoveNumber = parsed.fullmoveNumber
    }

    init(squares: [[Piece?]], sideToMove: PieceColor, halfmoveClock: Int = 0, fullmoveNumber: Int = 1) {
        self.squares = squares
        self.sideToMove = sideToMove
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
    }

    subscript(_ square: Square) -> Piece? {
        get { squares[square.row][square.column] }
        set { squares[square.row][square.column] = newValue }
    }

    func piece(at square: Square) -> Piece? { guard Self.isOnBoard(square) else { return nil }; return squares[square.row][square.column] }
    static func isOnBoard(_ square: Square) -> Bool { (0..<10).contains(square.row) && (0..<9).contains(square.column) }

    func applying(_ move: XiangqiMove) -> BoardState {
        var next = self
        let moved = next[move.from]
        let captured = next[move.to]
        next[move.to] = moved
        next[move.from] = nil
        next.sideToMove = sideToMove.opponent
        next.halfmoveClock = (moved?.kind == .pawn || captured != nil) ? 0 : halfmoveClock + 1
        if sideToMove == .black { next.fullmoveNumber += 1 }
        return next
    }

    func fen() -> String {
        let rows = squares.map { row -> String in
            var result = ""; var empties = 0
            for piece in row {
                guard let piece else { empties += 1; continue }
                if empties > 0 { result += "\(empties)"; empties = 0 }
                let c = piece.kind.fenRed
                result.append(piece.color == .red ? c : Character(c.lowercased()))
            }
            if empties > 0 { result += "\(empties)" }
            return result
        }
        return "\(rows.joined(separator: "/")) \(sideToMove.fenSide) - - \(halfmoveClock) \(fullmoveNumber)"
    }

    var positionKey: String { fen().split(separator: " ").prefix(2).joined(separator: " ") }

    private static func parseFEN(_ fen: String) -> BoardState? {
        let fields = fen.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 2 else { return nil }
        let ranks = fields[0].split(separator: "/")
        guard ranks.count == 10 else { return nil }
        var grid = Array(repeating: Array<Piece?>(repeating: nil, count: 9), count: 10)
        for (row, rank) in ranks.enumerated() {
            var col = 0
            for ch in rank {
                if let count = ch.wholeNumberValue { col += count; continue }
                guard col < 9, let piece = piece(fromFEN: ch) else { return nil }
                grid[row][col] = piece; col += 1
            }
            guard col == 9 else { return nil }
        }
        let side: PieceColor = fields[1].lowercased() == "b" ? .black : .red
        let half = fields.count > 4 ? Int(fields[4]) ?? 0 : 0
        let full = fields.count > 5 ? Int(fields[5]) ?? 1 : 1
        return BoardState(squares: grid, sideToMove: side, halfmoveClock: half, fullmoveNumber: full)
    }

    private static func piece(fromFEN character: Character) -> Piece? {
        let color: PieceColor = character.isUppercase ? .red : .black
        switch character.lowercased() {
        case "k": return Piece(color: color, kind: .general)
        case "a": return Piece(color: color, kind: .advisor)
        case "e": return Piece(color: color, kind: .elephant)
        case "h": return Piece(color: color, kind: .horse)
        case "r": return Piece(color: color, kind: .rook)
        case "c": return Piece(color: color, kind: .cannon)
        case "p": return Piece(color: color, kind: .pawn)
        default: return nil
        }
    }
}
