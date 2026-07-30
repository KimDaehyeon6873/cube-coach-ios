import Testing
@testable import CubeCoachCore

@Test func builtInCurriculaIncludeSourcesAndParseableAlgorithms() throws {
    let curricula = CurriculumCatalog.builtIn
    #expect(Set(curricula.map(\.track)) == Set([.beginner, .twoLookCFOP]))
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
            }
        }
    }
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

    let antiSune = try #require(samples["oll-antisune"])
    let antiSuneState = try #require(antiSune.exercise).compile().startState
    #expect(antiSune.notation == "R U2 R' U' R U' R'")
    #expect(antiSune.recognitionHint == "윗색 코너 하나가 오른쪽 뒤.")
    #expect(antiSuneState.faceletString == "FUUUUURUBULLRRRRRRUFLFFFFFFDDDDDDDDDUBBLLLLLLFRRBBBBBB")
    let upCornerIndices = [0, 2, 6, 8] // UBL, UBR, UFL, UFR in URFDLB facelet order.
    let antiSuneFacelets = Array(antiSuneState.faceletString)
    #expect(upCornerIndices.filter { antiSuneFacelets[$0] == "U" } == [2])

    let ua = try #require(samples["pll-ua"])
    let uaState = try #require(ua.exercise).compile().startState
    #expect(ua.notation == "R U' R U R U R U' R' U' R2")
    #expect(uaState.faceletString == "UUUUUUUUURLRRRRRRRFRFFFFFFFDDDDDDDDDLFLLLLLLLBBBBBBBBB")

    let ub = try #require(samples["pll-ub"])
    let ubState = try #require(ub.exercise).compile().startState
    #expect(ub.notation == "R2 U R U R' U' R' U' R' U R'")
    #expect(ubState.faceletString == "UUUUUUUUURFRRRRRRRFLFFFFFFFDDDDDDDDDLRLLLLLLLBBBBBBBBB")

    // With the solved bar on B, the side stickers of the three cycled U-layer
    // edges at UR, UF, and UL form opposite signatures for Ua and Ub.
    let upperEdgeSideIndices = [10, 19, 37, 46] // UR, UF, UL, UB
    #expect(upperEdgeSideIndices.map { Array(uaState.faceletString)[$0] } == ["L", "R", "F", "B"])
    #expect(upperEdgeSideIndices.map { Array(ubState.faceletString)[$0] } == ["F", "L", "R", "B"])
}

@Test func exerciseCompilerRejectsBadChunksAndUnsupportedWideMoves() {
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
        setupNotation: "Rw'",
        solutionNotation: "Rw",
        chunkBoundaries: [0, 1]
    )
    let rejectsWide: Bool = {
        do {
            _ = try wide.compile()
            return false
        } catch LearningExerciseCompilationError.unsupportedMove(let move) {
            return move.isWide
        } catch {
            return false
        }
    }()
    #expect(rejectsWide)
}
