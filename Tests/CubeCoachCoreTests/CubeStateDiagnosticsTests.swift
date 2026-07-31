import Testing
@testable import CubeCoachCore

private let diagnosticSolvedFaces: [CubeFace] = CubeFace.allCases.flatMap {
    Array(repeating: $0, count: 9)
}

@Test func mapsEveryEdgePositionToURFDLBFaceletsAndCombination() {
    let expected: [(CubeEdge, String, [Int], [CubeFace])] = [
        (.upRight, "UR", [5, 10], [.up, .right]),
        (.upFront, "UF", [7, 19], [.up, .front]),
        (.upLeft, "UL", [3, 37], [.up, .left]),
        (.upBack, "UB", [1, 46], [.up, .back]),
        (.downRight, "DR", [32, 16], [.down, .right]),
        (.downFront, "DF", [28, 25], [.down, .front]),
        (.downLeft, "DL", [30, 43], [.down, .left]),
        (.downBack, "DB", [34, 52], [.down, .back]),
        (.frontRight, "FR", [23, 12], [.front, .right]),
        (.frontLeft, "FL", [21, 41], [.front, .left]),
        (.backLeft, "BL", [50, 39], [.back, .left]),
        (.backRight, "BR", [48, 14], [.back, .right]),
    ]

    #expect(CubeStateDiagnostics.edgeColorCombinations.count == 12)
    for (offset, item) in expected.enumerated() {
        let location = CubeStateDiagnostics.location(for: item.0, facelets: diagnosticSolvedFaces)
        #expect(location.position == .edge(item.0))
        #expect(location.notation == item.1)
        #expect(!location.koreanLabel.isEmpty)
        #expect(location.faceletIndices == item.2)
        #expect(location.expectedColors == item.3)
        #expect(location.observedColors == item.3)
        #expect(CubeStateDiagnostics.edgeColorCombinations[offset].colors == item.3)
    }
}

@Test func mapsEveryCornerPositionToURFDLBFaceletsAndCombination() {
    let expected: [(CubeCorner, String, [Int], [CubeFace])] = [
        (.upRightFront, "URF", [8, 9, 20], [.up, .right, .front]),
        (.upFrontLeft, "UFL", [6, 18, 38], [.up, .front, .left]),
        (.upLeftBack, "ULB", [0, 36, 47], [.up, .left, .back]),
        (.upBackRight, "UBR", [2, 45, 11], [.up, .back, .right]),
        (.downFrontRight, "DFR", [29, 26, 15], [.down, .front, .right]),
        (.downLeftFront, "DLF", [27, 44, 24], [.down, .left, .front]),
        (.downBackLeft, "DBL", [33, 53, 42], [.down, .back, .left]),
        (.downRightBack, "DRB", [35, 17, 51], [.down, .right, .back]),
    ]

    #expect(CubeStateDiagnostics.cornerColorCombinations.count == 8)
    for (offset, item) in expected.enumerated() {
        let location = CubeStateDiagnostics.location(for: item.0, facelets: diagnosticSolvedFaces)
        #expect(location.position == .corner(item.0))
        #expect(location.notation == item.1)
        #expect(!location.koreanLabel.isEmpty)
        #expect(location.faceletIndices == item.2)
        #expect(location.expectedColors == item.3)
        #expect(location.observedColors == item.3)
        #expect(CubeStateDiagnostics.cornerColorCombinations[offset].colors == item.3)
    }
}

@Test func unknownAndMissingDiagnosticsAreActionable() {
    let unknown = CubeStateDiagnostics.diagnostic(
        for: .unknownEdge(position: .frontRight),
        facelets: diagnosticSolvedFaces
    )
    #expect(unknown.affectedLocations.map(\.faceletIndices) == [[23, 12]])
    #expect(unknown.affectedLocations.first?.observedColors == [.front, .right])
    #expect(unknown.title == "알 수 없는 엣지")
    #expect(unknown.detail == unknown.guidance)
    #expect(unknown.highlightedFaceletIndices == [23, 12])
    #expect(unknown.candidateFaceletIndices.isEmpty)
    #expect(unknown.observedColorGroups == [[.front, .right]])
    #expect(unknown.validColorCombinations.count == 12)
    #expect(!unknown.guidance.isEmpty)

    let missing = CubeStateDiagnostics.diagnostic(for: .missingCorner(.downBackLeft))
    #expect(missing.affectedLocations.isEmpty)
    #expect(missing.highlightedFaceletIndices.isEmpty)
    #expect(missing.validColorCombinations.map(\.notation) == ["DBL"])
    #expect(missing.validColorCombinations.first?.colors == [.down, .back, .left])
    #expect(!missing.guidance.isEmpty)
}

@Test func duplicateDiagnosticFindsEveryObservedCopy() {
    var faces = diagnosticSolvedFaces
    for (index, color) in zip([7, 19], [CubeFace.up, .right]) {
        faces[index] = color
    }

    let diagnostic = CubeStateDiagnostics.diagnostic(
        for: .duplicateEdge(.upRight),
        facelets: faces
    )
    #expect(diagnostic.affectedLocations.map(\.notation) == ["UR", "UF"])
    #expect(diagnostic.affectedLocations.map(\.observedColors) == [
        Optional([.up, .right]), Optional([.up, .right]),
    ])
}

@Test func orientationAndParityExposeCandidatesWithoutClaimingCulprit() {
    let edge = CubeStateDiagnostics.diagnostic(
        for: .invalidEdgeOrientationSum,
        facelets: diagnosticSolvedFaces
    )
    #expect(edge.affectedLocations.isEmpty)
    #expect(edge.candidateLocations.count == 12)
    #expect(edge.highlightedFaceletIndices.isEmpty)
    #expect(edge.candidateFaceletIndices.count == 24)
    #expect(edge.validColorCombinations.count == 12)

    let corner = CubeStateDiagnostics.diagnostic(for: .invalidCornerOrientationSum)
    #expect(corner.affectedLocations.isEmpty)
    #expect(corner.candidateLocations.count == 8)

    let parity = CubeStateDiagnostics.diagnostic(for: .permutationParityMismatch)
    #expect(parity.affectedLocations.isEmpty)
    #expect(parity.candidateLocations.count == 20)
    #expect(parity.validColorCombinations.count == 20)
}
