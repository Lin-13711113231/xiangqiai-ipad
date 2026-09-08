import Foundation

/// Retains the exact start position and complete move list for a played game.
/// Pikafish receives this sequence rather than a flattened FEN so its native
/// WXF repetition adjudicator can evaluate long check, long chase, and mixed
/// cyclic positions using the same immutable state history as its search.
struct GameHistory: Equatable {
    let initialFEN: String
    private(set) var positions: [BoardState]
    private(set) var moves: [XiangqiMove]

    init(initial: BoardState = BoardState()) {
        initialFEN = initial.fen()
        positions = [initial]
        moves = []
    }

    var current: BoardState { positions.last ?? BoardState() }
    var count: Int { positions.count }
    var uciMoves: [String] { moves.map(\.uci) }

    mutating func append(_ move: XiangqiMove) {
        precondition(GameRules.legalMoves(in: current).contains(move), "GameHistory only accepts legal moves")
        moves.append(move)
        positions.append(current.applying(move))
    }

    mutating func undo(plies: Int) {
        let removalCount = min(max(0, plies), moves.count)
        guard removalCount > 0 else { return }
        moves.removeLast(removalCount)
        positions.removeLast(removalCount)
    }
}
