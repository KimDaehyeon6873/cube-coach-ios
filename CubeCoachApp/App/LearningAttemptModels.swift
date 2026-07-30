import CubeCoachCore
import Foundation

enum LearningHintLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case h0
    case h1
    case h2
    case h3
    case h4
    case h5

    static func < (lhs: LearningHintLevel, rhs: LearningHintLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum RecognitionOutcome: String, Codable, Sendable {
    case correct
    case corrected
    case notAssessed
}

enum ExecutionOutcome: String, Codable, Sendable {
    case matched
    case didNotMatch
    case unsure
}

enum OutcomeEvidence: String, Codable, Sendable {
    case manualComparison
    case validatedScan

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case Self.manualComparison.rawValue, "selfCompared":
            self = .manualComparison
        case Self.validatedScan.rawValue, "scanVerified":
            self = .validatedScan
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown outcome evidence: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum PreparationMethod: String, Codable, Sendable {
    case externallyPrepared
    case guidedAcquisition
}

enum PracticeMode: String, Codable, Sendable {
    case learning
    case review
    case practice
    case scanRecommendation

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case Self.learning.rawValue:
            self = .learning
        case Self.review.rawValue:
            self = .review
        case Self.practice.rawValue:
            self = .practice
        case Self.scanRecommendation.rawValue, "scannedCase":
            self = .scanRecommendation
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown practice mode: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ReviewAttempt: Codable, Equatable, Sendable {
    let caseID: String
    /// Completion time. Scheduling is always based on this timestamp.
    let timestamp: Date
    /// Optional for backward compatibility with attempts saved before timing
    /// evidence was split into start and completion.
    let startedAt: Date?
    /// Optional so legacy JSON without preparation evidence remains decodable.
    /// A missing value cannot prove independent preparation.
    let preparation: PreparationMethod?
    let maxHint: LearningHintLevel
    let playbackUsed: Bool
    let recognition: RecognitionOutcome
    let execution: ExecutionOutcome
    let evidence: OutcomeEvidence
    let mode: PracticeMode
    let contentVersion: String

    init(
        caseID: String,
        timestamp: Date = .now,
        startedAt: Date? = nil,
        preparation: PreparationMethod? = nil,
        maxHint: LearningHintLevel = .h0,
        playbackUsed: Bool = false,
        recognition: RecognitionOutcome = .notAssessed,
        execution: ExecutionOutcome,
        evidence: OutcomeEvidence = .manualComparison,
        mode: PracticeMode = .review,
        contentVersion: String = "1"
    ) {
        self.caseID = caseID
        self.timestamp = timestamp
        self.startedAt = startedAt
        self.preparation = preparation
        self.maxHint = maxHint
        self.playbackUsed = playbackUsed
        self.recognition = recognition
        self.execution = execution
        self.evidence = evidence
        self.mode = mode
        self.contentVersion = contentVersion
    }

    var wasAssisted: Bool {
        preparation != .externallyPrepared ||
            maxHint > .h0 ||
            playbackUsed ||
            recognition == .corrected
    }

    var schedulerRating: ReviewRating {
        switch execution {
        case .didNotMatch, .unsure:
            .again
        case .matched where wasAssisted:
            .hard
        case .matched:
            .good
        }
    }
}

struct ReviewAttemptSummary: Equatable, Sendable {
    let total: Int
    let independent: Int
    let assisted: Int
    let matched: Int
    let didNotMatch: Int
    let unsure: Int

    static let empty = ReviewAttemptSummary(
        total: 0,
        independent: 0,
        assisted: 0,
        matched: 0,
        didNotMatch: 0,
        unsure: 0
    )

    init(attempts: some Sequence<ReviewAttempt>) {
        var total = 0
        var independent = 0
        var assisted = 0
        var matched = 0
        var didNotMatch = 0
        var unsure = 0

        for attempt in attempts {
            total += 1
            if attempt.wasAssisted {
                assisted += 1
            } else {
                independent += 1
            }
            switch attempt.execution {
            case .matched: matched += 1
            case .didNotMatch: didNotMatch += 1
            case .unsure: unsure += 1
            }
        }

        self.total = total
        self.independent = independent
        self.assisted = assisted
        self.matched = matched
        self.didNotMatch = didNotMatch
        self.unsure = unsure
    }

    private init(
        total: Int,
        independent: Int,
        assisted: Int,
        matched: Int,
        didNotMatch: Int,
        unsure: Int
    ) {
        self.total = total
        self.independent = independent
        self.assisted = assisted
        self.matched = matched
        self.didNotMatch = didNotMatch
        self.unsure = unsure
    }
}
