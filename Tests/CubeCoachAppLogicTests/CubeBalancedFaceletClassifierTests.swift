import Testing
@testable import CubeCoachAppLogic

private let balancedCenters: [CubeFace: CubeRGBSample] = [
    .up: .init(red: 0.94, green: 0.94, blue: 0.91),
    .right: .init(red: 0.82, green: 0.08, blue: 0.06),
    .front: .init(red: 0.05, green: 0.62, blue: 0.16),
    .down: .init(red: 0.96, green: 0.79, blue: 0.05),
    .left: .init(red: 0.96, green: 0.35, blue: 0.04),
    .back: .init(red: 0.05, green: 0.25, blue: 0.84),
]

private func uniformGrid(_ face: CubeFace) -> [CubeRGBSample] {
    Array(repeating: balancedCenters[face]!, count: 9)
}

@Test func balancedClassifierProducesExactlyNineFaceletsPerColor() throws {
    var grids = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.map { ($0, uniformGrid($0)) })
    // Make twelve non-center samples locally look red. Global assignment must
    // still preserve the physical nine-per-color invariant.
    for (face, index) in [(.front, 0), (.front, 1), (.front, 2), (.back, 0)] as [(CubeFace, Int)] {
        grids[face]![index] = balancedCenters[.right]!
    }

    let result = try CubeBalancedFaceletClassifier.classify(
        gridsByFace: grids,
        centers: balancedCenters
    )
    let counts = Dictionary(grouping: result.values.flatMap { $0 }, by: \.colorFace)
        .mapValues(\.count)

    for face in CubeFace.faceletOrder {
        #expect(counts[face] == 9)
    }
}

@Test func balancedClassifierLocksEveryCenterToItsCapturedFace() throws {
    let grids = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.map { face in
        var samples = uniformGrid(face)
        samples[4] = balancedCenters[face == .up ? .right : .up]!
        return (face, samples)
    })

    let result = try CubeBalancedFaceletClassifier.classify(
        gridsByFace: grids,
        centers: balancedCenters
    )

    for face in CubeFace.faceletOrder {
        #expect(result[face]?[4].colorFace == face)
    }
}

@Test func balancedClassifierIsDeterministicForEqualCosts() throws {
    let ambiguous = CubeRGBSample(red: 0.45, green: 0.45, blue: 0.45)
    let grids = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.map { face in
        var samples = Array(repeating: ambiguous, count: 9)
        samples[4] = balancedCenters[face]!
        return (face, samples)
    })

    let first = try CubeBalancedFaceletClassifier.classify(
        gridsByFace: grids,
        centers: balancedCenters
    )
    for _ in 0..<5 {
        let next = try CubeBalancedFaceletClassifier.classify(
            gridsByFace: grids,
            centers: balancedCenters
        )
        #expect(next == first)
    }
}

@Test func balancedClassifierKeepsSolvedFaceColorsAndHighConfidence() throws {
    let grids = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.map { ($0, uniformGrid($0)) })
    let result = try CubeBalancedFaceletClassifier.classify(
        gridsByFace: grids,
        centers: balancedCenters
    )

    for face in CubeFace.faceletOrder {
        #expect(result[face]?.allSatisfy { $0.colorFace == face } == true)
        #expect(result[face]?.allSatisfy { $0.confidence > 0.99 } == true)
    }
}

@Test func balancedClassifierMarksForcedAndAmbiguousAssignmentsLowConfidence() throws {
    var grids = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.map { ($0, uniformGrid($0)) })
    // Nine non-center positions compete for the eight red slots. At least one
    // exact-red sample must be globally forced to a non-nearest color.
    grids[.up]![0] = balancedCenters[.right]!
    let result = try CubeBalancedFaceletClassifier.classify(
        gridsByFace: grids,
        centers: balancedCenters
    )
    let forced = result.values.flatMap { $0 }.filter {
        $0.sample == balancedCenters[.right]! && $0.colorFace != .right
    }

    #expect(forced.count == 1)
    #expect(forced[0].confidence == 0)

    let gray = CubeRGBSample(red: 0.45, green: 0.45, blue: 0.45)
    let ambiguousGrids = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.map {
        var samples = Array(repeating: gray, count: 9)
        samples[4] = balancedCenters[$0]!
        return ($0, samples)
    })
    let ambiguousResult = try CubeBalancedFaceletClassifier.classify(
        gridsByFace: ambiguousGrids,
        centers: balancedCenters
    )
    let ambiguousFacelets = ambiguousResult.values.flatMap { $0 }.filter { $0.sample == gray }
    #expect(ambiguousFacelets.contains { $0.confidence == 0 })
}

@Test func balancedClassifierAcceptsDistinctCenters() throws {
    try CubeBalancedFaceletClassifier.validateCenterSeparation(balancedCenters)
}

@Test func balancedClassifierCanValidateCentersAsFacesAreCaptured() throws {
    try CubeBalancedFaceletClassifier.validateCenterSeparation(
        [
            .up: balancedCenters[.up]!,
            .front: balancedCenters[.front]!,
        ],
        requiresCompleteSet: false
    )
}

@Test func balancedClassifierRejectsNearlyIdenticalCentersBeforeAssignment() {
    var centers = balancedCenters
    centers[.right] = .init(red: 0.939, green: 0.94, blue: 0.91)
    let grids = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.map {
        ($0, Array(repeating: centers[$0]!, count: 9))
    })

    #expect(throws: CubeBalancedFaceletClassifier.ClassificationError.indistinguishableCenters(
        first: .up,
        second: .right
    )) {
        try CubeBalancedFaceletClassifier.classify(gridsByFace: grids, centers: centers)
    }
}
