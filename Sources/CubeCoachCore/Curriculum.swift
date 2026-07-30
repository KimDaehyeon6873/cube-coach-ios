import Foundation

public enum CurriculumTrack: String, Codable, Sendable, Equatable, CaseIterable {
    case beginner
    case twoLookCFOP
}

public struct LearningSource: Codable, Sendable, Equatable, Hashable {
    public let title: String
    public let publisher: String
    public let url: String
    public let note: String?

    public init(title: String, publisher: String, url: String, note: String? = nil) {
        self.title = title
        self.publisher = publisher
        self.url = url
        self.note = note
    }
}

public struct AlgorithmSample: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let notation: String
    public let recognitionHint: String
    /// Nil only when this item is explanatory rather than a trainer case.
    public let exercise: LearningExerciseSpec?

    public init(
        id: String,
        name: String,
        notation: String,
        recognitionHint: String,
        exercise: LearningExerciseSpec? = nil
    ) {
        self.id = id
        self.name = name
        self.notation = notation
        self.recognitionHint = recognitionHint
        self.exercise = exercise
    }
}

public struct CurriculumLesson: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let objective: String
    public let algorithms: [AlgorithmSample]
    public let sources: [LearningSource]

    public init(id: String, title: String, objective: String, algorithms: [AlgorithmSample], sources: [LearningSource]) {
        self.id = id
        self.title = title
        self.objective = objective
        self.algorithms = algorithms
        self.sources = sources
    }
}

public struct Curriculum: Identifiable, Codable, Sendable, Equatable {
    public var id: CurriculumTrack { track }
    public let track: CurriculumTrack
    public let title: String
    public let lessons: [CurriculumLesson]

    public init(track: CurriculumTrack, title: String, lessons: [CurriculumLesson]) {
        self.track = track
        self.title = title
        self.lessons = lessons
    }
}

public enum CurriculumCatalog {
    private static func executableSample(
        id: String,
        name: String,
        notation: String,
        recognitionHint: String,
        setup: String,
        chunks: [Int]
    ) -> AlgorithmSample {
        AlgorithmSample(
            id: id,
            name: name,
            notation: notation,
            recognitionHint: recognitionHint,
            exercise: LearningExerciseSpec(
                setupNotation: setup,
                solutionNotation: notation,
                chunkBoundaries: chunks
            )
        )
    }

    private static let beginnerSource = LearningSource(
        title: "3x3 Beginner's Method",
        publisher: "CubeSkills",
        url: "https://www.cubeskills.com/tutorials/the-beginners-method-for-solving-the-rubiks-cube",
        note: "단계 구성과 초급 해법 참고"
    )
    private static let notationSource = LearningSource(
        title: "WCA Regulations, Article 12: Notation",
        publisher: "World Cube Association",
        url: "https://www.worldcubeassociation.org/regulations/full/#article-12-notation",
        note: "회전 표기 기준"
    )
    private static let ollSource = LearningSource(
        title: "2-Look OLL",
        publisher: "J Perm",
        url: "https://jperm.net/algs/2lookoll",
        note: "2-Look OLL 사례와 알고리즘 참고"
    )
    private static let pllSource = LearningSource(
        title: "2-Look PLL",
        publisher: "J Perm",
        url: "https://jperm.net/algs/2lookpll",
        note: "2-Look PLL 사례와 알고리즘 참고"
    )

    public static let beginner = Curriculum(track: .beginner, title: "레이어 해법 기초", lessons: [
        CurriculumLesson(id: "beginner-cross", title: "흰색 십자", objective: "센터와 엣지의 상대 색을 맞추며 십자를 만든다.", algorithms: [], sources: [beginnerSource]),
        CurriculumLesson(id: "beginner-corners", title: "첫 층 코너", objective: "목표 코너를 반복 삽입하고 손동작을 암기한다.", algorithms: [
            executableSample(id: "right-trigger", name: "오른손 트리거", notation: "R U R' U'", recognitionHint: "삽입 슬롯을 오른쪽 앞에 둔다.", setup: "U R U' R'", chunks: [0, 2, 4]),
            executableSample(id: "left-trigger", name: "왼손 트리거", notation: "L' U' L U", recognitionHint: "삽입 슬롯을 왼쪽 앞에 둔다.", setup: "U' L' U L", chunks: [0, 2, 4])
        ], sources: [beginnerSource, notationSource]),
        CurriculumLesson(id: "beginner-second-layer", title: "두 번째 층", objective: "윗면의 비노랑 엣지를 좌우 슬롯에 삽입한다.", algorithms: [
            executableSample(id: "middle-right", name: "오른쪽 삽입", notation: "U R U' R' U' F' U F", recognitionHint: "엣지의 옆 색이 오른쪽 센터를 향한다.", setup: "F' U' F U R U R' U'", chunks: [0, 4, 8]),
            executableSample(id: "middle-left", name: "왼쪽 삽입", notation: "U' L' U L U F U' F'", recognitionHint: "엣지의 옆 색이 왼쪽 센터를 향한다.", setup: "F U F' U' L' U' L U", chunks: [0, 4, 8])
        ], sources: [beginnerSource]),
        CurriculumLesson(id: "beginner-last-layer", title: "마지막 층 입문", objective: "마지막 층의 십자와 대표 코너 방향 공식을 연습한다.", algorithms: [
            executableSample(id: "yellow-cross", name: "노란 십자", notation: "F R U R' U' F'", recognitionHint: "선은 가로, ㄴ 모양은 왼쪽 위로 둔다.", setup: "F U R U' R' F'", chunks: [0, 3, 6]),
            executableSample(id: "sune", name: "Sune", notation: "R U R' U R U2 R'", recognitionHint: "방향이 맞는 코너 하나를 왼쪽 앞에 둔다.", setup: "R U2 R' U' R U' R'", chunks: [0, 3, 7])
        ], sources: [beginnerSource])
    ])

    public static let twoLookCFOP = Curriculum(track: .twoLookCFOP, title: "2-Look CFOP 시작", lessons: [
        CurriculumLesson(id: "cfop-f2l-foundation", title: "Cross + 직관 F2L 기초", objective: "십자를 계획하고 코너-엣지 쌍을 슬롯에 삽입한다.", algorithms: [
            executableSample(id: "f2l-basic", name: "기본 분리·삽입", notation: "U R U' R'", recognitionHint: "쌍을 만든 뒤 오른쪽 슬롯에 넣는다.", setup: "R U R' U'", chunks: [0, 2, 4])
        ], sources: [beginnerSource]),
        CurriculumLesson(id: "two-look-oll-edges", title: "OLL 1단계: 엣지 방향", objective: "점·ㄴ·선 패턴을 노란 십자로 바꾼다.", algorithms: [
            executableSample(id: "oll-line", name: "선", notation: "F R U R' U' F'", recognitionHint: "노란 선을 가로로 둔다.", setup: "F U R U' R' F'", chunks: [0, 3, 6]),
            executableSample(id: "oll-l", name: "ㄴ 모양", notation: "F U R U' R' F'", recognitionHint: "노란 ㄴ을 왼쪽 위에 둔다.", setup: "F R U R' U' F'", chunks: [0, 3, 6])
        ], sources: [ollSource]),
        CurriculumLesson(id: "two-look-oll-corners", title: "OLL 2단계: 코너 방향 입문", objective: "대표 코너 패턴을 인식해 윗면 방향 맞추기를 연습한다.", algorithms: [
            executableSample(id: "oll-sune", name: "Sune", notation: "R U R' U R U2 R'", recognitionHint: "윗색 코너 하나가 왼쪽 앞.", setup: "R U2 R' U' R U' R'", chunks: [0, 3, 7]),
            executableSample(id: "oll-antisune", name: "Anti-Sune", notation: "R U2 R' U' R U' R'", recognitionHint: "윗색 코너 하나가 오른쪽 뒤.", setup: "R U R' U R U2 R'", chunks: [0, 3, 7]),
            executableSample(id: "oll-headlights", name: "Headlights", notation: "R2 D R' U2 R D' R' U2 R'", recognitionHint: "같은 방향 코너 두 개를 뒤로 둔다.", setup: "R U2 R D R' U2 R D' R2", chunks: [0, 4, 9])
        ], sources: [ollSource]),
        CurriculumLesson(id: "two-look-pll-corners", title: "PLL 1단계: 코너 순열", objective: "코너의 위치를 먼저 맞춘다.", algorithms: [
            executableSample(id: "pll-a", name: "A 순열", notation: "x R' U R' D2 R U' R' D2 R2 x'", recognitionHint: "맞는 코너 블록을 기준으로 둔다.", setup: "x R2 D2 R U R' D2 R U' R x'", chunks: [0, 1, 5, 10, 11])
        ], sources: [pllSource]),
        CurriculumLesson(id: "two-look-pll-edges", title: "PLL 2단계: 엣지 순열", objective: "마지막 엣지를 순환시켜 완성한다.", algorithms: [
            executableSample(id: "pll-ua", name: "Ua 순열", notation: "R U' R U R U R U' R' U' R2", recognitionHint: "완성된 바를 뒤에 둔다. 앞 엣지가 오른쪽으로 가는 순환이다.", setup: "R2 U R U R' U' R' U' R' U R'", chunks: [0, 5, 11]),
            executableSample(id: "pll-ub", name: "Ub 순열", notation: "R2 U R U R' U' R' U' R' U R'", recognitionHint: "완성된 바를 뒤에 둔다. 앞 엣지가 왼쪽으로 가는 순환이다.", setup: "R U' R U R U R U' R' U' R2", chunks: [0, 5, 11])
        ], sources: [pllSource]),
        CurriculumLesson(
            id: "cfop-auf",
            title: "마지막 U면 정렬(AUF)",
            objective: "PLL 뒤 옆면 색을 센터에 맞추는 마지막 윗면 정렬을 확인한다.",
            algorithms: [],
            sources: [notationSource]
        )
    ])

    public static let builtIn: [Curriculum] = [beginner, twoLookCFOP]
}
