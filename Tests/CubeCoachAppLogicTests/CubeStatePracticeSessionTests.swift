import Foundation
import Testing
@testable import CubeCoachAppLogic
@testable import CubeCoachCore

private final class PracticeTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Duration = .zero

    func now() -> Duration { lock.withLock { value } }
    func advance(seconds: Double) {
        lock.withLock { value += .seconds(seconds) }
    }
}

private func practiceScan(
    notation: String = "R",
    id: UUID = UUID(),
    reviewedAt: Date = Date(timeIntervalSince1970: 100)
) throws -> ValidatedCubeScan {
    let state = try CubeState.solved.applying(WCAParser.parse(notation))
    return ValidatedCubeScan(
        id: id,
        state: state,
        reviewedAt: reviewedAt
    )
}

private func solvedScan() -> ValidatedCubeScan {
    ValidatedCubeScan(state: .solved)
}

@MainActor
@Test func validatedScanDefaultsAndInitialMetadataArePreserved() throws {
    let scan = try practiceScan()
    let model = try CubeStatePracticeSessionModel(initialScan: scan)

    #expect(scan.orientation == .identity)
    #expect(model.initialScan == scan)
    #expect(model.resultScan == nil)
    #expect(model.phase == .briefing)
    #expect(model.highestHintIndex == nil)
    #expect(model.recommendedCurriculumTrack == scan.diagnosis.recommendedCurriculumTrack)
    #expect(model.recommendedLessonID == scan.diagnosis.recommendedLessonID)
}

@MainActor
@Test func initialScanMustHaveAnActionableDerivedGoal() throws {
    #expect(throws: CubeStatePracticeSessionError.solvedInitialScan) {
        try CubeStatePracticeSessionModel(initialScan: solvedScan())
    }

    let state = try CubeState.solved.applying(WCAParser.parse("R"))
    let scan = ValidatedCubeScan(state: state)
    #expect(scan.diagnosis == state.practiceDiagnosis)
    #expect(scan.diagnosis.goalID != nil)
    _ = try CubeStatePracticeSessionModel(initialScan: scan)
}

@MainActor
@Test func elapsedAccumulatesOnlyAcrossRunningIntervals() throws {
    let clock = PracticeTestClock()
    let model = try CubeStatePracticeSessionModel(
        initialScan: practiceScan(),
        clock: TimerMonotonicClock(read: clock.now)
    )

    #expect(model.elapsed() == 0)
    #expect(model.start())
    clock.advance(seconds: 2.25)
    #expect(model.elapsed() == 2.25)
    #expect(model.stop(reason: .interrupted))
    clock.advance(seconds: 10)
    #expect(model.elapsed() == 2.25)
    #expect(model.resume())
    clock.advance(seconds: 1.75)
    #expect(model.stop(reason: .completed))
    #expect(model.elapsed() == 4)
}

@MainActor
@Test func hintsRevealMonotonicallyOnlyDuringPausedReview() throws {
    let model = try CubeStatePracticeSessionModel(initialScan: practiceScan())

    #expect(model.revealNextHint(maximumCount: 3) == nil)
    #expect(model.start())
    #expect(model.revealNextHint(maximumCount: 3) == nil)
    #expect(model.stop(reason: .completed))
    #expect(model.revealNextHint(maximumCount: 3) == 0)
    #expect(model.revealNextHint(maximumCount: 3) == 1)
    #expect(model.revealNextHint(maximumCount: 1) == nil)
    #expect(model.highestHintIndex == 1)
    #expect(model.revealNextHint(maximumCount: 3) == 2)
    #expect(model.revealNextHint(maximumCount: 3) == nil)
    #expect(model.markStuck())
    #expect(model.phase == .awaitingResultScan(reason: .stuck))
    #expect(model.revealNextHint(maximumCount: 4) == 3)
    #expect(model.highestHintIndex == 3)
}

@MainActor
@Test func cancelResultScanPreservesAttemptStateAndRejectsStaleCallbacks() throws {
    let clock = PracticeTestClock()
    let model = try CubeStatePracticeSessionModel(
        initialScan: practiceScan(),
        clock: TimerMonotonicClock(read: clock.now)
    )
    #expect(model.start())
    clock.advance(seconds: 5)
    #expect(model.stop(reason: .stuck))
    #expect(model.revealNextHint(maximumCount: 2) == 0)

    let request = try #require(model.beginResultScan())
    #expect(model.beginResultScan() == nil)
    #expect(!model.cancelResultScan(requestID: UUID()))
    #expect(!model.acceptResultScan(solvedScan(), requestID: UUID()))
    let differentlyOriented = ValidatedCubeScan(
        state: .solved,
        orientation: try #require(CubeOrientation.all.first { $0 != .identity })
    )
    #expect(!model.acceptResultScan(differentlyOriented, requestID: request))
    #expect(model.cancelResultScan(requestID: request))
    #expect(model.phase == .awaitingResultScan(reason: .stuck))
    #expect(model.elapsed() == 5)
    #expect(model.highestHintIndex == 0)
    #expect(!model.cancelResultScan(requestID: request))
    #expect(!model.acceptResultScan(solvedScan(), requestID: request))
}

@MainActor
@Test func acceptedResultUsesOriginalGoalAndIsIdempotent() throws {
    let initial = try practiceScan(notation: "R")
    let model = try CubeStatePracticeSessionModel(initialScan: initial)
    #expect(model.start())
    #expect(model.stop(reason: .completed))
    let request = try #require(model.beginResultScan())
    let result = solvedScan()

    #expect(model.acceptResultScan(result, requestID: request))
    #expect(model.resultScan == result)
    let comparison = CubePracticeGoalEvaluator.compare(
        start: initial.state,
        result: result.state,
        goal: try #require(initial.diagnosis.goalID)
    )
    #expect(model.phase == .result(comparison: comparison))
    #expect(!model.acceptResultScan(result, requestID: request))
    #expect(!model.start())
    #expect(!model.resume())
    #expect(!model.continueFromResult())
}

@MainActor
@Test func continuingCreatesFreshSessionAndInvalidatesOldRequest() throws {
    let initial = try practiceScan(notation: "R")
    let next = try practiceScan(notation: "F")
    let model = try CubeStatePracticeSessionModel(initialScan: initial)
    let oldSessionID = model.sessionID

    #expect(model.start())
    #expect(model.stop(reason: .completed))
    #expect(model.revealNextHint(maximumCount: 1) == 0)
    let request = try #require(model.beginResultScan())
    #expect(model.acceptResultScan(next, requestID: request))
    #expect(model.continueFromResult())

    #expect(model.sessionID != oldSessionID)
    #expect(model.initialScan == next)
    #expect(model.resultScan == nil)
    #expect(model.phase == .briefing)
    #expect(model.elapsed() == 0)
    #expect(model.highestHintIndex == nil)
    #expect(model.recommendedLessonID == next.diagnosis.recommendedLessonID)
    #expect(!model.cancelResultScan(requestID: request))
    #expect(!model.acceptResultScan(solvedScan(), requestID: request))
}

@MainActor
@Test func invalidTransitionsAreNoOpsAndAbandonFreezesTime() throws {
    let clock = PracticeTestClock()
    let model = try CubeStatePracticeSessionModel(
        initialScan: practiceScan(),
        clock: TimerMonotonicClock(read: clock.now)
    )

    #expect(!model.stop(reason: .stuck))
    #expect(!model.resume())
    #expect(model.beginResultScan() == nil)
    #expect(model.start())
    #expect(!model.start())
    clock.advance(seconds: 3)
    model.abandon()
    #expect(model.phase == .abandoned)
    #expect(model.elapsed() == 3)
    clock.advance(seconds: 20)
    #expect(model.elapsed() == 3)
    model.abandon()
    #expect(!model.start())
    #expect(!model.stop(reason: .completed))
    #expect(!model.resume())
}
