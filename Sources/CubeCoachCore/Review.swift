import Foundation

public enum ReviewRating: String, Codable, Sendable, Equatable, CaseIterable {
    case again = "Again"
    case hard = "Hard"
    case good = "Good"
    case easy = "Easy"
}

public struct ReviewState: Codable, Sendable, Equatable {
    public let repetitions: Int
    public let intervalDays: Int
    public let easeFactor: Double
    public let dueAt: Date
    public let lastReviewedAt: Date?

    public init(repetitions: Int, intervalDays: Int, easeFactor: Double, dueAt: Date, lastReviewedAt: Date? = nil) {
        self.repetitions = max(0, repetitions)
        self.intervalDays = max(0, intervalDays)
        self.easeFactor = max(1.3, easeFactor)
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
    }

    public static func new(dueAt: Date = Date()) -> ReviewState {
        ReviewState(repetitions: 0, intervalDays: 0, easeFactor: 2.5, dueAt: dueAt)
    }
}

public enum ReviewScheduler {
    private static let day: TimeInterval = 86_400

    /// A deterministic SM-2-inspired scheduler. The same state, rating and timestamp always produce the same result.
    public static func schedule(_ state: ReviewState, rating: ReviewRating, reviewedAt: Date) -> ReviewState {
        let repetitions: Int
        let interval: Int
        let ease: Double
        let dueAt: Date

        switch rating {
        case .again:
            repetitions = 0
            interval = 0
            ease = max(1.3, state.easeFactor - 0.2)
            dueAt = reviewedAt.addingTimeInterval(10 * 60)
        case .hard:
            repetitions = state.repetitions + 1
            interval = state.intervalDays == 0 ? 1 : max(1, Int((Double(state.intervalDays) * 1.2).rounded(.down)))
            ease = max(1.3, state.easeFactor - 0.15)
            dueAt = reviewedAt.addingTimeInterval(Double(interval) * day)
        case .good:
            repetitions = state.repetitions + 1
            if state.repetitions == 0 { interval = 1 }
            else if state.repetitions == 1 { interval = 3 }
            else { interval = max(1, Int((Double(state.intervalDays) * state.easeFactor).rounded())) }
            ease = state.easeFactor
            dueAt = reviewedAt.addingTimeInterval(Double(interval) * day)
        case .easy:
            repetitions = state.repetitions + 1
            interval = state.repetitions == 0 ? 4 : max(4, Int((Double(max(1, state.intervalDays)) * state.easeFactor * 1.3).rounded()))
            ease = state.easeFactor + 0.15
            dueAt = reviewedAt.addingTimeInterval(Double(interval) * day)
        }
        return ReviewState(repetitions: repetitions, intervalDays: interval, easeFactor: ease, dueAt: dueAt, lastReviewedAt: reviewedAt)
    }
}
