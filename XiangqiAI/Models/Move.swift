import Foundation

struct Square: Hashable, Codable, Comparable {
    let row: Int
    let column: Int
    static func < (lhs: Square, rhs: Square) -> Bool { (lhs.row, lhs.column) < (rhs.row, rhs.column) }
}

struct XiangqiMove: Hashable, Codable, Identifiable {
    let from: Square
    let to: Square
    var id: String { "\(from.row),\(from.column)-\(to.row),\(to.column)" }

    /// Converts to Pikafish UCI coordinates: a0 is the red home rank.
    var uci: String {
        func name(_ square: Square) -> String {
            let file = Character(UnicodeScalar(97 + square.column)!)
            return "\(file)\(9 - square.row)"
        }
        return name(from) + name(to)
    }

    static func fromUCI(_ value: String) -> XiangqiMove? {
        let chars = Array(value.lowercased())
        guard chars.count >= 4,
              let a = chars[0].asciiValue, let b = chars[2].asciiValue,
              (97...105).contains(a), (97...105).contains(b),
              let firstRank = chars[1].wholeNumberValue, let secondRank = chars[3].wholeNumberValue,
              (0...9).contains(firstRank), (0...9).contains(secondRank) else { return nil }
        return XiangqiMove(from: Square(row: 9 - firstRank, column: Int(a - 97)),
                           to: Square(row: 9 - secondRank, column: Int(b - 97)))
    }
}
