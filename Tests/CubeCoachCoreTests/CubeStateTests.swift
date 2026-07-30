import Testing
@testable import CubeCoachCore

private let solvedFacelets =
    "UUUUUUUUU" +
    "RRRRRRRRR" +
    "FFFFFFFFF" +
    "DDDDDDDDD" +
    "LLLLLLLLL" +
    "BBBBBBBBB"

@Test func restoresSolvedCubeCubies() throws {
    let state = try CubeState(faceletString: solvedFacelets)

    #expect(state.cubies.cornerPermutation == CubeCorner.allCases)
    #expect(state.cubies.cornerOrientations == Array(repeating: 0, count: 8))
    #expect(state.cubies.edgePermutation == CubeEdge.allCases)
    #expect(state.cubies.edgeOrientations == Array(repeating: 0, count: 12))
}

@Test func acceptsLegalTurnStates() throws {
    var facelets = Array(solvedFacelets)
    cycleGroups(&facelets, groups: [
        [8, 9, 20], [6, 18, 38], [0, 36, 47],
    ])
    cycleGroups(&facelets, groups: [
        [5, 10], [7, 19], [3, 37],
    ])

    let state = try CubeState(faceletString: String(facelets))

    #expect(Array(state.cubies.cornerPermutation.prefix(3)) == [
        .upLeftBack, .upRightFront, .upFrontLeft,
    ])
    #expect(Array(state.cubies.edgePermutation.prefix(3)) == [
        .upLeft, .upRight, .upFront,
    ])
}

@Test func rejectsSingleTwistedCorner() {
    var facelets = Array(solvedFacelets)
    cycle(&facelets, indices: [8, 9, 20])

    #expect(throws: CubeStateValidationError.invalidCornerOrientationSum) {
        try CubeState(faceletString: String(facelets))
    }
}

@Test func rejectsSingleFlippedEdge() {
    var facelets = Array(solvedFacelets)
    facelets.swapAt(5, 10)

    #expect(throws: CubeStateValidationError.invalidEdgeOrientationSum) {
        try CubeState(faceletString: String(facelets))
    }
}

@Test func rejectsASingleSwappedEdgePair() {
    var facelets = Array(solvedFacelets)
    facelets.swapAt(5, 7)
    facelets.swapAt(10, 19)

    #expect(throws: CubeStateValidationError.permutationParityMismatch) {
        try CubeState(faceletString: String(facelets))
    }
}

@Test func rejectsWrongColorCounts() {
    var facelets = Array(solvedFacelets)
    facelets[0] = "R"

    #expect(throws: CubeStateValidationError.invalidColorCount(face: .up, actual: 8)) {
        try CubeState(faceletString: String(facelets))
    }
}

@Test func rejectsDuplicateCentersBeforeColorCounts() {
    var facelets = Array(solvedFacelets)
    facelets[13] = "U"

    #expect(throws: CubeStateValidationError.duplicateCenters) {
        try CubeState(faceletString: String(facelets))
    }
}

@Test func requiresCentersInStandardURFDLBPositions() {
    var facelets = Array(solvedFacelets)
    facelets.swapAt(4, 13)

    #expect(throws: CubeStateValidationError.centerMismatch(face: .up, actual: .right)) {
        try CubeState(faceletString: String(facelets))
    }
}

@Test func rejectsDuplicateAndMissingCubie() {
    var facelets = Array(solvedFacelets)
    let cornerFacelets = [
        [8, 9, 20], [6, 18, 38], [0, 36, 47], [2, 45, 11],
        [29, 26, 15], [27, 44, 24], [33, 53, 42], [35, 17, 51],
    ]
    let duplicatedCubieColors: [[Character]] = [
        Array("ULB"), Array("ULB"), Array("UBR"), Array("UBR"),
        Array("DFR"), Array("DFR"), Array("DLF"), Array("DLF"),
    ]
    for (indices, colors) in zip(cornerFacelets, duplicatedCubieColors) {
        for (index, color) in zip(indices, colors) {
            facelets[index] = color
        }
    }

    #expect(throws: CubeStateValidationError.duplicateCorner(.upLeftBack)) {
        try CubeState(faceletString: String(facelets))
    }
}

private func cycle(_ values: inout [Character], indices: [Int]) {
    let last = values[indices[indices.count - 1]]
    for offset in stride(from: indices.count - 1, through: 1, by: -1) {
        values[indices[offset]] = values[indices[offset - 1]]
    }
    values[indices[0]] = last
}

private func cycleGroups(_ values: inout [Character], groups: [[Int]]) {
    let last = groups[groups.count - 1].map { values[$0] }
    for offset in stride(from: groups.count - 1, through: 1, by: -1) {
        for (destination, source) in zip(groups[offset], groups[offset - 1]) {
            values[destination] = values[source]
        }
    }
    for (destination, value) in zip(groups[0], last) {
        values[destination] = value
    }
}
