import Foundation

enum PieceColor: String, Codable, CaseIterable {
    case red, black
    var opponent: PieceColor { self == .red ? .black : .red }
    var fenSide: String { self == .red ? "w" : "b" }
}

enum PieceKind: String, Codable, CaseIterable {
    case general, advisor, elephant, horse, rook, cannon, pawn

    func glyph(for color: PieceColor) -> String {
        switch (color, self) {
        case (.red, .general): return "帅"
        case (.red, .advisor): return "仕"
        case (.red, .elephant): return "相"
        case (.red, .horse): return "马"
        case (.red, .rook): return "车"
        case (.red, .cannon): return "炮"
        case (.red, .pawn): return "兵"
        case (.black, .general): return "将"
        case (.black, .advisor): return "士"
        case (.black, .elephant): return "象"
        case (.black, .horse): return "馬"
        case (.black, .rook): return "車"
        case (.black, .cannon): return "砲"
        case (.black, .pawn): return "卒"
        }
    }

    var fenRed: Character {
        switch self { case .rook: return "R"; case .horse: return "H"; case .elephant: return "E"; case .advisor: return "A"; case .general: return "K"; case .cannon: return "C"; case .pawn: return "P" }
    }
}

struct Piece: Equatable, Codable, Identifiable {
    let color: PieceColor
    let kind: PieceKind
    var id: String { "\(color.rawValue)-\(kind.rawValue)" }
    var glyph: String { kind.glyph(for: color) }
}
