import CubeCoachCore
import Foundation

/// 실행 가능한 Core 연습을 학습 화면에 연결하는 UI 어댑터입니다.
struct StudyCaseUI: Identifiable, Equatable {
    enum CatalogValidationError: Error, Equatable, CustomStringConvertible {
        case duplicateCaseID(String)
        case invalidExercise(caseID: String, reason: String)
        case algorithmDoesNotMatchExercise(caseID: String)

        var description: String {
            switch self {
            case let .duplicateCaseID(caseID):
                "Duplicate built-in study case ID: \(caseID)"
            case let .invalidExercise(caseID, reason):
                "Invalid built-in exercise \(caseID): \(reason)"
            case let .algorithmDoesNotMatchExercise(caseID):
                "Displayed algorithm does not match compiled exercise: \(caseID)"
            }
        }
    }

    let id: String
    let title: String
    let recognition: String
    let answerTitle: String
    let algorithm: String
    let hint: String
    let level: String
    let family: String
    let alternativeAlgorithms: [String]
    let sources: [LearningSource]
    let recognitionChoices: [String]
    let exercise: CompiledLearningExercise?

    /// Stable version of the authored drill fields that affect recognition and
    /// execution. This intentionally avoids Swift's randomized `Hasher`.
    var contentVersion: String {
        let setup = exercise?.spec.setupNotation ?? ""
        let chunks = exercise?.chunks.map(\.normalized).joined(separator: "\u{1F}") ?? ""
        let fields = [id, recognition, algorithm, setup, chunks]

        var hash: UInt64 = 0xcbf29ce484222325
        for field in fields {
            let length = UInt64(field.utf8.count)
            for shift in stride(from: 0, through: 56, by: 8) {
                hash ^= UInt64(UInt8(truncatingIfNeeded: length >> UInt64(shift)))
                hash &*= 0x100000001b3
            }
            for byte in field.utf8 {
                hash ^= UInt64(byte)
                hash &*= 0x100000001b3
            }
        }
        return "fnv1a64-" + String(hash, radix: 16).leftPadded(to: 16, with: "0")
    }

    init(
        id: String,
        title: String,
        recognition: String,
        answerTitle: String,
        algorithm: String,
        hint: String,
        level: String,
        family: String,
        alternativeAlgorithms: [String] = [],
        sources: [LearningSource] = [],
        recognitionChoices: [String] = [],
        exercise: CompiledLearningExercise? = nil
    ) {
        self.id = id
        self.title = title
        self.recognition = recognition
        self.answerTitle = answerTitle
        self.algorithm = algorithm
        self.hint = hint
        self.level = level
        self.family = family
        self.alternativeAlgorithms = alternativeAlgorithms
        self.sources = sources
        self.recognitionChoices = recognitionChoices
        self.exercise = exercise
    }

    static let coreCatalog: [StudyCaseUI] = {
        do {
            return try validatedCoreCatalog(from: CurriculumCatalog.builtIn)
        } catch {
            preconditionFailure("Built-in curriculum validation failed: \(error)")
        }
    }()

    static func validatedCoreCatalog(from curricula: [Curriculum]) throws -> [StudyCaseUI] {
        var executable: [StudyCaseUI] = []
        var seenCaseIDs = Set<String>()

        for curriculum in curricula {
            for lesson in curriculum.lessons {
                for sample in lesson.algorithms {
                    guard let exercise = sample.exercise else {
                        // Explanatory/theory samples are intentionally not trainer cases.
                        continue
                    }
                    guard seenCaseIDs.insert(sample.id).inserted else {
                        throw CatalogValidationError.duplicateCaseID(sample.id)
                    }

                    let compiled: CompiledLearningExercise
                    do {
                        compiled = try exercise.compile()
                    } catch {
                        throw CatalogValidationError.invalidExercise(
                            caseID: sample.id,
                            reason: String(describing: error)
                        )
                    }
                    let displayedAlgorithm: CubeAlgorithm
                    do {
                        displayedAlgorithm = try WCAParser.parse(sample.notation)
                    } catch {
                        throw CatalogValidationError.invalidExercise(
                            caseID: sample.id,
                            reason: "Invalid displayed notation: \(error)"
                        )
                    }
                    guard displayedAlgorithm == compiled.solution else {
                        throw CatalogValidationError.algorithmDoesNotMatchExercise(
                            caseID: sample.id
                        )
                    }
                    do {
                        _ = try sample.alternativeNotations.map(WCAParser.parse)
                    } catch {
                        throw CatalogValidationError.invalidExercise(
                            caseID: sample.id,
                            reason: "Invalid alternative notation: \(error)"
                        )
                    }

                    executable.append(.init(
                        id: sample.id,
                        title: sample.name,
                        recognition: sample.recognitionHint,
                        answerTitle: "공식",
                        algorithm: sample.notation,
                        hint: lesson.objective,
                        level: curriculum.title,
                        family: lesson.title,
                        alternativeAlgorithms: sample.alternativeNotations,
                        sources: lesson.sources,
                        exercise: compiled
                    ))
                }
            }
        }

        return executable.map { item in
            let comparable = executable
                .filter { $0.id != item.id && $0.family == item.family }
                + executable.filter {
                    $0.id != item.id && $0.family != item.family && $0.level == item.level
                }
            var seenTitles = Set([item.title])
            let distractors = comparable.compactMap { candidate -> String? in
                seenTitles.insert(candidate.title).inserted ? candidate.title : nil
            }.prefix(2)
            return .init(
                id: item.id,
                title: item.title,
                recognition: item.recognition,
                answerTitle: item.answerTitle,
                algorithm: item.algorithm,
                hint: item.hint,
                level: item.level,
                family: item.family,
                alternativeAlgorithms: item.alternativeAlgorithms,
                sources: item.sources,
                recognitionChoices: ([item.title] + distractors).sorted(),
                exercise: item.exercise
            )
        }
    }
}

private extension String {
    func leftPadded(to length: Int, with character: Character) -> String {
        guard count < length else { return self }
        return String(repeating: String(character), count: length - count) + self
    }
}

/// Core 커리큘럼을 로드맵 표현에 맞게 요약하는 UI 어댑터입니다.
struct RoadmapStageUI: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let caseIDs: [String]

    static let all: [RoadmapStageUI] = CurriculumCatalog.builtIn.map { curriculum in
        let executableIDs = Set(StudyCaseUI.coreCatalog.map(\.id))
        let ids = curriculum.lessons.flatMap { lesson in
            lesson.algorithms
                .filter { executableIDs.contains($0.id) }
                .map(\.id)
        }
        let subtitle: String = switch curriculum.track {
        case .beginner: "조각의 이동 원리와 기본 트리거"
        case .twoLookCFOP: "OLL 9개 · PLL 6개로 단계 전환"
        case .fullCFOP: "F2L 41 · OLL 57 · PLL 21"
        case .advancedLastLayer: "COLL로 코너 방향과 순열을 함께 해결"
        case .rouxCMLL: "Roux 두 블록을 유지하는 CMLL 42"
        }
        return RoadmapStageUI(id: curriculum.track.rawValue, title: curriculum.title, subtitle: subtitle, caseIDs: ids)
    }
}
