/// The six face identities used by the standard URFDLB facelet notation.
public enum CubeFace: Character, CaseIterable, Codable, Hashable, Sendable {
    case up = "U"
    case right = "R"
    case front = "F"
    case down = "D"
    case left = "L"
    case back = "B"
}

/// Corner cubies in the order used by the WCA/TNoodle cubie representation.
public enum CubeCorner: Int, CaseIterable, Codable, Hashable, Sendable {
    case upRightFront
    case upFrontLeft
    case upLeftBack
    case upBackRight
    case downFrontRight
    case downLeftFront
    case downBackLeft
    case downRightBack
}

/// Edge cubies in the order used by the WCA/TNoodle cubie representation.
public enum CubeEdge: Int, CaseIterable, Codable, Hashable, Sendable {
    case upRight
    case upFront
    case upLeft
    case upBack
    case downRight
    case downFront
    case downLeft
    case downBack
    case frontRight
    case frontLeft
    case backLeft
    case backRight
}

/// A 3×3 cube represented as cubie permutations and orientations.
public struct CubeCubieState: Equatable, Sendable {
    public let cornerPermutation: [CubeCorner]
    public let cornerOrientations: [Int]
    public let edgePermutation: [CubeEdge]
    public let edgeOrientations: [Int]

    public init(
        cornerPermutation: [CubeCorner],
        cornerOrientations: [Int],
        edgePermutation: [CubeEdge],
        edgeOrientations: [Int]
    ) {
        self.cornerPermutation = cornerPermutation
        self.cornerOrientations = cornerOrientations
        self.edgePermutation = edgePermutation
        self.edgeOrientations = edgeOrientations
    }
}

public enum CubeStateValidationError: Error, Equatable, Sendable {
    case invalidFaceletCount(actual: Int)
    case invalidFaceletSymbol(character: Character, index: Int)
    case duplicateCenters
    case centerMismatch(face: CubeFace, actual: CubeFace)
    case invalidColorCount(face: CubeFace, actual: Int)
    case unknownCorner(position: CubeCorner)
    case duplicateCorner(CubeCorner)
    case missingCorner(CubeCorner)
    case unknownEdge(position: CubeEdge)
    case duplicateEdge(CubeEdge)
    case missingEdge(CubeEdge)
    case invalidCornerOrientationSum
    case invalidEdgeOrientationSum
    case permutationParityMismatch
}

/// A validated 3×3 facelet state.
///
/// Facelets use the standard 54-character URFDLB order: U1...U9,
/// R1...R9, F1...F9, D1...D9, L1...L9, B1...B9.
public struct CubeState: Equatable, Sendable {
    public let facelets: [CubeFace]
    public let cubies: CubeCubieState

    public init(facelets: [CubeFace]) throws {
        guard facelets.count == Self.faceletCount else {
            throw CubeStateValidationError.invalidFaceletCount(actual: facelets.count)
        }

        try Self.validateCenters(in: facelets)
        try Self.validateColorCounts(in: facelets)

        let cubies = try Self.restoreCubies(from: facelets)
        try Self.validateCubies(cubies)

        self.facelets = facelets
        self.cubies = cubies
    }

    public init(faceletString: String) throws {
        let characters = Array(faceletString)
        guard characters.count == Self.faceletCount else {
            throw CubeStateValidationError.invalidFaceletCount(actual: characters.count)
        }

        var facelets: [CubeFace] = []
        facelets.reserveCapacity(Self.faceletCount)
        for (index, character) in characters.enumerated() {
            guard let face = CubeFace(rawValue: character) else {
                throw CubeStateValidationError.invalidFaceletSymbol(
                    character: character,
                    index: index
                )
            }
            facelets.append(face)
        }
        try self.init(facelets: facelets)
    }
}

private extension CubeState {
    static let faceletCount = 54
    static let centerIndices = [4, 13, 22, 31, 40, 49]

    // Kociemba's standard facelet-to-cubie table, converted to zero-based
    // indices in the URFDLB string.
    static let cornerFacelets = [
        [8, 9, 20],   // URF
        [6, 18, 38],  // UFL
        [0, 36, 47],  // ULB
        [2, 45, 11],  // UBR
        [29, 26, 15], // DFR
        [27, 44, 24], // DLF
        [33, 53, 42], // DBL
        [35, 17, 51], // DRB
    ]

    static let cornerColors: [[CubeFace]] = [
        [.up, .right, .front],
        [.up, .front, .left],
        [.up, .left, .back],
        [.up, .back, .right],
        [.down, .front, .right],
        [.down, .left, .front],
        [.down, .back, .left],
        [.down, .right, .back],
    ]

    static let edgeFacelets = [
        [5, 10],  // UR
        [7, 19],  // UF
        [3, 37],  // UL
        [1, 46],  // UB
        [32, 16], // DR
        [28, 25], // DF
        [30, 43], // DL
        [34, 52], // DB
        [23, 12], // FR
        [21, 41], // FL
        [50, 39], // BL
        [48, 14], // BR
    ]

    static let edgeColors: [[CubeFace]] = [
        [.up, .right],
        [.up, .front],
        [.up, .left],
        [.up, .back],
        [.down, .right],
        [.down, .front],
        [.down, .left],
        [.down, .back],
        [.front, .right],
        [.front, .left],
        [.back, .left],
        [.back, .right],
    ]

    static func validateCenters(in facelets: [CubeFace]) throws {
        let centers = centerIndices.map { facelets[$0] }
        guard Set(centers).count == CubeFace.allCases.count else {
            throw CubeStateValidationError.duplicateCenters
        }

        for (face, center) in zip(CubeFace.allCases, centers) where face != center {
            throw CubeStateValidationError.centerMismatch(face: face, actual: center)
        }
    }

    static func validateColorCounts(in facelets: [CubeFace]) throws {
        for face in CubeFace.allCases {
            let count = facelets.lazy.filter { $0 == face }.count
            guard count == 9 else {
                throw CubeStateValidationError.invalidColorCount(face: face, actual: count)
            }
        }
    }

    static func restoreCubies(from facelets: [CubeFace]) throws -> CubeCubieState {
        var cornerPermutation: [CubeCorner] = []
        var cornerOrientations: [Int] = []

        for position in CubeCorner.allCases {
            let positionFacelets = cornerFacelets[position.rawValue]
            guard let orientation = (0..<3).first(where: {
                let color = facelets[positionFacelets[$0]]
                return color == .up || color == .down
            }) else {
                throw CubeStateValidationError.unknownCorner(position: position)
            }

            let second = facelets[positionFacelets[(orientation + 1) % 3]]
            let third = facelets[positionFacelets[(orientation + 2) % 3]]
            guard let cubie = CubeCorner.allCases.first(where: {
                let colors = cornerColors[$0.rawValue]
                return colors[1] == second && colors[2] == third
            }) else {
                throw CubeStateValidationError.unknownCorner(position: position)
            }

            cornerPermutation.append(cubie)
            cornerOrientations.append(orientation % 3)
        }

        var edgePermutation: [CubeEdge] = []
        var edgeOrientations: [Int] = []

        for position in CubeEdge.allCases {
            let positionFacelets = edgeFacelets[position.rawValue]
            let first = facelets[positionFacelets[0]]
            let second = facelets[positionFacelets[1]]

            if let cubie = CubeEdge.allCases.first(where: {
                let colors = edgeColors[$0.rawValue]
                return colors[0] == first && colors[1] == second
            }) {
                edgePermutation.append(cubie)
                edgeOrientations.append(0)
            } else if let cubie = CubeEdge.allCases.first(where: {
                let colors = edgeColors[$0.rawValue]
                return colors[0] == second && colors[1] == first
            }) {
                edgePermutation.append(cubie)
                edgeOrientations.append(1)
            } else {
                throw CubeStateValidationError.unknownEdge(position: position)
            }
        }

        return CubeCubieState(
            cornerPermutation: cornerPermutation,
            cornerOrientations: cornerOrientations,
            edgePermutation: edgePermutation,
            edgeOrientations: edgeOrientations
        )
    }

    static func validateCubies(_ cubies: CubeCubieState) throws {
        try validateUnique(
            cubies.cornerPermutation,
            allCases: CubeCorner.allCases,
            duplicateError: CubeStateValidationError.duplicateCorner,
            missingError: CubeStateValidationError.missingCorner
        )
        try validateUnique(
            cubies.edgePermutation,
            allCases: CubeEdge.allCases,
            duplicateError: CubeStateValidationError.duplicateEdge,
            missingError: CubeStateValidationError.missingEdge
        )

        guard cubies.cornerOrientations.reduce(0, +).isMultiple(of: 3) else {
            throw CubeStateValidationError.invalidCornerOrientationSum
        }
        guard cubies.edgeOrientations.reduce(0, +).isMultiple(of: 2) else {
            throw CubeStateValidationError.invalidEdgeOrientationSum
        }
        guard permutationParity(cubies.cornerPermutation.map(\.rawValue))
                == permutationParity(cubies.edgePermutation.map(\.rawValue)) else {
            throw CubeStateValidationError.permutationParityMismatch
        }
    }

    static func validateUnique<Element: Hashable>(
        _ values: [Element],
        allCases: [Element],
        duplicateError: (Element) -> CubeStateValidationError,
        missingError: (Element) -> CubeStateValidationError
    ) throws {
        var seen: Set<Element> = []
        for value in values where !seen.insert(value).inserted {
            throw duplicateError(value)
        }
        for value in allCases where !seen.contains(value) {
            throw missingError(value)
        }
    }

    static func permutationParity(_ permutation: [Int]) -> Int {
        var inversions = 0
        for left in permutation.indices {
            for right in permutation.indices where right > left
                && permutation[left] > permutation[right] {
                inversions += 1
            }
        }
        return inversions % 2
    }
}
