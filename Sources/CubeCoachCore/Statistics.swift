import Foundation

public struct SolveRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let rawDuration: TimeInterval
    public let penalty: SolvePenalty
    public let scramble: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), rawDuration: TimeInterval, penalty: SolvePenalty = .none, scramble: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.rawDuration = max(0, rawDuration)
        self.penalty = penalty
        self.scramble = scramble
    }

    public init(id: UUID = UUID(), timestamp: Date = Date(), timing: SolveTiming, scramble: String? = nil) {
        self.init(id: id, timestamp: timestamp, rawDuration: timing.rawDuration, penalty: timing.penalty, scramble: scramble)
    }

    public var finalDuration: TimeInterval? {
        switch penalty {
        case .none: rawDuration
        case .plusTwo: rawDuration + 2
        case .dnf: nil
        }
    }

    public var officialCentiseconds: Int? {
        guard penalty != .dnf else { return nil }
        return Int((rawDuration * 100).rounded(.down)) + (penalty == .plusTwo ? 200 : 0)
    }
}

public struct SolveStatistics: Codable, Sendable, Equatable {
    public let records: [SolveRecord]

    public init(records: [SolveRecord]) { self.records = records }

    public var validSolveCount: Int {
        records.lazy.filter { $0.officialCentiseconds != nil }.count
    }

    public var dnfCount: Int {
        records.count - validSolveCount
    }

    /// Fraction of recorded attempts that have a valid result, in the closed range 0...1.
    /// An empty session has a completion rate of zero.
    public var completionRate: Double {
        guard !records.isEmpty else { return 0 }
        return Double(validSolveCount) / Double(records.count)
    }

    public var personalBest: SolveRecord? {
        records.filter { $0.officialCentiseconds != nil }.min {
            ($0.officialCentiseconds ?? .max, $0.timestamp) < ($1.officialCentiseconds ?? .max, $1.timestamp)
        }
    }

    /// Arithmetic mean of all valid results in the session. DNFs are excluded rather
    /// than treated as zero or as an arbitrarily slow solve. Each input is first
    /// truncated to an official centisecond, then the mean is rounded to the nearest
    /// centisecond (half up).
    public var sessionAverageCentiseconds: Int? {
        roundedMeanCentiseconds(of: records.compactMap(\.officialCentiseconds))
    }

    public var sessionAverage: TimeInterval? {
        sessionAverageCentiseconds.map { Double($0) / 100 }
    }

    /// Session mean in seconds. This is the UI-facing alias for `sessionAverage`.
    public var sessionMean: TimeInterval? {
        sessionAverage
    }

    public var ao5: TimeInterval? { averageOfLast(5) }
    public var ao12: TimeInterval? { averageOfLast(12) }
    public var bestAo5: TimeInterval? { bestAverage(of: 5) }
    public var bestAo12: TimeInterval? { bestAverage(of: 12) }

    /// WCA average: discard exactly one best and one worst result. A DNF is worst;
    /// two or more DNFs make the average DNF (`nil`). Returned seconds use centisecond inputs.
    public func averageOfLast(_ count: Int) -> TimeInterval? {
        guard count >= 3, records.count >= count else { return nil }
        let values = chronologicalRecords.suffix(count).map(\.officialCentiseconds)
        return wcaAverageCentiseconds(of: values).map { Double($0) / 100 }
    }

    /// Best valid WCA average across every consecutive chronological window.
    /// A window with two or more DNFs is ignored; a window with one DNF remains valid
    /// because that DNF is discarded as the worst result.
    public func bestAverage(of count: Int) -> TimeInterval? {
        guard count >= 3, records.count >= count else { return nil }
        let chronological = chronologicalRecords
        var bestCentiseconds: Int?

        for start in 0...(chronological.count - count) {
            let values = chronological[start..<(start + count)].map(\.officialCentiseconds)
            guard let average = wcaAverageCentiseconds(of: values) else { continue }
            bestCentiseconds = min(bestCentiseconds ?? average, average)
        }

        return bestCentiseconds.map { Double($0) / 100 }
    }

    /// Population standard deviation of the most recent `count` valid solves.
    ///
    /// DNFs are skipped before choosing the recent window. Every duration is first
    /// truncated to centiseconds; the population variance divides by `count` (not
    /// `count - 1`). The returned value is in seconds and is not rounded after the
    /// square root, preserving the precision of a centisecond-input calculation.
    public func standardDeviationOfRecentValid(_ count: Int) -> TimeInterval? {
        guard count > 0 else { return nil }
        let values = chronologicalRecords.compactMap(\.officialCentiseconds)
        guard values.count >= count else { return nil }
        let recent = values.suffix(count).map(Double.init)
        let mean = recent.reduce(0, +) / Double(count)
        let variance = recent.reduce(0) { sum, value in
            let difference = value - mean
            return sum + difference * difference
        } / Double(count)
        return variance.squareRoot() / 100
    }

    /// Population standard deviation in seconds for the most recent valid solves.
    public func standardDeviationOfRecent(_ count: Int) -> TimeInterval? {
        standardDeviationOfRecentValid(count)
    }

    private var chronologicalRecords: [SolveRecord] {
        records.sorted { $0.timestamp < $1.timestamp }
    }

    private func roundedMeanCentiseconds(of values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return (values.reduce(0, +) + values.count / 2) / values.count
    }

    private func wcaAverageCentiseconds(of values: [Int?]) -> Int? {
        guard values.filter({ $0 == nil }).count <= 1 else { return nil }

        var sortable = values.map { $0 ?? Int.max }
        sortable.sort()
        sortable.removeFirst()
        sortable.removeLast()
        guard sortable.allSatisfy({ $0 != Int.max }) else { return nil }
        return roundedMeanCentiseconds(of: sortable)
    }
}
