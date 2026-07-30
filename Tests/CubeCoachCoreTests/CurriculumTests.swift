import Testing
@testable import CubeCoachCore

@Test func builtInCurriculaIncludeSourcesAndParseableAlgorithms() throws {
    let curricula = CurriculumCatalog.builtIn
    #expect(Set(curricula.map(\.track)) == Set(CurriculumTrack.allCases))
    for curriculum in curricula {
        #expect(!curriculum.lessons.isEmpty)
        for lesson in curriculum.lessons {
            #expect(!lesson.sources.isEmpty)
            for sample in lesson.algorithms {
                _ = try WCAParser.parse(sample.notation)
                let spec = try #require(sample.exercise)
                let compiled = try spec.compile()
                #expect(compiled.solution.normalized == sample.notation)
                #expect(compiled.endState == .solved)
                #expect(compiled.checkpoints.last == compiled.endState)
                #expect(compiled.chunks.count == spec.chunkBoundaries.count - 1)
                #expect(compiled.practiceMode == .guidedAcquisition)
                #expect(compiled.acquisitionSupportLabel.contains("독립 회상 평가 아님"))
                for alternative in sample.alternativeNotations {
                    let execution = try compiled.startState.executing(WCAParser.parse(alternative))
                    #expect(execution.cube == .solved)
                    #expect(execution.orientation == .identity)
                }
            }
        }
    }
}

@Test func releaseCatalogContainsCompleteSpeedcubingSets() {
    let counts = Dictionary(uniqueKeysWithValues: CurriculumCatalog.builtIn.map { curriculum in
        (curriculum.track, curriculum.lessons.flatMap(\.algorithms).count)
    })
    #expect(counts[.beginner] == 10)
    #expect(counts[.twoLookCFOP] == 15)
    #expect(counts[.fullCFOP] == 119)
    #expect(counts[.advancedLastLayer] == 40)
    #expect(counts[.rouxCMLL] == 42)
    #expect(counts.values.reduce(0, +) == 226)

    let samples = CurriculumCatalog.builtIn.flatMap(\.lessons).flatMap(\.algorithms)
    #expect(samples.filter { !$0.alternativeNotations.isEmpty }.count >= 15)
    #expect(CurriculumCatalog.openAlgorithmSource.licenseName == "MIT License")
    #expect(CurriculumCatalog.openCMLLSource.licenseName == "MIT License")
}

@Test func theoryOnlyLessonsDoNotBecomeExecutableTrainerCases() {
    let theoryOnly = CurriculumCatalog.builtIn
        .flatMap(\.lessons)
        .filter(\.algorithms.isEmpty)
    #expect(!theoryOnly.isEmpty)
}

@Test func namedLastLayerCasesMatchSemanticFaceletGoldens() throws {
    // These fixtures intentionally describe the externally named cases rather
    // than deriving expectations from each authored solution. They prevent a
    // solution and its inverse setup from remaining self-consistent after a
    // Ua/Ub name swap or a recognition-hint regression.
    let samples = Dictionary(
        uniqueKeysWithValues: CurriculumCatalog.builtIn
            .flatMap(\.lessons)
            .flatMap(\.algorithms)
            .map { ($0.id, $0) }
    )

    let antiSune = try #require(samples["2look-oll-antisune"])
    let antiSuneState = try #require(antiSune.exercise).compile().startState
    #expect(antiSune.notation == "R U2 R' U' R U' R'")
    #expect(antiSune.recognitionHint.contains("Corners"))
    #expect(antiSuneState.faceletString == "FUUUUURUBULLRRRRRRUFLFFFFFFDDDDDDDDDUBBLLLLLLFRRBBBBBB")
    let upCornerIndices = [0, 2, 6, 8] // UBL, UBR, UFL, UFR in URFDLB facelet order.
    let antiSuneFacelets = Array(antiSuneState.faceletString)
    #expect(upCornerIndices.filter { antiSuneFacelets[$0] == "U" } == [2])

    let ua = try #require(samples["2look-pll-ua-perm"])
    let uaState = try #require(ua.exercise).compile().startState
    #expect(ua.notation == "M2 U M U2 M' U M2")
    #expect(uaState.faceletString == "UUUUUUUUURLRRRRRRRFRFFFFFFFDDDDDDDDDLFLLLLLLLBBBBBBBBB")

    let ub = try #require(samples["2look-pll-ub-perm"])
    let ubState = try #require(ub.exercise).compile().startState
    #expect(ub.notation == "M2 U' M U2 M' U' M2")
    #expect(ubState.faceletString == "UUUUUUUUURFRRRRRRRFLFFFFFFFDDDDDDDDDLRLLLLLLLBBBBBBBBB")

    // With the solved bar on B, the side stickers of the three cycled U-layer
    // edges at UR, UF, and UL form opposite signatures for Ua and Ub.
    let upperEdgeSideIndices = [10, 19, 37, 46] // UR, UF, UL, UB
    #expect(upperEdgeSideIndices.map { Array(uaState.faceletString)[$0] } == ["L", "R", "F", "B"])
    #expect(upperEdgeSideIndices.map { Array(ubState.faceletString)[$0] } == ["F", "L", "R", "B"])
}

@Test func exerciseCompilerRejectsBadChunksAndSupportsWideMoves() throws {
    let badChunks = LearningExerciseSpec(
        setupNotation: "R'",
        solutionNotation: "R",
        chunkBoundaries: [0, 2]
    )
    #expect(throws: LearningExerciseCompilationError.invalidChunkBoundaries(
        boundaries: [0, 2],
        moveCount: 1
    )) {
        try badChunks.compile()
    }

    let wide = LearningExerciseSpec(
        setupNotation: "Rw U' Rw'",
        solutionNotation: "Rw U Rw'",
        chunkBoundaries: [0, 3]
    )
    #expect(try wide.compile().endState == .solved)
}
