import CubeCoachCore
import Foundation
import SwiftUI

private enum TimerScramblePreparationError: Error {
    case unsupportedMove
}

public struct TimerMonotonicClock: Sendable {
    private let read: @Sendable () -> Duration

    public init(read: @escaping @Sendable () -> Duration) {
        self.read = read
    }

    public func now() -> Duration { read() }

    public static let continuous: TimerMonotonicClock = {
        let clock = ContinuousClock()
        let origin = clock.now
        return TimerMonotonicClock { origin.duration(to: clock.now) }
    }()
}

@MainActor
public final class TimerFeatureModel: ObservableObject {
    public struct ScramblePresentation: Equatable, Sendable {
        public let notation: String
        public let cubeState: CubeState

        public init(notation: String, cubeState: CubeState) {
            self.notation = notation
            self.cubeState = cubeState
        }
    }

    public enum ScrambleCatalogState: Equatable, Sendable {
        case loading
        case ready
        case failed
    }

    public enum Phase: Equatable, Sendable {
        case idle
        case holding
        case armed
        case inspection
        case inspectionHolding
        case inspectionArmed
        case running
        case stopped
    }

    @Published public var mode: TimerPracticeMode = .free {
        didSet {
            guard oldValue != mode else { return }
            resetAttempt(makeNewScramble: true)
        }
    }
    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var scramblePresentation: ScramblePresentation?
    @Published public private(set) var records: [TimerSolveRecord]
    @Published public private(set) var lastPenalty: TimerSolvePenalty = .none
    @Published public private(set) var interruptionMessage: String?
    @Published public private(set) var scrambleCatalogState: ScrambleCatalogState = .loading

    private let clock: TimerMonotonicClock
    private let catalogLoader: TimerScrambleCatalogLoader
    private let scrambleSeed: UInt64
    private var scrambleGenerator: TimerScrambleGenerator?
    private var catalogLoadTask: Task<Void, Never>?
    private var holdTask: Task<Void, Never>?
    private var inspectionStart: Duration?
    private var solveStart: Duration?

    public convenience init(
        clock: TimerMonotonicClock = .continuous,
        initialRecords: [TimerSolveRecord] = []
    ) {
        self.init(
            clock: clock,
            initialRecords: initialRecords,
            catalogLoader: .bundled,
            scrambleSeed: UInt64.random(in: UInt64.min...UInt64.max)
        )
    }

    init(
        clock: TimerMonotonicClock,
        initialRecords: [TimerSolveRecord],
        catalogLoader: TimerScrambleCatalogLoader,
        scrambleSeed: UInt64
    ) {
        self.clock = clock
        self.records = initialRecords
        self.catalogLoader = catalogLoader
        self.scrambleSeed = scrambleSeed
        self.scramblePresentation = nil
        loadScrambleCatalog()
    }

    deinit {
        holdTask?.cancel()
        catalogLoadTask?.cancel()
    }

    public var ao5: String? { TimerSolveStatistics.average(of: 5, in: records) }
    public var ao12: String? { TimerSolveStatistics.average(of: 12, in: records) }
    public var scramble: String { scramblePresentation?.notation ?? "" }
    public var scrambledCubeState: CubeState? { scramblePresentation?.cubeState }
    public var isScrambleReady: Bool {
        scrambleCatalogState == .ready
            && scramblePresentation != nil
    }

    public func waitForScrambleCatalog() async {
        await catalogLoadTask?.value
    }

    public func retryScrambleCatalogLoad() {
        guard scrambleCatalogState == .failed else { return }
        loadScrambleCatalog()
    }

    public func makeNewScramble() {
        guard isScrambleReady, phase == .idle || phase == .stopped else { return }
        resetAttempt(makeNewScramble: true)
    }

    public func startInspection() {
        guard isScrambleReady,
              mode == .wcaPractice,
              phase == .idle || phase == .stopped
        else { return }
        if phase == .stopped {
            resetAttempt(makeNewScramble: false)
        }
        inspectionStart = clock.now()
        solveStart = nil
        lastPenalty = .none
        phase = .inspection
    }

    public func pressBegan() {
        guard isScrambleReady else { return }
        if phase == .running {
            stopSolve()
            return
        }

        switch phase {
        case .idle where mode == .free:
            beginHold(inspection: false)
        case .inspection:
            beginHold(inspection: true)
        case .stopped:
            resetAttempt(makeNewScramble: false)
            if mode == .free { beginHold(inspection: false) }
        default:
            break
        }
    }

    public func pressEnded() {
        guard isScrambleReady else { return }
        holdTask?.cancel()
        holdTask = nil

        switch phase {
        case .armed:
            beginSolve(penalty: .none)
        case .inspectionArmed:
            beginSolve(penalty: currentInspectionPenalty(at: clock.now()))
        case .holding:
            phase = .idle
        case .inspectionHolding:
            phase = .inspection
        default:
            break
        }
    }

    public func elapsed(at now: Duration? = nil) -> Double {
        guard phase == .running, let solveStart else {
            if phase == .stopped, let latest = records.first { return latest.rawSeconds }
            return 0
        }
        return seconds(from: solveStart, to: now ?? clock.now())
    }

    public func inspectionElapsed(at now: Duration? = nil) -> Double {
        guard let inspectionStart else { return 0 }
        return seconds(from: inspectionStart, to: now ?? clock.now())
    }

    public func inspectionRemaining(at now: Duration? = nil) -> Double {
        15 - inspectionElapsed(at: now)
    }

    public func inspectionPenalty(at now: Duration? = nil) -> TimerSolvePenalty {
        currentInspectionPenalty(at: now ?? clock.now())
    }

    public func resetAttempt(makeNewScramble: Bool = true) {
        holdTask?.cancel()
        holdTask = nil
        inspectionStart = nil
        solveStart = nil
        lastPenalty = .none
        phase = .idle
        if makeNewScramble, let scrambleGenerator {
            do {
                try setNextScramble(using: scrambleGenerator)
            } catch {
                failScramblePreparation()
            }
        }
    }

    /// Stops an active solve exactly once.
    ///
    /// The view exposes this action across the whole screen only while the
    /// timer is running. The phase guard also makes repeated touch events safe.
    public func stopRunningSolve() {
        stopSolve()
    }

    public func deleteRecord(id: UUID) {
        records.removeAll { $0.id == id }
    }

    /// Applies the durable store's newest-first record snapshot.
    ///
    /// Keeping this replacement idempotent prevents the app-level two-way
    /// synchronization from publishing a feedback loop.
    public func replaceRecords(_ newRecords: [TimerSolveRecord]) {
        guard records != newRecords else { return }
        records = newRecords
        if phase == .stopped {
            lastPenalty = records.first?.penalty ?? .none
        }
    }

    public func setPenalty(_ penalty: TimerSolvePenalty, for id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index] = records[index].applying(penalty)
        if index == records.startIndex, phase == .stopped {
            lastPenalty = penalty
        }
    }

    public func handleAppDeactivation() {
        holdTask?.cancel()
        holdTask = nil

        switch phase {
        case .running:
            guard let solveStart else {
                resetAttempt(makeNewScramble: false)
                return
            }
            let rawSeconds = seconds(from: solveStart, to: clock.now())
            records.insert(
                TimerSolveRecord(rawSeconds: rawSeconds, penalty: .dnf, scramble: scramble),
                at: 0
            )
            self.solveStart = nil
            inspectionStart = nil
            lastPenalty = .dnf
            phase = .stopped
            prepareNextScramble()
            interruptionMessage = "앱이 비활성화되어 진행 중 기록을 DNF로 저장했어요."
        case .holding, .armed, .inspection, .inspectionHolding, .inspectionArmed:
            resetAttempt(makeNewScramble: false)
            interruptionMessage = "앱이 비활성화되어 준비 중이던 시도를 취소했어요."
        case .idle, .stopped:
            break
        }
    }

    public func clearInterruptionMessage() {
        interruptionMessage = nil
    }

    /// VoiceOver and Voice Control users need an activation path that doesn't
    /// depend on a timed touch-and-hold gesture.
    public func activateAccessibleTimerControl() {
        guard isScrambleReady else { return }
        switch phase {
        case .running:
            stopSolve()
        case .idle where mode == .free:
            beginSolve(penalty: .none)
        case .stopped where mode == .free:
            resetAttempt(makeNewScramble: false)
            beginSolve(penalty: .none)
        case .inspection, .inspectionHolding:
            beginSolve(penalty: currentInspectionPenalty(at: clock.now()))
        case .armed:
            beginSolve(penalty: .none)
        case .inspectionArmed:
            beginSolve(penalty: currentInspectionPenalty(at: clock.now()))
        default:
            break
        }
    }

    private func beginHold(inspection: Bool) {
        phase = inspection ? .inspectionHolding : .holding
        holdTask?.cancel()
        holdTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            if inspection, self.phase == .inspectionHolding {
                self.phase = .inspectionArmed
            } else if !inspection, self.phase == .holding {
                self.phase = .armed
            }
        }
    }

    private func loadScrambleCatalog() {
        catalogLoadTask?.cancel()
        scrambleGenerator = nil
        scramblePresentation = nil
        scrambleCatalogState = .loading

        let loader = catalogLoader
        let seed = scrambleSeed
        catalogLoadTask = Task { [weak self] in
            do {
                let catalog = try await loader.load()
                guard !Task.isCancelled, let self else { return }
                let generator = TimerScrambleGenerator(catalog: catalog, seed: seed)
                self.scrambleGenerator = generator
                try self.setNextScramble(using: generator)
                self.scrambleCatalogState = .ready
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.failScramblePreparation()
            }
        }
    }

    private func setNextScramble(using generator: TimerScrambleGenerator) throws {
        let nextScramble = generator.make()
        let algorithm = try WCAParser.parse(nextScramble)
        guard algorithm.moves.allSatisfy({
            $0.symbol.isFace && !$0.isWide && $0.layerCount == nil
        }) else {
            throw TimerScramblePreparationError.unsupportedMove
        }
        let nextState = try CubeState.solved.applying(algorithm)

        // A single published payload prevents the UI from ever observing new
        // notation paired with the preceding scramble's cube state.
        scramblePresentation = ScramblePresentation(
            notation: nextScramble,
            cubeState: nextState
        )
    }

    private func failScramblePreparation() {
        scrambleGenerator = nil
        scramblePresentation = nil
        scrambleCatalogState = .failed
    }

    private func beginSolve(penalty: TimerSolvePenalty) {
        lastPenalty = penalty
        solveStart = clock.now()
        phase = .running
    }

    private func stopSolve() {
        guard phase == .running, let solveStart else { return }
        let stoppedAt = clock.now()
        let rawSeconds = seconds(from: solveStart, to: stoppedAt)
        let completedScramble = scramble
        records.insert(
            TimerSolveRecord(
                rawSeconds: rawSeconds,
                penalty: lastPenalty,
                scramble: completedScramble
            ),
            at: 0
        )
        self.solveStart = nil
        inspectionStart = nil
        phase = .stopped
        prepareNextScramble()
    }

    private func prepareNextScramble() {
        guard let scrambleGenerator else {
            failScramblePreparation()
            return
        }
        do {
            try setNextScramble(using: scrambleGenerator)
        } catch {
            failScramblePreparation()
        }
    }

    private func currentInspectionPenalty(at now: Duration) -> TimerSolvePenalty {
        let elapsed = inspectionElapsed(at: now)
        switch InspectionPenalty.at(elapsed: elapsed) {
        case .none: return .none
        case .plusTwo: return .plusTwo
        case .dnf: return .dnf
        }
    }

    private func seconds(from start: Duration, to end: Duration) -> Double {
        let components = (end - start).components
        return max(0, Double(components.seconds) + Double(components.attoseconds) / 1e18)
    }
}
