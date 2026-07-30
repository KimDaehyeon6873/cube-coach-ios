import Foundation

struct TrainerAttemptState: Equatable, Sendable {
    enum Phase: Int, Codable, CaseIterable, Sendable {
        case prepare
        case recognize
        case recall
        case playback
        case execute
        case compare
        case result
    }

    let caseID: String
    let timestamp: Date
    let mode: PracticeMode
    let contentVersion: String

    private(set) var phase: Phase = .prepare
    private(set) var preparation: PreparationMethod?
    private(set) var maxHint: LearningHintLevel = .h0
    private(set) var playbackUsed = false
    private(set) var recognition: RecognitionOutcome = .notAssessed
    private(set) var execution: ExecutionOutcome?
    private(set) var evidence: OutcomeEvidence?

    var wasAssisted: Bool {
        preparation != .externallyPrepared ||
            maxHint > .h0 ||
            playbackUsed ||
            recognition == .corrected
    }

    init(
        caseID: String,
        timestamp: Date = .now,
        mode: PracticeMode = .review,
        contentVersion: String = "1"
    ) {
        self.caseID = caseID
        self.timestamp = timestamp
        self.mode = mode
        self.contentVersion = contentVersion
    }

    /// Advances exactly one phase. Supplying the expected phase makes stale UI
    /// callbacks harmless instead of allowing them to advance a newer attempt.
    @discardableResult
    mutating func advance(from expectedPhase: Phase) -> Bool {
        guard phase == expectedPhase,
              phase != .result,
              expectedPhase != .prepare || preparation != nil,
              let next = Phase(rawValue: phase.rawValue + 1)
        else {
            return false
        }
        phase = next
        return true
    }

    /// Preparation is immutable evidence and must be captured before leaving
    /// `.prepare`. Guided setup playback is assistance, but it does not reveal
    /// the recall stepper or raise the hint level.
    @discardableResult
    mutating func recordPreparation(_ method: PreparationMethod) -> Bool {
        guard phase == .prepare, preparation == nil else { return false }
        preparation = method
        if method == .guidedAcquisition {
            playbackUsed = true
        }
        return true
    }

    /// Records only a higher hint level, so hint assistance can never be erased.
    @discardableResult
    mutating func revealHint(_ level: LearningHintLevel) -> Bool {
        guard phase == .recall, level > maxHint else { return false }
        maxHint = level
        return true
    }

    @discardableResult
    mutating func recordRecognition(
        _ outcome: RecognitionOutcome,
        from expectedPhase: Phase = .recognize
    ) -> Bool {
        guard phase == expectedPhase, expectedPhase == .recognize else { return false }
        recognition = outcome
        return advance(from: expectedPhase)
    }

    @discardableResult
    mutating func recordPlaybackUsed(from expectedPhase: Phase = .recall) -> Bool {
        guard phase == expectedPhase,
              expectedPhase == .recall,
              !playbackUsed
        else {
            return false
        }
        playbackUsed = true
        return true
    }

    @discardableResult
    mutating func recordExecution(
        _ outcome: ExecutionOutcome,
        from expectedPhase: Phase = .execute
    ) -> Bool {
        guard phase == expectedPhase, expectedPhase == .execute else { return false }
        execution = outcome
        return advance(from: expectedPhase)
    }

    /// Completes the attempt once. A duplicate or stale completion returns nil.
    mutating func complete(
        evidence completionEvidence: OutcomeEvidence,
        completedAt: Date = .now,
        from expectedPhase: Phase = .compare
    ) -> ReviewAttempt? {
        guard phase == expectedPhase,
              expectedPhase == .compare,
              let execution
        else {
            return nil
        }
        evidence = completionEvidence
        phase = .result
        return ReviewAttempt(
            caseID: caseID,
            timestamp: completedAt,
            startedAt: timestamp,
            preparation: preparation,
            maxHint: maxHint,
            playbackUsed: playbackUsed,
            recognition: recognition,
            execution: execution,
            evidence: completionEvidence,
            mode: mode,
            contentVersion: contentVersion
        )
    }
}
