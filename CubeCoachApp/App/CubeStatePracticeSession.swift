import Combine
import CubeCoachCore
import Foundation

/// One reviewed, legal cube scan in the canonical Core coordinate system.
public struct ValidatedCubeScan: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let state: CubeState
    public let orientation: CubeOrientation
    public let reviewedAt: Date
    public var diagnosis: CubePracticeDiagnosis { state.practiceDiagnosis }

    public init(
        id: UUID = UUID(),
        state: CubeState,
        orientation: CubeOrientation = .identity,
        reviewedAt: Date = Date()
    ) {
        self.id = id
        self.state = state
        self.orientation = orientation
        self.reviewedAt = reviewedAt
    }
}

public enum CubeStatePracticeSessionError: Error, Equatable, Sendable {
    case solvedInitialScan
    case missingPracticeGoal
}

/// Coordinates a scan-backed physical practice attempt without generating a
/// scramble, solving moves, or a timer solve record.
@MainActor
public final class CubeStatePracticeSessionModel: ObservableObject {
    public enum StopReason: Equatable, Sendable {
        case completed
        case stuck
        case interrupted
    }

    public enum Phase: Equatable, Sendable {
        case briefing
        case running
        case awaitingResultScan(reason: StopReason)
        case scanningResult(requestID: UUID)
        case result(comparison: CubePracticeComparison)
        case abandoned
    }

    @Published public private(set) var initialScan: ValidatedCubeScan
    @Published public private(set) var resultScan: ValidatedCubeScan?
    @Published public private(set) var phase: Phase = .briefing
    @Published public private(set) var highestHintIndex: Int?
    @Published public private(set) var recommendedCurriculumTrack: CurriculumTrack
    @Published public private(set) var recommendedLessonID: String

    /// Changes whenever `continueFromResult()` begins a logically new attempt.
    public private(set) var sessionID = UUID()

    private let clock: TimerMonotonicClock
    private var accumulatedActiveDuration: Duration = .zero
    private var activeStartedAt: Duration?
    private var pendingScanSessionID: UUID?
    private var reasonBeforeScanning: StopReason?

    public init(
        initialScan: ValidatedCubeScan,
        clock: TimerMonotonicClock = .continuous
    ) throws {
        guard !initialScan.diagnosis.isSolved else {
            throw CubeStatePracticeSessionError.solvedInitialScan
        }
        guard initialScan.diagnosis.goalID != nil else {
            throw CubeStatePracticeSessionError.missingPracticeGoal
        }

        self.initialScan = initialScan
        recommendedCurriculumTrack = initialScan.diagnosis.recommendedCurriculumTrack
        recommendedLessonID = initialScan.diagnosis.recommendedLessonID
        self.clock = clock
    }

    /// Cumulative active practice time. Paused scanning and review time is not
    /// included, and the value never decreases.
    public func elapsed() -> Double {
        var duration = accumulatedActiveDuration
        if let activeStartedAt {
            duration += max(.zero, clock.now() - activeStartedAt)
        }
        return Self.seconds(duration)
    }

    @discardableResult
    public func start() -> Bool {
        guard phase == .briefing else { return false }
        activeStartedAt = clock.now()
        phase = .running
        return true
    }

    @discardableResult
    public func stop(reason: StopReason) -> Bool {
        guard phase == .running else { return false }
        pauseActiveTime()
        phase = .awaitingResultScan(reason: reason)
        return true
    }

    @discardableResult
    public func resume() -> Bool {
        guard case .awaitingResultScan = phase else { return false }
        activeStartedAt = clock.now()
        phase = .running
        return true
    }

    @discardableResult
    public func markStuck() -> Bool {
        guard case .awaitingResultScan = phase else { return false }
        phase = .awaitingResultScan(reason: .stuck)
        return true
    }

    /// Reveals hints in order. The returned zero-based index is suitable for
    /// directly indexing a lesson's hint array.
    @discardableResult
    public func revealNextHint(maximumCount: Int) -> Int? {
        guard case .awaitingResultScan = phase, maximumCount > 0 else {
            return nil
        }
        let next = (highestHintIndex ?? -1) + 1
        guard next < maximumCount else { return nil }
        highestHintIndex = next
        return next
    }

    /// Starts a result scan and returns the request identity that every scan
    /// callback must present.
    @discardableResult
    public func beginResultScan() -> UUID? {
        guard case let .awaitingResultScan(reason) = phase else { return nil }
        let requestID = UUID()
        reasonBeforeScanning = reason
        pendingScanSessionID = sessionID
        phase = .scanningResult(requestID: requestID)
        return requestID
    }

    @discardableResult
    public func cancelResultScan(requestID: UUID) -> Bool {
        guard case .scanningResult(requestID: requestID) = phase,
              pendingScanSessionID == sessionID,
              let reasonBeforeScanning
        else { return false }

        clearPendingScan()
        phase = .awaitingResultScan(reason: reasonBeforeScanning)
        return true
    }

    @discardableResult
    public func acceptResultScan(
        _ scan: ValidatedCubeScan,
        requestID: UUID
    ) -> Bool {
        guard case .scanningResult(requestID: requestID) = phase,
              pendingScanSessionID == sessionID,
              scan.orientation == initialScan.orientation,
              let goal = initialScan.diagnosis.goalID
        else { return false }

        let comparison = CubePracticeGoalEvaluator.compare(
            start: initialScan.state,
            result: scan.state,
            goal: goal
        )
        resultScan = scan
        clearPendingScan()
        phase = .result(comparison: comparison)
        return true
    }

    /// Uses the reviewed result as a new physical starting point. Completed or
    /// otherwise non-actionable diagnoses intentionally cannot start a session.
    @discardableResult
    public func continueFromResult() -> Bool {
        guard case .result = phase,
              let resultScan,
              !resultScan.diagnosis.isSolved,
              resultScan.diagnosis.goalID != nil
        else { return false }

        initialScan = resultScan
        self.resultScan = nil
        recommendedCurriculumTrack = resultScan.diagnosis.recommendedCurriculumTrack
        recommendedLessonID = resultScan.diagnosis.recommendedLessonID
        sessionID = UUID()
        accumulatedActiveDuration = .zero
        activeStartedAt = nil
        highestHintIndex = nil
        clearPendingScan()
        phase = .briefing
        return true
    }

    public func abandon() {
        guard phase != .abandoned else { return }
        if phase == .running {
            pauseActiveTime()
        }
        clearPendingScan()
        phase = .abandoned
    }

    private func pauseActiveTime() {
        guard let activeStartedAt else { return }
        accumulatedActiveDuration += max(.zero, clock.now() - activeStartedAt)
        self.activeStartedAt = nil
    }

    private func clearPendingScan() {
        pendingScanSessionID = nil
        reasonBeforeScanning = nil
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
