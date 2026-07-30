import Testing
@testable import CubeCoachCore

@Test func inspectionPenaltyBoundaries() {
    #expect(InspectionPenalty.at(elapsed: 14.9999) == .none)
    #expect(InspectionPenalty.at(elapsed: 15) == .plusTwo)
    #expect(InspectionPenalty.at(elapsed: 15.0001) == .plusTwo)
    #expect(InspectionPenalty.at(elapsed: 16.9999) == .plusTwo)
    #expect(InspectionPenalty.at(elapsed: 17) == .dnf)
    #expect(InspectionPenalty.at(elapsed: 17.0001) == .dnf)
}

@Test func timerTransitionsThroughHoldingArmedRunningStopped() throws {
    var timer = SolveTimerMachine.inspection(startedAt: 0, armDuration: 0.5)
    try timer.press(at: 10)
    #expect(timer.phase.kind == .holding)
    try timer.advance(to: 10.5)
    #expect(timer.phase.kind == .armed)
    try timer.release(at: 16)
    #expect(timer.phase.kind == .running)
    try timer.stop(at: 26)
    guard case let .stopped(result) = timer.phase else {
        Issue.record("not stopped")
        return
    }
    #expect(result.rawDuration == 10)
    #expect(result.penalty == .plusTwo)
    #expect(result.finalDuration == 12)
}

@Test func prematureReleaseReturnsToInspection() throws {
    var timer = SolveTimerMachine.inspection(startedAt: 0)
    try timer.press(at: 1)
    try timer.release(at: 1.1)
    #expect(timer.phase.kind == .inspection)
}

@Test func officialTimeTruncatesRatherThanRounds() {
    let result = SolveTiming(rawDuration: 9.999, inspectionElapsed: 0, penalty: .none)
    #expect(result.officialCentiseconds == 999)
    #expect(result.officialDisplay == "9.99")
}
