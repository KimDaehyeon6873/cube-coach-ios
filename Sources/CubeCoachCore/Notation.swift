import Foundation

public enum CubeAxis: String, Codable, Sendable, Equatable, CaseIterable {
    case x, y, z
}

public enum MoveSymbol: String, Codable, Sendable, Equatable, CaseIterable {
    case R, L, U, D, F, B
    case x, y, z

    public var axis: CubeAxis {
        switch self {
        case .R, .L, .x: .x
        case .U, .D, .y: .y
        case .F, .B, .z: .z
        }
    }

    public var isFace: Bool {
        switch self {
        case .R, .L, .U, .D, .F, .B: true
        case .x, .y, .z: false
        }
    }
}

public enum TurnAmount: String, Codable, Sendable, Equatable, CaseIterable {
    case clockwise = ""
    case half = "2"
    case counterclockwise = "'"
}

public struct CubeMove: Codable, Sendable, Equatable, Hashable {
    public let symbol: MoveSymbol
    public let isWide: Bool
    /// Explicit leading layer count (for example `2` in `2Rw`).
    public let layerCount: Int?
    public let amount: TurnAmount

    public init(symbol: MoveSymbol, isWide: Bool = false, layerCount: Int? = nil, amount: TurnAmount = .clockwise) {
        precondition(!isWide || symbol.isFace, "Only face turns may be wide")
        precondition(layerCount == nil || (layerCount == 2 && isWide), "Explicit layer count is supported only for 2-layer wide turns")
        self.symbol = symbol
        self.isWide = isWide
        self.layerCount = layerCount
        self.amount = amount
    }

    public var axis: CubeAxis { symbol.axis }
    public var notation: String { (layerCount.map(String.init) ?? "") + symbol.rawValue + (isWide ? "w" : "") + amount.rawValue }

    public var inverse: CubeMove {
        let inverseAmount: TurnAmount
        switch amount {
        case .clockwise: inverseAmount = .counterclockwise
        case .half: inverseAmount = .half
        case .counterclockwise: inverseAmount = .clockwise
        }
        return CubeMove(
            symbol: symbol,
            isWide: isWide,
            layerCount: layerCount,
            amount: inverseAmount
        )
    }
}

public struct CubeAlgorithm: Codable, Sendable, Equatable, Hashable {
    public let moves: [CubeMove]

    public init(moves: [CubeMove]) { self.moves = moves }
    public var normalized: String { moves.map(\.notation).joined(separator: " ") }
    public var inverse: CubeAlgorithm { CubeAlgorithm(moves: moves.reversed().map(\.inverse)) }
}

public enum WCAParseErrorReason: Sendable, Equatable {
    case unexpectedSymbol(String)
    case invalidLayerPrefix(String)
    case layerPrefixRequiresWide
    case wideModifierRequiresFace
    case duplicateModifier
}

public struct WCAParseError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Zero-based character offset in the original input.
    public let position: Int
    public let reason: WCAParseErrorReason

    public init(position: Int, reason: WCAParseErrorReason) {
        self.position = position
        self.reason = reason
    }

    public var description: String {
        switch reason {
        case let .unexpectedSymbol(symbol): "Unexpected symbol '\(symbol)' at character \(position)"
        case let .invalidLayerPrefix(prefix): "Invalid layer prefix '\(prefix)' at character \(position)"
        case .layerPrefixRequiresWide: "Layer prefix requires a wide face turn at character \(position)"
        case .wideModifierRequiresFace: "Wide modifier requires a face turn at character \(position)"
        case .duplicateModifier: "Duplicate move modifier at character \(position)"
        }
    }
}

public enum WCAParser {
    public static func parse(_ source: String) throws -> CubeAlgorithm {
        let characters = Array(source)
        var index = 0
        var moves: [CubeMove] = []

        while index < characters.count {
            if characters[index].isWhitespace {
                index += 1
                continue
            }

            var layerCount: Int?
            if characters[index].isNumber {
                let prefix = String(characters[index])
                guard prefix == "2" else {
                    throw WCAParseError(position: index, reason: .invalidLayerPrefix(prefix))
                }
                layerCount = 2
                index += 1
                guard index < characters.count else {
                    throw WCAParseError(position: index - 1, reason: .layerPrefixRequiresWide)
                }
            }

            let rawSymbol = String(characters[index])
            guard let symbol = MoveSymbol(rawValue: rawSymbol) else {
                throw WCAParseError(position: index, reason: .unexpectedSymbol(rawSymbol))
            }
            index += 1

            var isWide = false
            if index < characters.count, characters[index] == "w" {
                guard symbol.isFace else {
                    throw WCAParseError(position: index, reason: .wideModifierRequiresFace)
                }
                isWide = true
                index += 1
            }
            if layerCount != nil && !isWide {
                throw WCAParseError(position: index, reason: .layerPrefixRequiresWide)
            }

            var amount = TurnAmount.clockwise
            if index < characters.count {
                switch characters[index] {
                case "2": amount = .half; index += 1
                case "'", "’", "′": amount = .counterclockwise; index += 1
                default: break
                }
            }

            if index < characters.count, characters[index] == "2" || characters[index] == "'" || characters[index] == "’" || characters[index] == "′" {
                throw WCAParseError(position: index, reason: .duplicateModifier)
            }
            moves.append(CubeMove(symbol: symbol, isWide: isWide, layerCount: layerCount, amount: amount))
        }
        return CubeAlgorithm(moves: moves)
    }

    public static func normalize(_ source: String) throws -> String { try parse(source).normalized }
}
