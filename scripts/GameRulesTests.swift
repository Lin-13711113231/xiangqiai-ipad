import Foundation

struct RulesTestFailure: Error { let message: String }
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws { if !condition() { throw RulesTestFailure(message: message) } }
func emptyGrid() -> [[Piece?]] { Array(repeating: Array<Piece?>(repeating: nil, count: 9), count: 10) }
func withGenerals(_ grid: inout [[Piece?]]) { grid[9][4] = Piece(color: .red, kind: .general); grid[0][3] = Piece(color: .black, kind: .general) }

func testRules() throws {
    let initial = BoardState()
    try require(GameRules.legalMoves(in: initial).count == 44, "Initial legal-move count should be 44")
    try require(XiangqiMove.fromUCI("a0a1")?.uci == "a0a1", "UCI round trip failed")

    var horseGrid = emptyGrid(); withGenerals(&horseGrid); horseGrid[7][4] = Piece(color: .red, kind: .horse); horseGrid[6][4] = Piece(color: .red, kind: .pawn)
    let horse = BoardState(squares: horseGrid, sideToMove: .red)
    try require(!GameRules.legalMoves(from: Square(row: 7, column: 4), in: horse).contains(XiangqiMove(from: Square(row: 7, column: 4), to: Square(row: 5, column: 5))), "Horse leg block was ignored")

    var elephantGrid = emptyGrid(); withGenerals(&elephantGrid); elephantGrid[5][2] = Piece(color: .red, kind: .elephant)
    let elephant = BoardState(squares: elephantGrid, sideToMove: .red)
    try require(!GameRules.legalMoves(from: Square(row: 5, column: 2), in: elephant).contains { $0.to.row < 5 }, "Elephant crossed river")

    var cannonGrid = emptyGrid(); withGenerals(&cannonGrid); cannonGrid[5][4] = Piece(color: .red, kind: .cannon); cannonGrid[3][4] = Piece(color: .red, kind: .pawn); cannonGrid[1][4] = Piece(color: .black, kind: .rook)
    let cannon = BoardState(squares: cannonGrid, sideToMove: .red)
    try require(GameRules.legalMoves(from: Square(row: 5, column: 4), in: cannon).contains(XiangqiMove(from: Square(row: 5, column: 4), to: Square(row: 1, column: 4))), "Cannon screen capture missing")

    var flyingGrid = emptyGrid(); flyingGrid[9][4] = Piece(color: .red, kind: .general); flyingGrid[0][4] = Piece(color: .black, kind: .general)
    let flying = BoardState(squares: flyingGrid, sideToMove: .red)
    try require(GameRules.isInCheck(.red, in: flying), "Flying generals should give check")
    print("GameRulesTests: PASS")
}

do { try testRules() } catch { fputs("GameRulesTests: FAIL: \(error)\n", stderr); exit(1) }
