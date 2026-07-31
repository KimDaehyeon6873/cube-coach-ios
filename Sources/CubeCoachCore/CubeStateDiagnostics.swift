/// Identifies whether a diagnostic location is an edge or corner position.
public enum CubePiecePosition: Equatable, Hashable, Sendable {
    case edge(CubeEdge)
    case corner(CubeCorner)
}

/// A physical cubie position together with the facelets that form it.
public struct CubePieceLocation: Equatable, Sendable {
    public let position: CubePiecePosition
    public let notation: String
    public let koreanLabel: String
    public let faceletIndices: [Int]
    public let expectedColors: [CubeFace]
    public let observedColors: [CubeFace]?

    public init(
        position: CubePiecePosition,
        notation: String,
        koreanLabel: String,
        faceletIndices: [Int],
        expectedColors: [CubeFace],
        observedColors: [CubeFace]?
    ) {
        self.position = position
        self.notation = notation
        self.koreanLabel = koreanLabel
        self.faceletIndices = faceletIndices
        self.expectedColors = expectedColors
        self.observedColors = observedColors
    }
}

/// A legal color combination for one physical cubie.
public struct CubeCubieColorCombination: Equatable, Sendable {
    public let notation: String
    public let koreanLabel: String
    public let colors: [CubeFace]

    public init(notation: String, koreanLabel: String, colors: [CubeFace]) {
        self.notation = notation
        self.koreanLabel = koreanLabel
        self.colors = colors
    }
}

/// Actionable scan information derived from a cube validation failure.
///
/// `affectedLocations` contains positions directly named by the error or positions
/// whose observed colors match a duplicated cubie. `candidateLocations` is used for
/// global constraints such as orientation sums and permutation parity; candidates
/// must not be interpreted as a uniquely identified bad cubie.
public struct CubeStateDiagnostic: Equatable, Sendable {
    public let error: CubeStateValidationError
    public let affectedLocations: [CubePieceLocation]
    public let candidateLocations: [CubePieceLocation]
    public let validColorCombinations: [CubeCubieColorCombination]
    public let guidance: String

    public init(
        error: CubeStateValidationError,
        affectedLocations: [CubePieceLocation],
        candidateLocations: [CubePieceLocation],
        validColorCombinations: [CubeCubieColorCombination],
        guidance: String
    ) {
        self.error = error
        self.affectedLocations = affectedLocations
        self.candidateLocations = candidateLocations
        self.validColorCombinations = validColorCombinations
        self.guidance = guidance
    }

    /// Short Korean heading suitable for a scan-error card.
    public var title: String {
        switch error {
        case .unknownEdge: "알 수 없는 엣지"
        case .unknownCorner: "알 수 없는 코너"
        case .duplicateEdge: "중복된 엣지"
        case .duplicateCorner: "중복된 코너"
        case .missingEdge: "누락된 엣지"
        case .missingCorner: "누락된 코너"
        case .invalidEdgeOrientationSum: "뒤집힌 엣지 확인"
        case .invalidCornerOrientationSum: "돌아간 코너 확인"
        case .permutationParityMismatch: "조각 자리 확인"
        case .invalidFaceletCount: "스티커 개수 오류"
        case .invalidFaceletSymbol: "스티커 기호 오류"
        case .duplicateCenters: "센터 색 중복"
        case .centerMismatch: "센터 위치 오류"
        case .invalidColorCount: "색 개수 오류"
        }
    }

    /// Alias with UI-oriented naming.
    public var detail: String { guidance }

    /// Facelets directly implicated by a local unknown/duplicate/missing error.
    public var highlightedFaceletIndices: [Int] {
        uniqueIndices(from: affectedLocations)
    }

    /// Facelets that are possible sources of a global orientation/parity error.
    /// These are candidates only and are deliberately separate from highlights.
    public var candidateFaceletIndices: [Int] {
        uniqueIndices(from: candidateLocations)
    }

    /// Observed colors grouped in the same order as `affectedLocations`.
    public var observedColorGroups: [[CubeFace]] {
        affectedLocations.compactMap(\.observedColors)
    }

    private func uniqueIndices(from locations: [CubePieceLocation]) -> [Int] {
        var seen: Set<Int> = []
        return locations.flatMap(\.faceletIndices).filter { seen.insert($0).inserted }
    }
}

/// Stable URFDLB position metadata and validation-error diagnostics.
public enum CubeStateDiagnostics {
    public static let edgeColorCombinations: [CubeCubieColorCombination] = edgeMetadata.map {
        CubeCubieColorCombination(notation: $0.notation, koreanLabel: $0.koreanLabel, colors: $0.colors)
    }

    public static let cornerColorCombinations: [CubeCubieColorCombination] = cornerMetadata.map {
        CubeCubieColorCombination(notation: $0.notation, koreanLabel: $0.koreanLabel, colors: $0.colors)
    }

    public static func location(
        for edge: CubeEdge,
        facelets: [CubeFace]? = nil
    ) -> CubePieceLocation {
        location(edgeMetadata[edge.rawValue], facelets: facelets)
    }

    public static func location(
        for corner: CubeCorner,
        facelets: [CubeFace]? = nil
    ) -> CubePieceLocation {
        location(cornerMetadata[corner.rawValue], facelets: facelets)
    }

    /// Creates guidance for a validation error. Supplying the attempted 54 facelets
    /// adds the colors actually seen at every referenced position.
    public static func diagnostic(
        for error: CubeStateValidationError,
        facelets: [CubeFace]? = nil
    ) -> CubeStateDiagnostic {
        switch error {
        case let .unknownEdge(position):
            return result(
                error,
                affected: [location(for: position, facelets: facelets)],
                combinations: edgeColorCombinations,
                guidance: "표시된 엣지의 두 색을 확인하세요.\n아래의 가능한 조합과 비교해 주세요."
            )
        case let .unknownCorner(position):
            return result(
                error,
                affected: [location(for: position, facelets: facelets)],
                combinations: cornerColorCombinations,
                guidance: "표시된 코너의 세 색을 확인하세요.\n아래의 가능한 조합과 비교해 주세요."
            )
        case let .duplicateEdge(edge):
            let matches = matchingEdgeLocations(edge, facelets: facelets)
            return result(
                error,
                affected: matches.isEmpty ? [location(for: edge, facelets: facelets)] : matches,
                combinations: edgeColorCombinations,
                guidance: "같은 엣지 색 조합이 두 번 인식됐어요.\n표시된 위치를 다시 촬영해 주세요."
            )
        case let .duplicateCorner(corner):
            let matches = matchingCornerLocations(corner, facelets: facelets)
            return result(
                error,
                affected: matches.isEmpty ? [location(for: corner, facelets: facelets)] : matches,
                combinations: cornerColorCombinations,
                guidance: "같은 코너 색 조합이 두 번 인식됐어요.\n표시된 위치를 다시 촬영해 주세요."
            )
        case let .missingEdge(edge):
            return result(
                error,
                combinations: [edgeColorCombinations[edge.rawValue]],
                guidance: "필요한 엣지 색 조합이 없어요.\n중복되거나 잘못 인식된 엣지를 확인해 주세요."
            )
        case let .missingCorner(corner):
            return result(
                error,
                combinations: [cornerColorCombinations[corner.rawValue]],
                guidance: "필요한 코너 색 조합이 없어요.\n중복되거나 잘못 인식된 코너를 확인해 주세요."
            )
        case .invalidEdgeOrientationSum:
            return result(
                error,
                candidates: CubeEdge.allCases.map { location(for: $0, facelets: facelets) },
                combinations: edgeColorCombinations,
                guidance: "한 엣지가 뒤집혀 입력된 것 같아요.\n한 조각으로 단정할 수 없어 주황 후보를 먼저 확인해 주세요."
            )
        case .invalidCornerOrientationSum:
            return result(
                error,
                candidates: CubeCorner.allCases.map { location(for: $0, facelets: facelets) },
                combinations: cornerColorCombinations,
                guidance: "한 코너가 돌아가 입력된 것 같아요.\n한 조각으로 단정할 수 없어 주황 후보를 먼저 확인해 주세요."
            )
        case .permutationParityMismatch:
            let candidates = CubeCorner.allCases.map { location(for: $0, facelets: facelets) }
                + CubeEdge.allCases.map { location(for: $0, facelets: facelets) }
            return result(
                error,
                candidates: candidates,
                combinations: cornerColorCombinations + edgeColorCombinations,
                guidance: "엣지와 코너의 자리 짝이 맞지 않아요.\n한 조각으로 단정할 수 없어 주황 후보를 먼저 확인해 주세요."
            )
        case .invalidFaceletCount, .invalidFaceletSymbol, .duplicateCenters,
             .centerMismatch, .invalidColorCount:
            return result(
                error,
                guidance: "전개도의 색과 개수를 확인해 주세요.\n필요하면 해당 면을 다시 촬영해 주세요."
            )
        }
    }
}

private extension CubeStateDiagnostics {
    struct Metadata {
        let position: CubePiecePosition
        let notation: String
        let koreanLabel: String
        let indices: [Int]
        let colors: [CubeFace]
    }

    static let edgeMetadata: [Metadata] = [
        Metadata(position: .edge(.upRight), notation: "UR", koreanLabel: "위-오른쪽 엣지", indices: [5, 10], colors: [.up, .right]),
        Metadata(position: .edge(.upFront), notation: "UF", koreanLabel: "위-앞 엣지", indices: [7, 19], colors: [.up, .front]),
        Metadata(position: .edge(.upLeft), notation: "UL", koreanLabel: "위-왼쪽 엣지", indices: [3, 37], colors: [.up, .left]),
        Metadata(position: .edge(.upBack), notation: "UB", koreanLabel: "위-뒤 엣지", indices: [1, 46], colors: [.up, .back]),
        Metadata(position: .edge(.downRight), notation: "DR", koreanLabel: "아래-오른쪽 엣지", indices: [32, 16], colors: [.down, .right]),
        Metadata(position: .edge(.downFront), notation: "DF", koreanLabel: "아래-앞 엣지", indices: [28, 25], colors: [.down, .front]),
        Metadata(position: .edge(.downLeft), notation: "DL", koreanLabel: "아래-왼쪽 엣지", indices: [30, 43], colors: [.down, .left]),
        Metadata(position: .edge(.downBack), notation: "DB", koreanLabel: "아래-뒤 엣지", indices: [34, 52], colors: [.down, .back]),
        Metadata(position: .edge(.frontRight), notation: "FR", koreanLabel: "앞-오른쪽 엣지", indices: [23, 12], colors: [.front, .right]),
        Metadata(position: .edge(.frontLeft), notation: "FL", koreanLabel: "앞-왼쪽 엣지", indices: [21, 41], colors: [.front, .left]),
        Metadata(position: .edge(.backLeft), notation: "BL", koreanLabel: "뒤-왼쪽 엣지", indices: [50, 39], colors: [.back, .left]),
        Metadata(position: .edge(.backRight), notation: "BR", koreanLabel: "뒤-오른쪽 엣지", indices: [48, 14], colors: [.back, .right]),
    ]

    static let cornerMetadata: [Metadata] = [
        Metadata(position: .corner(.upRightFront), notation: "URF", koreanLabel: "위-오른쪽-앞 코너", indices: [8, 9, 20], colors: [.up, .right, .front]),
        Metadata(position: .corner(.upFrontLeft), notation: "UFL", koreanLabel: "위-앞-왼쪽 코너", indices: [6, 18, 38], colors: [.up, .front, .left]),
        Metadata(position: .corner(.upLeftBack), notation: "ULB", koreanLabel: "위-왼쪽-뒤 코너", indices: [0, 36, 47], colors: [.up, .left, .back]),
        Metadata(position: .corner(.upBackRight), notation: "UBR", koreanLabel: "위-뒤-오른쪽 코너", indices: [2, 45, 11], colors: [.up, .back, .right]),
        Metadata(position: .corner(.downFrontRight), notation: "DFR", koreanLabel: "아래-앞-오른쪽 코너", indices: [29, 26, 15], colors: [.down, .front, .right]),
        Metadata(position: .corner(.downLeftFront), notation: "DLF", koreanLabel: "아래-왼쪽-앞 코너", indices: [27, 44, 24], colors: [.down, .left, .front]),
        Metadata(position: .corner(.downBackLeft), notation: "DBL", koreanLabel: "아래-뒤-왼쪽 코너", indices: [33, 53, 42], colors: [.down, .back, .left]),
        Metadata(position: .corner(.downRightBack), notation: "DRB", koreanLabel: "아래-오른쪽-뒤 코너", indices: [35, 17, 51], colors: [.down, .right, .back]),
    ]

    static func location(_ metadata: Metadata, facelets: [CubeFace]?) -> CubePieceLocation {
        let observed: [CubeFace]?
        if let facelets, metadata.indices.allSatisfy({ facelets.indices.contains($0) }) {
            observed = metadata.indices.map { facelets[$0] }
        } else {
            observed = nil
        }
        return CubePieceLocation(
            position: metadata.position,
            notation: metadata.notation,
            koreanLabel: metadata.koreanLabel,
            faceletIndices: metadata.indices,
            expectedColors: metadata.colors,
            observedColors: observed
        )
    }

    static func result(
        _ error: CubeStateValidationError,
        affected: [CubePieceLocation] = [],
        candidates: [CubePieceLocation] = [],
        combinations: [CubeCubieColorCombination] = [],
        guidance: String
    ) -> CubeStateDiagnostic {
        CubeStateDiagnostic(
            error: error,
            affectedLocations: affected,
            candidateLocations: candidates,
            validColorCombinations: combinations,
            guidance: guidance
        )
    }

    static func matchingEdgeLocations(_ edge: CubeEdge, facelets: [CubeFace]?) -> [CubePieceLocation] {
        guard let facelets else { return [] }
        let expected = Set(edgeMetadata[edge.rawValue].colors)
        return edgeMetadata
            .map { location($0, facelets: facelets) }
            .filter { $0.observedColors.map(Set.init) == expected }
    }

    static func matchingCornerLocations(_ corner: CubeCorner, facelets: [CubeFace]?) -> [CubePieceLocation] {
        guard let facelets else { return [] }
        let expected = Set(cornerMetadata[corner.rawValue].colors)
        return cornerMetadata
            .map { location($0, facelets: facelets) }
            .filter { $0.observedColors.map(Set.init) == expected }
    }
}
