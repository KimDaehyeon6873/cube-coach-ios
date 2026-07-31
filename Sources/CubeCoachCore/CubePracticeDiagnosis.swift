/// A learning-oriented description of how far a validated 3×3 state has progressed.
///
/// The stages deliberately describe what to practise next. They do not contain
/// or generate a solution sequence for the scanned state.
public enum CubePracticeStage: String, CaseIterable, Codable, Sendable, Equatable {
    case downCrossIncomplete
    case downCrossComplete
    case firstLayerComplete
    case f2lComplete
    case ollComplete
    case aufRequired
    case complete
}

/// The concrete, state-based objective for a practice attempt.
///
/// These identifiers describe predicates, not algorithms. In particular, the
/// PLL goals accept a completed last-layer permutation before the final U-face
/// alignment, while `auf` requires the exact solved state.
public enum CubePracticeGoalID: String, CaseIterable, Codable, Sendable, Equatable {
    case cross
    case firstLayer
    case f2l
    case ollEdges
    case ollCorners
    case pllCorners
    case pllEdges
    case auf
}

public struct CubePracticeDiagnosis: Codable, Sendable, Equatable {
    public let stage: CubePracticeStage
    public let goalID: CubePracticeGoalID?
    public let title: String
    public let practiceGoal: String
    public let recommendedCurriculumTrack: CurriculumTrack
    public let recommendedLessonID: String

    public var isSolved: Bool { stage == .complete }

    public init(
        stage: CubePracticeStage,
        goalID: CubePracticeGoalID? = nil,
        title: String,
        practiceGoal: String,
        recommendedCurriculumTrack: CurriculumTrack,
        recommendedLessonID: String
    ) {
        self.stage = stage
        self.goalID = goalID
        self.title = title
        self.practiceGoal = practiceGoal
        self.recommendedCurriculumTrack = recommendedCurriculumTrack
        self.recommendedLessonID = recommendedLessonID
    }
}

public enum CubePracticeDiagnoser {
    /// Classifies a legal cube state by the next layer/CFOP milestone to practise.
    ///
    /// `CubeState` has already established color counts, cubie orientation sums,
    /// and permutation parity. This method only measures progress and never
    /// computes a solving algorithm.
    public static func diagnose(_ state: CubeState) -> CubePracticeDiagnosis {
        if isSolved(state) {
            return CubePracticeDiagnosis(
                stage: .complete,
                title: "큐브 완성",
                practiceGoal: "다음 스크램블에서는 크로스 계획과 F2L 연결을 더 효율적으로 연습하세요.",
                recommendedCurriculumTrack: .fullCFOP,
                recommendedLessonID: "full-f2l"
            )
        }

        if isSolvedAfterAUF(state) {
            return CubePracticeDiagnosis(
                stage: .aufRequired,
                goalID: .auf,
                title: "마지막 U면 정렬(AUF)",
                practiceGoal: "마지막 층을 윗면 회전으로 정렬해 옆면 센터 색에 맞추세요.",
                recommendedCurriculumTrack: .fullCFOP,
                recommendedLessonID: "full-pll"
            )
        }

        guard isDownCrossComplete(state) else {
            return CubePracticeDiagnosis(
                stage: .downCrossIncomplete,
                goalID: .cross,
                title: "D면 십자 연습",
                practiceGoal: "D면 엣지 네 개를 각 옆면 센터 색까지 맞춰 십자를 완성하세요.",
                recommendedCurriculumTrack: .beginner,
                recommendedLessonID: "beginner-cross"
            )
        }

        guard isFirstLayerComplete(state) else {
            return CubePracticeDiagnosis(
                stage: .downCrossComplete,
                goalID: .firstLayer,
                title: "첫 층 코너 연습",
                practiceGoal: "완성한 십자를 유지하면서 D면 코너 네 개를 올바른 슬롯에 넣으세요.",
                recommendedCurriculumTrack: .beginner,
                recommendedLessonID: "beginner-corners"
            )
        }

        guard isF2LComplete(state) else {
            return CubePracticeDiagnosis(
                stage: .firstLayerComplete,
                goalID: .f2l,
                title: "두 번째 층 연습",
                practiceGoal: "첫 층을 보존하며 중간층 엣지를 센터 색에 맞는 슬롯에 삽입하세요.",
                recommendedCurriculumTrack: .beginner,
                recommendedLessonID: "beginner-second-layer"
            )
        }

        guard isUpCrossOriented(state) else {
            return CubePracticeDiagnosis(
                stage: .f2lComplete,
                goalID: .ollEdges,
                title: "OLL 엣지 방향 연습",
                practiceGoal: "F2L을 유지하면서 U면 엣지를 먼저 맞춰 십자를 만드세요.",
                recommendedCurriculumTrack: .twoLookCFOP,
                recommendedLessonID: "two-look-oll-complete"
            )
        }

        guard isUpFaceOriented(state) else {
            return CubePracticeDiagnosis(
                stage: .f2lComplete,
                goalID: .ollCorners,
                title: "OLL 코너 방향 연습",
                practiceGoal: "U면 십자를 유지하면서 네 코너의 방향을 맞추세요.",
                recommendedCurriculumTrack: .twoLookCFOP,
                recommendedLessonID: "two-look-oll-complete"
            )
        }

        guard areUpCornersPermutedModuloAUF(state) else {
            return CubePracticeDiagnosis(
                stage: .ollComplete,
                goalID: .pllCorners,
                title: "PLL 코너 순열 연습",
                practiceGoal: "완성된 U면 방향을 유지하면서 마지막 층 코너의 위치를 먼저 맞추세요.",
                recommendedCurriculumTrack: .twoLookCFOP,
                recommendedLessonID: "two-look-pll-complete"
            )
        }

        return CubePracticeDiagnosis(
            stage: .ollComplete,
            goalID: .pllEdges,
            title: "PLL 엣지 순열 연습",
            practiceGoal: "맞춰진 코너를 유지하면서 마지막 층 엣지를 순환시켜 완성하세요.",
            recommendedCurriculumTrack: .twoLookCFOP,
            recommendedLessonID: "two-look-pll-complete"
        )
    }
}

public enum CubePracticeComparisonOutcome: String, Codable, Sendable, Equatable {
    case achieved
    case improved
    case unchanged
    case regressed
}

public struct CubePracticeComparison: Codable, Sendable, Equatable {
    public let goal: CubePracticeGoalID
    public let outcome: CubePracticeComparisonOutcome
    public let wasAchievedAtStart: Bool
    public let isAchieved: Bool
    public let changedFaceletIndices: [Int]

    public init(
        goal: CubePracticeGoalID,
        outcome: CubePracticeComparisonOutcome,
        wasAchievedAtStart: Bool,
        isAchieved: Bool,
        changedFaceletIndices: [Int]
    ) {
        self.goal = goal
        self.outcome = outcome
        self.wasAchievedAtStart = wasAchievedAtStart
        self.isAchieved = isAchieved
        self.changedFaceletIndices = changedFaceletIndices
    }
}

/// Evaluates a physical before/after scan without producing solving moves.
public enum CubePracticeGoalEvaluator {
    public static func isAchieved(_ goal: CubePracticeGoalID, in state: CubeState) -> Bool {
        switch goal {
        case .cross:
            CubePracticeDiagnoser.isDownCrossComplete(state)
        case .firstLayer:
            CubePracticeDiagnoser.isFirstLayerComplete(state)
        case .f2l:
            CubePracticeDiagnoser.isF2LComplete(state)
        case .ollEdges:
            CubePracticeDiagnoser.isF2LComplete(state)
                && CubePracticeDiagnoser.isUpCrossOriented(state)
        case .ollCorners:
            CubePracticeDiagnoser.isF2LComplete(state)
                && CubePracticeDiagnoser.isUpFaceOriented(state)
        case .pllCorners:
            CubePracticeDiagnoser.isF2LComplete(state)
                && CubePracticeDiagnoser.isUpFaceOriented(state)
                && CubePracticeDiagnoser.areUpCornersPermutedModuloAUF(state)
        case .pllEdges:
            CubePracticeDiagnoser.isF2LComplete(state)
                && CubePracticeDiagnoser.isUpFaceOriented(state)
                && CubePracticeDiagnoser.isUpLayerPermutedModuloAUF(state)
        case .auf:
            CubePracticeDiagnoser.isSolved(state)
        }
    }

    public static func compare(
        start: CubeState,
        result: CubeState,
        goal: CubePracticeGoalID
    ) -> CubePracticeComparison {
        let startAchieved = isAchieved(goal, in: start)
        let resultAchieved = isAchieved(goal, in: result)
        let outcome: CubePracticeComparisonOutcome

        if resultAchieved {
            outcome = .achieved
        } else {
            let startProgress = progress(toward: goal, in: start)
            let resultProgress = progress(toward: goal, in: result)
            if resultProgress.lexicographicallyPrecedes(startProgress) {
                outcome = .regressed
            } else if startProgress.lexicographicallyPrecedes(resultProgress) {
                outcome = .improved
            } else {
                outcome = .unchanged
            }
        }

        return CubePracticeComparison(
            goal: goal,
            outcome: outcome,
            wasAchievedAtStart: startAchieved,
            isAchieved: resultAchieved,
            changedFaceletIndices: zip(start.facelets, result.facelets)
                .enumerated()
                .compactMap { index, pair in pair.0 == pair.1 ? nil : index }
        )
    }
}

public extension CubeState {
    var practiceDiagnosis: CubePracticeDiagnosis {
        CubePracticeDiagnoser.diagnose(self)
    }
}

fileprivate extension CubePracticeDiagnoser {
    static let downCorners: [CubeCorner] = [
        .downFrontRight, .downLeftFront, .downBackLeft, .downRightBack,
    ]
    static let downEdges: [CubeEdge] = [
        .downRight, .downFront, .downLeft, .downBack,
    ]
    static let middleEdges: [CubeEdge] = [
        .frontRight, .frontLeft, .backLeft, .backRight,
    ]
    static let upCorners: [CubeCorner] = [
        .upRightFront, .upFrontLeft, .upLeftBack, .upBackRight,
    ]
    static let upEdges: [CubeEdge] = [
        .upRight, .upFront, .upLeft, .upBack,
    ]

    static func isSolved(_ state: CubeState) -> Bool {
        for (faceIndex, face) in CubeFace.allCases.enumerated() {
            let range = (faceIndex * 9)..<((faceIndex + 1) * 9)
            if state.facelets[range].contains(where: { $0 != face }) {
                return false
            }
        }
        return true
    }

    static func isSolvedAfterAUF(_ state: CubeState) -> Bool {
        downCorners.allSatisfy { isSolved($0, in: state) }
            && downEdges.allSatisfy { isSolved($0, in: state) }
            && middleEdges.allSatisfy { isSolved($0, in: state) }
            && (1..<4).contains { offset in
                isUpLayerPermuted(state, by: offset)
            }
    }

    static func isUpLayerPermutedModuloAUF(_ state: CubeState) -> Bool {
        (0..<4).contains { isUpLayerPermuted(state, by: $0) }
    }

    static func isDownCrossComplete(_ state: CubeState) -> Bool {
        downEdges.allSatisfy { isSolved($0, in: state) }
    }

    static func isFirstLayerComplete(_ state: CubeState) -> Bool {
        isDownCrossComplete(state)
            && downCorners.allSatisfy { isSolved($0, in: state) }
    }

    static func isF2LComplete(_ state: CubeState) -> Bool {
        isFirstLayerComplete(state)
            && middleEdges.allSatisfy { isSolved($0, in: state) }
    }

    static func isUpFaceOriented(_ state: CubeState) -> Bool {
        state.facelets[0..<9].allSatisfy { $0 == .up }
    }

    static func isUpCrossOriented(_ state: CubeState) -> Bool {
        [1, 3, 5, 7].allSatisfy { state.facelets[$0] == .up }
    }

    static func areUpCornersPermutedModuloAUF(_ state: CubeState) -> Bool {
        (0..<4).contains { offset in
            upCorners.enumerated().allSatisfy { index, position in
                state.cubies.cornerPermutation[position.rawValue]
                    == upCorners[(index + offset) % upCorners.count]
            }
        }
    }

    static func isUpLayerPermuted(_ state: CubeState, by offset: Int) -> Bool {
        let cornersMatch = upCorners.enumerated().allSatisfy { index, position in
            state.cubies.cornerPermutation[position.rawValue]
                == upCorners[(index + offset) % upCorners.count]
                && state.cubies.cornerOrientations[position.rawValue] == 0
        }
        let edgesMatch = upEdges.enumerated().allSatisfy { index, position in
            state.cubies.edgePermutation[position.rawValue]
                == upEdges[(index + offset) % upEdges.count]
                && state.cubies.edgeOrientations[position.rawValue] == 0
        }
        return cornersMatch && edgesMatch
    }

    static func isSolved(_ corner: CubeCorner, in state: CubeState) -> Bool {
        let index = corner.rawValue
        return state.cubies.cornerPermutation[index] == corner
            && state.cubies.cornerOrientations[index] == 0
    }

    static func isSolved(_ edge: CubeEdge, in state: CubeState) -> Bool {
        let index = edge.rawValue
        return state.cubies.edgePermutation[index] == edge
            && state.cubies.edgeOrientations[index] == 0
    }
}

private extension CubePracticeGoalEvaluator {
    static func progress(toward goal: CubePracticeGoalID, in state: CubeState) -> [Int] {
        let solvedDownEdges = CubePracticeDiagnoser.downEdges.count {
            CubePracticeDiagnoser.isSolved($0, in: state)
        }
        let solvedDownCorners = CubePracticeDiagnoser.downCorners.count {
            CubePracticeDiagnoser.isSolved($0, in: state)
        }
        let solvedMiddleEdges = CubePracticeDiagnoser.middleEdges.count {
            CubePracticeDiagnoser.isSolved($0, in: state)
        }
        let orientedUpEdges = [1, 3, 5, 7].count { state.facelets[$0] == .up }
        let orientedUpCorners = [0, 2, 6, 8].count { state.facelets[$0] == .up }

        switch goal {
        case .cross:
            return [solvedDownEdges]
        case .firstLayer:
            return [
                CubePracticeDiagnoser.isDownCrossComplete(state) ? 1 : 0,
                solvedDownCorners,
            ]
        case .f2l:
            return [
                CubePracticeDiagnoser.isFirstLayerComplete(state) ? 1 : 0,
                solvedMiddleEdges,
            ]
        case .ollEdges:
            return [
                CubePracticeDiagnoser.isF2LComplete(state) ? 1 : 0,
                orientedUpEdges,
            ]
        case .ollCorners:
            return [
                CubePracticeDiagnoser.isF2LComplete(state) ? 1 : 0,
                CubePracticeDiagnoser.isUpCrossOriented(state) ? 1 : 0,
                orientedUpCorners,
            ]
        case .pllCorners:
            return [
                CubePracticeDiagnoser.isF2LComplete(state) ? 1 : 0,
                CubePracticeDiagnoser.isUpFaceOriented(state) ? 1 : 0,
                bestUpCornerPermutationMatch(in: state),
            ]
        case .pllEdges:
            return [
                CubePracticeDiagnoser.isF2LComplete(state) ? 1 : 0,
                CubePracticeDiagnoser.isUpFaceOriented(state) ? 1 : 0,
                CubePracticeDiagnoser.areUpCornersPermutedModuloAUF(state) ? 1 : 0,
                bestUpLayerPermutationMatch(in: state),
            ]
        case .auf:
            return [
                isAchieved(.pllEdges, in: state) ? 1 : 0,
                zip(state.facelets, CubeState.solved.facelets).count { $0.0 == $0.1 },
            ]
        }
    }

    static func bestUpCornerPermutationMatch(in state: CubeState) -> Int {
        (0..<4).map { offset in
            CubePracticeDiagnoser.upCorners.enumerated().count { index, position in
                state.cubies.cornerPermutation[position.rawValue]
                    == CubePracticeDiagnoser.upCorners[(index + offset) % 4]
            }
        }.max() ?? 0
    }

    static func bestUpLayerPermutationMatch(in state: CubeState) -> Int {
        (0..<4).map { offset in
            let corners = CubePracticeDiagnoser.upCorners.enumerated().count { index, position in
                state.cubies.cornerPermutation[position.rawValue]
                    == CubePracticeDiagnoser.upCorners[(index + offset) % 4]
            }
            let edges = CubePracticeDiagnoser.upEdges.enumerated().count { index, position in
                state.cubies.edgePermutation[position.rawValue]
                    == CubePracticeDiagnoser.upEdges[(index + offset) % 4]
            }
            return corners + edges
        }.max() ?? 0
    }
}
