import CubeCoachCore
import Foundation

public enum TimerPracticeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case free
    case wcaPractice

    public var id: Self { self }

    var title: String {
        switch self {
        case .free: "자유 연습"
        case .wcaPractice: "15초 인스펙션"
        }
    }
}

public enum TimerSolvePenalty: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case plusTwo
    case dnf

    public var id: Self { self }

    var title: String {
        switch self {
        case .none: "페널티 없음"
        case .plusTwo: "+2"
        case .dnf: "DNF"
        }
    }
}

public struct TimerSolveRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let rawSeconds: Double
    public let penalty: TimerSolvePenalty
    public let scramble: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        rawSeconds: Double,
        penalty: TimerSolvePenalty = .none,
        scramble: String
    ) {
        self.id = id
        self.date = date
        self.rawSeconds = rawSeconds
        self.penalty = penalty
        self.scramble = scramble
    }

    public var adjustedSeconds: Double? {
        switch penalty {
        case .none: rawSeconds
        case .plusTwo: rawSeconds + 2
        case .dnf: nil
        }
    }

    public var displayText: String {
        switch penalty {
        case .none:
            TimerTextFormatter.solveTime(rawSeconds)
        case .plusTwo:
            "\(TimerTextFormatter.solveTime(rawSeconds + 2)) +2"
        case .dnf:
            "DNF (\(TimerTextFormatter.solveTime(rawSeconds)))"
        }
    }

    func applying(_ newPenalty: TimerSolvePenalty) -> TimerSolveRecord {
        TimerSolveRecord(
            id: id,
            date: date,
            rawSeconds: rawSeconds,
            penalty: newPenalty,
            scramble: scramble
        )
    }
}

enum TimerTextFormatter {
    static func solveTime(_ seconds: Double) -> String {
        let safeSeconds = max(0, seconds)
        let totalCentiseconds = Int((safeSeconds * 100).rounded(.down))
        let minutes = totalCentiseconds / 6_000
        let remainingSeconds = (totalCentiseconds % 6_000) / 100
        let centiseconds = totalCentiseconds % 100

        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, remainingSeconds, centiseconds)
        }
        return String(format: "%d.%02d", remainingSeconds, centiseconds)
    }

    static func inspection(_ seconds: Double) -> String {
        String(max(0, Int(ceil(seconds))))
    }

    static func average(_ seconds: Double) -> String {
        let centiseconds = Int((max(0, seconds) * 100).rounded())
        let minutes = centiseconds / 6_000
        let remainingSeconds = (centiseconds % 6_000) / 100
        let remainder = centiseconds % 100
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, remainingSeconds, remainder)
        }
        return String(format: "%d.%02d", remainingSeconds, remainder)
    }
}

enum TimerSolveStatistics {
    static func average(of count: Int, in records: [TimerSolveRecord]) -> String? {
        guard records.count >= count else { return nil }
        let coreRecords = records.map {
            CubeCoachCore.SolveRecord(
                id: $0.id,
                timestamp: $0.date,
                rawDuration: $0.rawSeconds,
                penalty: $0.penalty.coreValue,
                scramble: $0.scramble
            )
        }
        guard let average = CubeCoachCore.SolveStatistics(records: coreRecords).averageOfLast(count) else {
            return "DNF"
        }
        return TimerTextFormatter.average(average)
    }
}

private extension TimerSolvePenalty {
    var coreValue: CubeCoachCore.SolvePenalty {
        switch self {
        case .none: .none
        case .plusTwo: .plusTwo
        case .dnf: .dnf
        }
    }
}
