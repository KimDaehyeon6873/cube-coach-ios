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

public struct CubePracticeDiagnosis: Codable, Sendable, Equatable {
    public let stage: CubePracticeStage
    public let title: String
    public let practiceGoal: String
    public let recommendedCurriculumTrack: CurriculumTrack
    public let recommendedLessonID: String

    public var isSolved: Bool { stage == .complete }

    public init(
        stage: CubePracticeStage,
        title: String,
        practiceGoal: String,
        recommendedCurriculumTrack: CurriculumTrack,
        recommendedLessonID: String
    ) {
        self.stage = stage
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
                recommendedCurriculumTrack: .twoLookCFOP,
                recommendedLessonID: "cfop-f2l-foundation"
            )
        }

        if isSolvedAfterAUF(state) {
            return CubePracticeDiagnosis(
                stage: .aufRequired,
                title: "마지막 U면 정렬(AUF)",
                practiceGoal: "마지막 층을 윗면 회전으로 정렬해 옆면 센터 색에 맞추세요.",
                recommendedCurriculumTrack: .twoLookCFOP,
                recommendedLessonID: "cfop-auf"
            )
        }

        guard isDownCrossComplete(state) else {
            return CubePracticeDiagnosis(
                stage: .downCrossIncomplete,
                title: "D면 십자 연습",
                practiceGoal: "D면 엣지 네 개를 각 옆면 센터 색까지 맞춰 십자를 완성하세요.",
                recommendedCurriculumTrack: .beginner,
                recommendedLessonID: "beginner-cross"
            )
        }

        guard isFirstLayerComplete(state) else {
            return CubePracticeDiagnosis(
                stage: .downCrossComplete,
                title: "첫 층 코너 연습",
                practiceGoal: "완성한 십자를 유지하면서 D면 코너 네 개를 올바른 슬롯에 넣으세요.",
                recommendedCurriculumTrack: .beginner,
                recommendedLessonID: "beginner-corners"
            )
        }

        guard isF2LComplete(state) else {
            return CubePracticeDiagnosis(
                stage: .firstLayerComplete,
                title: "두 번째 층 연습",
                practiceGoal: "첫 층을 보존하며 중간층 엣지를 센터 색에 맞는 슬롯에 삽입하세요.",
                recommendedCurriculumTrack: .beginner,
                recommendedLessonID: "beginner-second-layer"
            )
        }

        guard isUpCrossOriented(state) else {
            return CubePracticeDiagnosis(
                stage: .f2lComplete,
                title: "OLL 엣지 방향 연습",
                practiceGoal: "F2L을 유지하면서 U면 엣지를 먼저 맞춰 십자를 만드세요.",
                recommendedCurriculumTrack: .twoLookCFOP,
                recommendedLessonID: "two-look-oll-edges"
            )
        }

        guard isUpFaceOriented(state) else {
            return CubePracticeDiagnosis(
                stage: .f2lComplete,
                title: "OLL 코너 방향 연습",
                practiceGoal: "U면 십자를 유지하면서 네 코너의 방향을 맞추세요.",
                recommendedCurriculumTrack: .twoLookCFOP,
                recommendedLessonID: "two-look-oll-corners"
            )
        }

        guard areUpCornersPermutedModuloAUF(state) else {
            return CubePracticeDiagnosis(
                stage: .ollComplete,
                title: "PLL 코너 순열 연습",
                practiceGoal: "완성된 U면 방향을 유지하면서 마지막 층 코너의 위치를 먼저 맞추세요.",
                recommendedCurriculumTrack: .twoLookCFOP,
                recommendedLessonID: "two-look-pll-corners"
            )
        }

        return CubePracticeDiagnosis(
            stage: .ollComplete,
            title: "PLL 엣지 순열 연습",
            practiceGoal: "맞춰진 코너를 유지하면서 마지막 층 엣지를 순환시켜 완성하세요.",
            recommendedCurriculumTrack: .twoLookCFOP,
            recommendedLessonID: "two-look-pll-edges"
        )
    }
}

public extension CubeState {
    var practiceDiagnosis: CubePracticeDiagnosis {
        CubePracticeDiagnoser.diagnose(self)
    }
}

private extension CubePracticeDiagnoser {
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
