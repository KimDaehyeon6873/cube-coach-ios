import Foundation
import Testing
@testable import CubeCoachCore

private func record(_ seconds: Double, penalty: SolvePenalty = .none) -> SolveRecord {
    SolveRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: seconds), rawDuration: seconds, penalty: penalty)
}

private func record(at timestamp: Double, duration: Double, penalty: SolvePenalty = .none) -> SolveRecord {
    SolveRecord(
        id: UUID(),
        timestamp: Date(timeIntervalSince1970: timestamp),
        rawDuration: duration,
        penalty: penalty
    )
}

@Test func computesPbAndWcaAverages() {
    let records = [10.0, 11, 12, 13, 30].map { record($0) }
    let stats = SolveStatistics(records: records)
    #expect(stats.personalBest?.finalDuration == 10)
    #expect(stats.ao5 == 12)
    #expect(stats.ao12 == nil)
}

@Test func averagesHandleDnfAsWorstAndTwoDnfsAsDnf() {
    let oneDNF = [record(10), record(11), record(12), record(13), record(14, penalty: .dnf)]
    #expect(SolveStatistics(records: oneDNF).ao5 == 12)
    let twoDNF = [record(10), record(11), record(12), record(13, penalty: .dnf), record(14, penalty: .dnf)]
    #expect(SolveStatistics(records: twoDNF).ao5 == nil)
}

@Test func latestAverageUsesTimestampsNotArrayInsertionOrder() {
    let records = [record(15), record(3), record(14), record(13), record(12), record(11), record(10)]
    // Chronologically latest five are 11...15, whose trimmed mean is 13.
    #expect(SolveStatistics(records: records).ao5 == 13)
}

@Test func plusTwoAndAverageUseTruncatedCentiseconds() {
    let penalized = record(9.999, penalty: .plusTwo)
    #expect(penalized.officialCentiseconds == 1_199)
    #expect(penalized.finalDuration == 11.999)

    let records = [record(10.001), record(10.011), record(10.021), record(10.031), record(10.041)]
    #expect(SolveStatistics(records: records).ao5 == 10.02)
}

@Test func sessionCountsCompletionRateAndEmptyBoundaries() {
    let empty = SolveStatistics(records: [])
    #expect(empty.validSolveCount == 0)
    #expect(empty.dnfCount == 0)
    #expect(empty.completionRate == 0)
    #expect(empty.sessionAverage == nil)
    #expect(empty.sessionAverageCentiseconds == nil)

    let stats = SolveStatistics(records: [
        record(10),
        record(11, penalty: .plusTwo),
        record(12, penalty: .dnf),
        record(13, penalty: .dnf),
    ])
    #expect(stats.validSolveCount == 2)
    #expect(stats.dnfCount == 2)
    #expect(stats.completionRate == 0.5)
}

@Test func sessionAverageExcludesDnfsAndUsesCentisecondInputs() {
    let stats = SolveStatistics(records: [
        record(at: 1, duration: 10.019),
        record(at: 2, duration: 10.029),
        record(at: 3, duration: 1, penalty: .dnf),
        record(at: 4, duration: 8.039, penalty: .plusTwo),
    ])

    // Official inputs are 1001, 1002, and 1003 centiseconds. Their mean is 1002.
    #expect(stats.sessionAverageCentiseconds == 1_002)
    #expect(stats.sessionAverage == 10.02)
    #expect(stats.sessionMean == 10.02)
}

@Test func bestAveragesSearchEveryChronologicalWindow() {
    let records = [
        record(at: 12, duration: 50),
        record(at: 1, duration: 10),
        record(at: 11, duration: 40),
        record(at: 2, duration: 11),
        record(at: 10, duration: 30),
        record(at: 3, duration: 12),
        record(at: 9, duration: 20),
        record(at: 4, duration: 13),
        record(at: 8, duration: 19),
        record(at: 5, duration: 14),
        record(at: 7, duration: 18),
        record(at: 6, duration: 17),
    ]
    let stats = SolveStatistics(records: records)

    #expect(stats.bestAo5 == 12)
    #expect(stats.bestAo12 == 19.4)
    #expect(stats.ao5 == 30)
    #expect(stats.ao12 == 19.4)
}

@Test func bestAverageAppliesDnfRulesToEachWindow() {
    let records = [
        record(at: 1, duration: 10, penalty: .dnf),
        record(at: 2, duration: 11, penalty: .dnf),
        record(at: 3, duration: 12),
        record(at: 4, duration: 13),
        record(at: 5, duration: 14),
        record(at: 6, duration: 15),
    ]
    let stats = SolveStatistics(records: records)

    // First window has two DNFs and is invalid; the second has one, trimmed as worst.
    #expect(stats.bestAo5 == 14)
    #expect(stats.ao5 == 14)
    #expect(stats.bestAverage(of: 2) == nil)
    #expect(stats.bestAverage(of: 7) == nil)
}

@Test func bestAo12CanComeFromAnEarlierWindow() {
    var records: [SolveRecord] = []
    for index in 1...13 {
        let duration = index == 13 ? 100.0 : Double(index + 9)
        records.append(record(at: Double(index), duration: duration))
    }
    let stats = SolveStatistics(records: records)

    #expect(stats.bestAo12 == 15.5)
    #expect(stats.ao12 == 16.5)
}

@Test func bestAverageReturnsNilWhenEveryWindowIsDnf() {
    let records = [
        record(at: 1, duration: 10),
        record(at: 2, duration: 11, penalty: .dnf),
        record(at: 3, duration: 12, penalty: .dnf),
        record(at: 4, duration: 13),
        record(at: 5, duration: 14),
        record(at: 6, duration: 15, penalty: .dnf),
    ]
    #expect(SolveStatistics(records: records).bestAo5 == nil)
}

@Test func recentValidStandardDeviationSkipsDnfsAndUsesTimestampOrder() {
    let records = [
        record(at: 4, duration: 14.009),
        record(at: 1, duration: 100),
        record(at: 5, duration: 99, penalty: .dnf),
        record(at: 3, duration: 12.009),
        record(at: 2, duration: 10.009),
    ]
    let stats = SolveStatistics(records: records)

    // Recent valid centisecond values are 1000, 1200, 1400. Population SD = sqrt(80000/3) cs.
    #expect(abs((stats.standardDeviationOfRecentValid(3) ?? 0) - 1.632_993_161_855_452) < 0.000_000_001)
    #expect(abs((stats.standardDeviationOfRecent(3) ?? 0) - 1.632_993_161_855_452) < 0.000_000_001)
    #expect(stats.standardDeviationOfRecentValid(1) == 0)
    #expect(stats.standardDeviationOfRecentValid(0) == nil)
    #expect(stats.standardDeviationOfRecentValid(5) == nil)
}
