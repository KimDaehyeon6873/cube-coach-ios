import Foundation

public enum LearningExercisePracticeMode: String, Codable, Sendable, Equatable {
    /// The authored setup is deterministic scaffolding for learning the move
    /// sequence. It is not evidence of independent case recognition or recall.
    case guidedAcquisition
}

public enum LearningExerciseExpectedOutcome: String, Codable, Sendable, Equatable {
    case solved
}

/// Authored, serializable metadata for an executable trainer case.
public struct LearningExerciseSpec: Codable, Sendable, Equatable {
    public let setupNotation: String
    public let solutionNotation: String
    /// Strictly increasing move offsets, including zero and the solution move count.
    public let chunkBoundaries: [Int]
    public let expectedOutcome: LearningExerciseExpectedOutcome
    public let practiceMode: LearningExercisePracticeMode
    public let acquisitionSupportLabel: String

    public init(
        setupNotation: String,
        solutionNotation: String,
        chunkBoundaries: [Int],
        expectedOutcome: LearningExerciseExpectedOutcome = .solved,
        practiceMode: LearningExercisePracticeMode = .guidedAcquisition,
        acquisitionSupportLabel: String = "공식 습득용 설정 상태 · 독립 회상 평가 아님"
    ) {
        self.setupNotation = setupNotation
        self.solutionNotation = solutionNotation
        self.chunkBoundaries = chunkBoundaries
        self.expectedOutcome = expectedOutcome
        self.practiceMode = practiceMode
        self.acquisitionSupportLabel = acquisitionSupportLabel
    }

    public func compile() throws -> CompiledLearningExercise {
        let setup: CubeAlgorithm
        do {
            setup = try WCAParser.parse(setupNotation)
        } catch let error as WCAParseError {
            throw LearningExerciseCompilationError.invalidSetupNotation(error)
        }

        let solution: CubeAlgorithm
        do {
            solution = try WCAParser.parse(solutionNotation)
        } catch let error as WCAParseError {
            throw LearningExerciseCompilationError.invalidSolutionNotation(error)
        }

        if let unsupported = (setup.moves + solution.moves).first(where: \.isWide) {
            throw LearningExerciseCompilationError.unsupportedMove(unsupported)
        }

        guard chunkBoundaries.count >= 2,
              chunkBoundaries.first == 0,
              chunkBoundaries.last == solution.moves.count,
              zip(chunkBoundaries, chunkBoundaries.dropFirst()).allSatisfy(<) else {
            throw LearningExerciseCompilationError.invalidChunkBoundaries(
                boundaries: chunkBoundaries,
                moveCount: solution.moves.count
            )
        }

        let setupPlayback = try CubeState.solved.playback(for: setup)
        let startExecution = setupPlayback[setupPlayback.count - 1].executionState
        guard startExecution.orientation == .identity else {
            throw LearningExerciseCompilationError.nonIdentityOrientation(stage: .setup)
        }

        let solutionPlayback = try startExecution.cube.playback(
            for: solution,
            orientation: startExecution.orientation
        )
        var checkpoints: [CubeState] = []
        var chunks: [CubeAlgorithm] = []
        for (lower, upper) in zip(chunkBoundaries, chunkBoundaries.dropFirst()) {
            let chunk = CubeAlgorithm(moves: Array(solution.moves[lower..<upper]))
            chunks.append(chunk)
            checkpoints.append(solutionPlayback[upper].executionState.cube)
        }

        let endExecution = solutionPlayback[solutionPlayback.count - 1].executionState
        let endState = endExecution.cube
        guard endExecution.orientation == .identity else {
            throw LearningExerciseCompilationError.nonIdentityOrientation(stage: .solution)
        }

        if expectedOutcome == .solved, endState != .solved {
            throw LearningExerciseCompilationError.expectedOutcomeMismatch(
                expected: expectedOutcome
            )
        }

        return CompiledLearningExercise(
            spec: self,
            setup: setup,
            solution: solution,
            chunks: chunks,
            setupPlayback: setupPlayback,
            solutionPlayback: solutionPlayback,
            startState: startExecution.cube,
            checkpoints: checkpoints,
            endState: endState
        )
    }
}

public enum LearningExerciseCompilationStage: String, Equatable, Sendable {
    case setup
    case solution
}

public enum LearningExerciseCompilationError: Error, Equatable, Sendable {
    case invalidSetupNotation(WCAParseError)
    case invalidSolutionNotation(WCAParseError)
    case unsupportedMove(CubeMove)
    case invalidChunkBoundaries(boundaries: [Int], moveCount: Int)
    case nonIdentityOrientation(stage: LearningExerciseCompilationStage)
    case expectedOutcomeMismatch(expected: LearningExerciseExpectedOutcome)
}

/// Validated and fully derived exercise content ready for UI playback.
public struct CompiledLearningExercise: Equatable, Sendable {
    public let spec: LearningExerciseSpec
    public let setup: CubeAlgorithm
    public let solution: CubeAlgorithm
    public let chunks: [CubeAlgorithm]
    public let setupPlayback: [CubePlaybackSnapshot]
    public let solutionPlayback: [CubePlaybackSnapshot]
    public let startState: CubeState
    /// State after each chunk. The final checkpoint is `endState`.
    public let checkpoints: [CubeState]
    public let endState: CubeState

    public init(
        spec: LearningExerciseSpec,
        setup: CubeAlgorithm,
        solution: CubeAlgorithm,
        chunks: [CubeAlgorithm],
        setupPlayback: [CubePlaybackSnapshot],
        solutionPlayback: [CubePlaybackSnapshot],
        startState: CubeState,
        checkpoints: [CubeState],
        endState: CubeState
    ) {
        self.spec = spec
        self.setup = setup
        self.solution = solution
        self.chunks = chunks
        self.setupPlayback = setupPlayback
        self.solutionPlayback = solutionPlayback
        self.startState = startState
        self.checkpoints = checkpoints
        self.endState = endState
    }

    public var expectedOutcome: LearningExerciseExpectedOutcome { spec.expectedOutcome }
    public var practiceMode: LearningExercisePracticeMode { spec.practiceMode }
    public var acquisitionSupportLabel: String { spec.acquisitionSupportLabel }
}
