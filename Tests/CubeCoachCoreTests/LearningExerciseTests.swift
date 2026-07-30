import Testing
@testable import CubeCoachCore

@Test func exerciseCompilerRejectsSetupThatLeavesARegrippedOrientation() {
    let exercise = LearningExerciseSpec(
        setupNotation: "x R'",
        solutionNotation: "R x'",
        chunkBoundaries: [0, 2]
    )

    #expect(throws: LearningExerciseCompilationError.nonIdentityOrientation(stage: .setup)) {
        try exercise.compile()
    }
}

@Test func exerciseCompilerRejectsSolutionThatLeavesARegrippedOrientation() {
    let exercise = LearningExerciseSpec(
        setupNotation: "",
        solutionNotation: "x",
        chunkBoundaries: [0, 1]
    )

    #expect(throws: LearningExerciseCompilationError.nonIdentityOrientation(stage: .solution)) {
        try exercise.compile()
    }
}

@Test func compiledExercisePreservesValidatedPlaybackIncludingTemporaryRegrips() throws {
    let exercise = LearningExerciseSpec(
        setupNotation: "x x' R'",
        solutionNotation: "R",
        chunkBoundaries: [0, 1]
    )

    let compiled = try exercise.compile()

    #expect(compiled.setupPlayback.count == compiled.setup.moves.count + 1)
    #expect(compiled.solutionPlayback.count == compiled.solution.moves.count + 1)
    #expect(compiled.setupPlayback.contains { $0.executionState.orientation != .identity })
    #expect(compiled.setupPlayback.last?.executionState.orientation == .identity)
    #expect(compiled.solutionPlayback.first?.executionState.cube == compiled.startState)
    #expect(compiled.solutionPlayback.last?.executionState.cube == compiled.endState)
    #expect(compiled.solutionPlayback.last?.executionState.orientation == .identity)
}
