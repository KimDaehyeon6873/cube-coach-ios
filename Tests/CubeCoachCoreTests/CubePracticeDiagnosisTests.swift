import Testing
@testable import CubeCoachCore

@Test func diagnosesEachPracticeMilestoneFromLegalCubeStates() throws {
    let cases: [(CubeState, CubePracticeStage, CurriculumTrack, String)] = [
        (
            try legalState(
                cornerPermutation: swapping(.upRightFront, .downFrontRight),
                edgePermutation: swapping(.upRight, .downRight)
            ),
            .downCrossIncomplete,
            .beginner,
            "beginner-cross"
        ),
        (
            try legalState(
                cornerPermutation: swapping(.upRightFront, .downFrontRight),
                edgePermutation: swapping(.frontRight, .frontLeft)
            ),
            .downCrossComplete,
            .beginner,
            "beginner-corners"
        ),
        (
            try legalState(
                edgePermutation: doubleSwap(
                    (.frontRight, .frontLeft),
                    (.upRight, .upFront)
                )
            ),
            .firstLayerComplete,
            .beginner,
            "beginner-second-layer"
        ),
        (
            try legalState(
                cornerOrientations: orientations([
                    (CubeCorner.upRightFront, 1),
                    (CubeCorner.upFrontLeft, 2),
                ])
            ),
            .f2lComplete,
            .twoLookCFOP,
            "two-look-oll-corners"
        ),
        (
            try legalState(
                cornerPermutation: swapping(.upRightFront, .upFrontLeft),
                edgePermutation: swapping(.upRight, .upFront)
            ),
            .ollComplete,
            .twoLookCFOP,
            "two-look-pll-corners"
        ),
        (
            try legalState(),
            .complete,
            .twoLookCFOP,
            "cfop-f2l-foundation"
        ),
    ]

    for (state, stage, track, lessonID) in cases {
        let diagnosis = state.practiceDiagnosis
        #expect(diagnosis.stage == stage)
        #expect(diagnosis.recommendedCurriculumTrack == track)
        #expect(diagnosis.recommendedLessonID == lessonID)
        #expect(!diagnosis.title.isEmpty)
        #expect(!diagnosis.practiceGoal.isEmpty)
    }
}

@Test func onlyCompleteStageIsReportedAsSolved() throws {
    let solved = try legalState()
    let pllCase = try legalState(
        cornerPermutation: swapping(.upRightFront, .upFrontLeft),
        edgePermutation: swapping(.upRight, .upFront)
    )

    #expect(CubePracticeDiagnoser.diagnose(solved).isSolved)
    #expect(!CubePracticeDiagnoser.diagnose(pllCase).isSolved)
}

@Test func diagnosesSolvedCubeAfterAnyNonzeroAUFAsFinalAlignment() throws {
    let reportedScan = try CubeState(
        faceletString: "UUUUUUUUUBBBRRRRRRRRRFFFFFFDDDDDDDDDFFFLLLLLLLLLBBBBBB"
    )
    let aufStates = try (1..<4).map { offset in
        try legalState(
            cornerPermutation: rotatingTopLayer(CubeCorner.allCases, by: offset),
            edgePermutation: rotatingTopLayer(CubeEdge.allCases, by: offset)
        )
    }

    for state in [reportedScan] + aufStates {
        let diagnosis = state.practiceDiagnosis
        #expect(diagnosis.stage == .aufRequired)
        #expect(!diagnosis.isSolved)
        #expect(diagnosis.title == "마지막 U면 정렬(AUF)")
        #expect(diagnosis.practiceGoal.contains("윗면 회전"))
        #expect(diagnosis.recommendedLessonID != "two-look-pll-corners")
        #expect(diagnosis.recommendedLessonID == "cfop-auf")
    }
}

@Test func separatesOLLAndPLLSubstagesForTargetedPractice() throws {
    let ollEdges = try legalState(
        edgeOrientations: orientations([
            (CubeEdge.upRight, 1),
            (CubeEdge.upFront, 1),
        ], count: 12)
    )
    let ollCorners = try legalState(
        cornerOrientations: orientations([
            (CubeCorner.upRightFront, 1),
            (CubeCorner.upFrontLeft, 2),
        ])
    )
    let pllCorners = try legalState(
        cornerPermutation: swapping(.upRightFront, .upFrontLeft),
        edgePermutation: swapping(.upRight, .upFront)
    )
    let pllEdges = try legalState(
        edgePermutation: doubleSwap(
            (.upRight, .upFront),
            (.upLeft, .upBack)
        )
    )

    #expect(ollEdges.practiceDiagnosis.recommendedLessonID == "two-look-oll-edges")
    #expect(ollCorners.practiceDiagnosis.recommendedLessonID == "two-look-oll-corners")
    #expect(pllCorners.practiceDiagnosis.recommendedLessonID == "two-look-pll-corners")
    #expect(pllEdges.practiceDiagnosis.recommendedLessonID == "two-look-pll-edges")
}

@Test func preservesPLLCornerAndEdgeRoutingUnderAUF() throws {
    let pllCorners: [CubeCorner] = swapping(.upRightFront, .upFrontLeft)
    let pllCornerEdges: [CubeEdge] = swapping(.upRight, .upFront)
    let pllEdges: [CubeEdge] = doubleSwap(
        (.upRight, .upFront),
        (.upLeft, .upBack)
    )

    for offset in 0..<4 {
        let cornerCase = try legalState(
            cornerPermutation: rotatingTopLayer(pllCorners, by: offset),
            edgePermutation: rotatingTopLayer(pllCornerEdges, by: offset)
        )
        let edgeCase = try legalState(
            cornerPermutation: rotatingTopLayer(CubeCorner.allCases, by: offset),
            edgePermutation: rotatingTopLayer(pllEdges, by: offset)
        )

        #expect(cornerCase.practiceDiagnosis.recommendedLessonID == "two-look-pll-corners")
        #expect(edgeCase.practiceDiagnosis.recommendedLessonID == "two-look-pll-edges")
    }
}

@Test func everyDiagnosisRecommendationResolvesToAReleaseLesson() {
    let releaseLessonIDs = Set(
        CurriculumCatalog.builtIn.flatMap(\.lessons).map(\.id)
    )
    let recommendationIDs: Set<String> = [
        "beginner-cross",
        "beginner-corners",
        "beginner-second-layer",
        "two-look-oll-edges",
        "two-look-oll-corners",
        "two-look-pll-corners",
        "two-look-pll-edges",
        "cfop-auf",
        "cfop-f2l-foundation",
    ]

    #expect(recommendationIDs.isSubset(of: releaseLessonIDs))
}

private let cornerFacelets = [
    [8, 9, 20], [6, 18, 38], [0, 36, 47], [2, 45, 11],
    [29, 26, 15], [27, 44, 24], [33, 53, 42], [35, 17, 51],
]

private let cornerColors: [[CubeFace]] = [
    [.up, .right, .front],
    [.up, .front, .left],
    [.up, .left, .back],
    [.up, .back, .right],
    [.down, .front, .right],
    [.down, .left, .front],
    [.down, .back, .left],
    [.down, .right, .back],
]

private let edgeFacelets = [
    [5, 10], [7, 19], [3, 37], [1, 46],
    [32, 16], [28, 25], [30, 43], [34, 52],
    [23, 12], [21, 41], [50, 39], [48, 14],
]

private let edgeColors: [[CubeFace]] = [
    [.up, .right], [.up, .front], [.up, .left], [.up, .back],
    [.down, .right], [.down, .front], [.down, .left], [.down, .back],
    [.front, .right], [.front, .left], [.back, .left], [.back, .right],
]

/// Builds a facelet fixture from cubies satisfying the same reachability
/// invariants that `CubeState` validates (orientation sums and parity).
private func legalState(
    cornerPermutation: [CubeCorner] = CubeCorner.allCases,
    cornerOrientations: [Int] = Array(repeating: 0, count: 8),
    edgePermutation: [CubeEdge] = CubeEdge.allCases,
    edgeOrientations: [Int] = Array(repeating: 0, count: 12)
) throws -> CubeState {
    var facelets = CubeFace.allCases.flatMap {
        Array(repeating: $0, count: 9)
    }

    for position in CubeCorner.allCases {
        let indices = cornerFacelets[position.rawValue]
        let cubie = cornerPermutation[position.rawValue]
        let colors = cornerColors[cubie.rawValue]
        let orientation = cornerOrientations[position.rawValue]
        facelets[indices[orientation]] = colors[0]
        facelets[indices[(orientation + 1) % 3]] = colors[1]
        facelets[indices[(orientation + 2) % 3]] = colors[2]
    }

    for position in CubeEdge.allCases {
        let indices = edgeFacelets[position.rawValue]
        let cubie = edgePermutation[position.rawValue]
        let colors = edgeColors[cubie.rawValue]
        let orientation = edgeOrientations[position.rawValue]
        facelets[indices[orientation]] = colors[0]
        facelets[indices[(orientation + 1) % 2]] = colors[1]
    }

    return try CubeState(facelets: facelets)
}

private func swapping<Element: CaseIterable & RawRepresentable>(
    _ first: Element,
    _ second: Element
) -> [Element] where Element.AllCases == [Element], Element.RawValue == Int {
    var values = Element.allCases
    values.swapAt(first.rawValue, second.rawValue)
    return values
}

private func doubleSwap<Element: CaseIterable & RawRepresentable>(
    _ first: (Element, Element),
    _ second: (Element, Element)
) -> [Element] where Element.AllCases == [Element], Element.RawValue == Int {
    var values = Element.allCases
    values.swapAt(first.0.rawValue, first.1.rawValue)
    values.swapAt(second.0.rawValue, second.1.rawValue)
    return values
}

private func orientations<Element: RawRepresentable>(
    _ changes: [(Element, Int)],
    count explicitCount: Int? = nil
) -> [Int] where Element.RawValue == Int {
    let count = explicitCount
        ?? changes.map { $0.0.rawValue }.max().map { max($0 + 1, 8) }
        ?? 8
    var values = Array(repeating: 0, count: count)
    for (element, orientation) in changes {
        values[element.rawValue] = orientation
    }
    return values
}

private func rotatingTopLayer<Element: CaseIterable & RawRepresentable>(
    _ permutation: [Element],
    by offset: Int
) -> [Element] where Element.AllCases == [Element], Element.RawValue == Int {
    var rotated = permutation
    for index in 0..<4 {
        rotated[index] = permutation[(index + offset) % 4]
    }
    return rotated
}
