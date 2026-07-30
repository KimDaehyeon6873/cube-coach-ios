import Foundation

public enum CurriculumTrack: String, Codable, Sendable, Equatable, CaseIterable {
    case beginner
    case twoLookCFOP
    case fullCFOP
    case advancedLastLayer
    case rouxCMLL
}

public struct LearningSource: Codable, Sendable, Equatable, Hashable {
    public let title: String
    public let publisher: String
    public let url: String
    public let note: String?
    public let licenseName: String?
    public let licenseURL: String?

    public init(
        title: String,
        publisher: String,
        url: String,
        note: String? = nil,
        licenseName: String? = nil,
        licenseURL: String? = nil
    ) {
        self.title = title
        self.publisher = publisher
        self.url = url
        self.note = note
        self.licenseName = licenseName
        self.licenseURL = licenseURL
    }
}

public struct AlgorithmSample: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let notation: String
    public let recognitionHint: String
    public let alternativeNotations: [String]
    /// Nil only when this item is explanatory rather than a trainer case.
    public let exercise: LearningExerciseSpec?

    public init(
        id: String,
        name: String,
        notation: String,
        recognitionHint: String,
        alternativeNotations: [String] = [],
        exercise: LearningExerciseSpec? = nil
    ) {
        self.id = id
        self.name = name
        self.notation = notation
        self.recognitionHint = recognitionHint
        self.alternativeNotations = alternativeNotations
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
    static func executableSample(
        id: String,
        name: String,
        notation: String,
        recognitionHint: String,
        setup: String,
        chunks: [Int],
        alternativeNotations: [String] = []
    ) -> AlgorithmSample {
        AlgorithmSample(
            id: id,
            name: name,
            notation: notation,
            recognitionHint: recognitionHint,
            alternativeNotations: alternativeNotations,
            exercise: LearningExerciseSpec(
                setupNotation: setup,
                solutionNotation: notation,
                chunkBoundaries: chunks
            )
        )
    }

    private static let beginnerSource = LearningSource(
        title: "Official 3×3 Solution Guide",
        publisher: "Rubik's",
        url: "https://www.rubiks.com/solution-guides",
        note: "단계 구조만 참고. 문장·이미지는 복제하지 않고 앱 설명과 전개도를 독립 제작",
        licenseName: "Reference only — reuse license not granted",
        licenseURL: "https://www.rubiks.com/terms-conditions"
    )
    static let notationSource = LearningSource(
        title: "WCA Regulations, Article 12: Notation",
        publisher: "World Cube Association",
        url: "https://www.worldcubeassociation.org/regulations/full/#article-12-notation",
        note: "회전 표기 기준"
    )
    public static let beginner = Curriculum(track: .beginner, title: "레이어 해법 기초", lessons: [
        CurriculumLesson(id: "beginner-cross", title: "흰색 십자", objective: "센터와 엣지의 상대 색을 맞추며 십자를 만든다.", algorithms: [], sources: [beginnerSource]),
        CurriculumLesson(id: "beginner-corners", title: "첫 층 코너", objective: "목표 코너를 반복 삽입하고 손동작을 암기한다.", algorithms: [
            executableSample(id: "right-trigger", name: "오른손 트리거", notation: "R U R' U'", recognitionHint: "오른쪽 앞 슬롯에 넣어요.", setup: "U R U' R'", chunks: [0, 2, 4]),
            executableSample(id: "left-trigger", name: "왼손 트리거", notation: "L' U' L U", recognitionHint: "왼쪽 앞 슬롯에 넣어요.", setup: "U' L' U L", chunks: [0, 2, 4])
        ], sources: [beginnerSource, notationSource]),
        CurriculumLesson(id: "beginner-second-layer", title: "두 번째 층", objective: "윗면의 비노랑 엣지를 좌우 슬롯에 삽입한다.", algorithms: [
            executableSample(id: "middle-right", name: "오른쪽 삽입", notation: "U R U' R' U' F' U F", recognitionHint: "옆 색이 오른쪽 센터를 향해요.", setup: "F' U' F U R U R' U'", chunks: [0, 4, 8]),
            executableSample(id: "middle-left", name: "왼쪽 삽입", notation: "U' L' U L U F U' F'", recognitionHint: "옆 색이 왼쪽 센터를 향해요.", setup: "F U F' U' L' U' L U", chunks: [0, 4, 8])
        ], sources: [beginnerSource]),
        CurriculumLesson(id: "beginner-last-layer", title: "노란 면 만들기", objective: "노란 십자와 코너 방향을 차례로 맞춰요.", algorithms: [
            executableSample(id: "yellow-cross", name: "노란 십자", notation: "F R U R' U' F'", recognitionHint: "선은 가로, ㄴ은 왼쪽 위.", setup: "F U R U' R' F'", chunks: [0, 3, 6]),
            executableSample(id: "sune", name: "노란 코너 방향", notation: "R U R' U R U2 R'", recognitionHint: "맞는 코너 하나를 왼쪽 앞에 둬요.", setup: "R U2 R' U' R U' R'", chunks: [0, 3, 7])
        ], sources: [beginnerSource, openAlgorithmSource]),
        CurriculumLesson(id: "beginner-last-layer-position", title: "마지막 층 위치 맞추기", objective: "코너와 엣지의 자리를 맞춰 큐브를 완성해요.", algorithms: [
            executableSample(
                id: "beginner-corner-position",
                name: "노란 코너 자리 맞추기",
                notation: "U R U' L' U R' U' L",
                recognitionHint: "제자리에 있는 코너를 오른쪽 앞에 둬요.",
                setup: "L' U R U' L U R' U'",
                chunks: [0, 4, 8]
            ),
            executableSample(
                id: "beginner-corner-twist",
                name: "코너 한 번 비틀기",
                notation: "R' D' R D",
                recognitionHint: "맞출 코너를 오른쪽 앞 위에 둬요.",
                setup: "D' R' D R",
                chunks: [0, 2, 4]
            ),
            executableSample(
                id: "beginner-edge-clockwise",
                name: "마지막 엣지 시계 순환",
                notation: "R U' R U R U R U' R' U' R2",
                recognitionHint: "완성된 옆면 바를 뒤에 둬요.",
                setup: "R2 U R U R' U' R' U' R' U R'",
                chunks: [0, 5, 11]
            ),
            executableSample(
                id: "beginner-edge-counterclockwise",
                name: "마지막 엣지 반시계 순환",
                notation: "R2 U R U R' U' R' U' R' U R'",
                recognitionHint: "완성된 옆면 바를 뒤에 둬요.",
                setup: "R U' R U R U R U' R' U' R2",
                chunks: [0, 5, 11]
            ),
        ], sources: [beginnerSource, openAlgorithmSource])
    ])

    public static let twoLookCFOP = makeTwoLookCFOP()

    public static let builtIn: [Curriculum] = [
        beginner,
        twoLookCFOP,
        fullCFOP,
        advancedLastLayer,
        rouxCMLL,
    ]
}
