import CryptoKit
import Foundation
import Testing
@testable import CubeCoachAppLogic
@testable import CubeCoachCore

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Duration = .zero

    func now() -> Duration {
        lock.withLock { value }
    }

    func advance(by duration: Duration) {
        lock.withLock { value += duration }
    }
}

@MainActor
private func makeReadyModel(
    clock: TimerMonotonicClock = .continuous,
    initialRecords: [TimerSolveRecord] = []
) async throws -> TimerFeatureModel {
    let catalog = try makeTestCatalog()
    let model = TimerFeatureModel(
        clock: clock,
        initialRecords: initialRecords,
        catalogLoader: TimerScrambleCatalogLoader { catalog },
        scrambleSeed: 42
    )
    await model.waitForScrambleCatalog()
    #expect(model.scrambleCatalogState == .ready)
    return model
}

private func makeTestCatalog() throws -> TNoodleScrambleCatalog {
    try makeTestCatalog(notations: ["R U R'", "F2 D' L2"])
}

private func makeTestCatalog(notations: [String]) throws -> TNoodleScrambleCatalog {
    let encoder = JSONEncoder()
    let pool = try notations
        .map { String(decoding: try encoder.encode($0), as: UTF8.self) }
        .joined(separator: "\n") + "\n"
    let data = Data(pool.utf8)
    let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    let manifest = TNoodleScrambleManifest(
        schemaVersion: 1,
        event: "333",
        generator: "TNoodle-WCA",
        generatorVersion: TNoodleScrambleCatalog.version,
        officialReleaseURL: "https://github.com/thewca/tnoodle/releases/tag/v1.2.3",
        generatorSHA256: TNoodleScrambleCatalog.generatorSHA256,
        signedBuild: true,
        count: notations.count,
        poolSHA256: checksum,
        claim: .tnoodleGeneratedPractice
    )
    return try TNoodleScrambleCatalog(manifest: manifest, poolData: data)
}

private enum TestCatalogError: Error {
    case unavailable
}

private actor RetryCatalogLoader {
    private var shouldFail = true
    private let catalog: TNoodleScrambleCatalog

    init(catalog: TNoodleScrambleCatalog) {
        self.catalog = catalog
    }

    func load() throws -> TNoodleScrambleCatalog {
        if shouldFail {
            shouldFail = false
            throw TestCatalogError.unavailable
        }
        return catalog
    }
}

@MainActor
@Test func deactivationWhileRunningStoresDNF() async throws {
    let clock = TestClock()
    let model = try await makeReadyModel(clock: TimerMonotonicClock(read: clock.now))
    let completedScramble = model.scramble
    model.activateAccessibleTimerControl()
    clock.advance(by: .seconds(7))

    model.handleAppDeactivation()

    #expect(model.phase == .stopped)
    #expect(model.records.first?.penalty == .dnf)
    #expect(model.records.first?.rawSeconds == 7)
    #expect(model.records.first?.scramble == completedScramble)
    #expect(model.scramble != completedScramble)

    let preparedScramble = model.scramble
    model.activateAccessibleTimerControl()
    #expect(model.phase == .running)
    #expect(model.scramble == preparedScramble)
}

@MainActor
@Test func deactivationDuringInspectionCancelsAttemptWithoutRecord() async throws {
    let model = try await makeReadyModel()
    model.mode = .wcaPractice
    model.startInspection()

    model.handleAppDeactivation()

    #expect(model.phase == .idle)
    #expect(model.records.isEmpty)
}

@MainActor
@Test func stoppedWCAAttemptDisplaysAndReusesExactlyOnePreparedScramble() async throws {
    let clock = TestClock()
    let model = try await makeReadyModel(clock: TimerMonotonicClock(read: clock.now))
    model.mode = .wcaPractice
    let completedScramble = model.scramble
    model.startInspection()
    model.activateAccessibleTimerControl()
    clock.advance(by: .seconds(5))
    model.activateAccessibleTimerControl()

    #expect(model.phase == .stopped)
    #expect(model.records.first?.scramble == completedScramble)
    #expect(model.scramble != completedScramble)

    let preparedScramble = model.scramble
    model.startInspection()

    #expect(model.phase == .inspection)
    #expect(model.scramble == preparedScramble)

    model.activateAccessibleTimerControl()
    clock.advance(by: .seconds(6))
    model.activateAccessibleTimerControl()

    #expect(model.records.count == 2)
    #expect(model.records.first?.scramble == preparedScramble)
    #expect(model.scramble != preparedScramble)
}

@MainActor
@Test func editingPenaltyPreservesSolveIdentityAndRawTime() async throws {
    let id = UUID()
    let record = TimerSolveRecord(
        id: id,
        date: Date(timeIntervalSince1970: 123),
        rawSeconds: 9.87,
        scramble: "R U"
    )
    let model = try await makeReadyModel(initialRecords: [record])

    model.setPenalty(.plusTwo, for: id)

    #expect(model.records.first?.id == id)
    #expect(model.records.first?.rawSeconds == 9.87)
    #expect(model.records.first?.penalty == .plusTwo)
}

@MainActor
@Test func durableStoreSnapshotClearsLiveTimerRecordsWithoutResurrection() async throws {
    let clock = TestClock()
    let deletedID = UUID()
    let staleRecord = TimerSolveRecord(
        id: deletedID,
        date: Date(timeIntervalSince1970: 123),
        rawSeconds: 9.87,
        scramble: "R U"
    )
    let model = try await makeReadyModel(
        clock: TimerMonotonicClock(read: clock.now),
        initialRecords: [staleRecord]
    )

    model.replaceRecords([])
    model.setPenalty(.dnf, for: deletedID)
    model.activateAccessibleTimerControl()
    clock.advance(by: .seconds(5))
    model.activateAccessibleTimerControl()

    #expect(model.records.count == 1)
    #expect(model.records.first?.id != deletedID)
    #expect(model.records.first?.rawSeconds == 5)
}

@MainActor
@Test func changingPracticeModeStartsWithANewScramble() async throws {
    let model = try await makeReadyModel()
    let freeModeScramble = model.scramble

    model.mode = .wcaPractice

    #expect(model.phase == .idle)
    #expect(model.scramble != freeModeScramble)
}

@MainActor
@Test func catalogLoadSuccessPublishesReadyScramble() async throws {
    let model = try await makeReadyModel()
    let algorithm = try WCAParser.parse(model.scramble)
    let expectedState = try CubeState.solved.applying(algorithm)
    let presentation = try #require(model.scramblePresentation)

    #expect(model.isScrambleReady)
    #expect(!model.scramble.isEmpty)
    #expect(presentation.notation == model.scramble)
    #expect(presentation.cubeState == model.scrambledCubeState)
    #expect(model.scrambledCubeState == expectedState)
    #expect(model.scramble == "F2 D' L2")
    #expect(
        expectedState.faceletString
            == "UUUUUUUDDLRRLRRBBBRFFBFFBRRUDDUDDDDDFFFRLLRLLBBLBBFLLF"
    )
}

@MainActor
@Test func nonFaceScrambleFailsClosedBeforeTimerCanStart() async throws {
    let catalog = try makeTestCatalog(notations: ["x"])
    let model = TimerFeatureModel(
        clock: .continuous,
        initialRecords: [],
        catalogLoader: TimerScrambleCatalogLoader { catalog },
        scrambleSeed: 42
    )

    await model.waitForScrambleCatalog()

    #expect(model.scrambleCatalogState == .failed)
    #expect(model.scramble.isEmpty)
    #expect(model.scrambledCubeState == nil)
    #expect(!model.isScrambleReady)

    model.activateAccessibleTimerControl()
    #expect(model.phase == .idle)
    #expect(model.records.isEmpty)
}

@MainActor
@Test func newScrambleUpdatesNotationAndMatchingCubeStateTogether() async throws {
    let model = try await makeReadyModel()
    let previousScramble = model.scramble
    let previousState = model.scrambledCubeState

    model.makeNewScramble()

    let expectedState = try CubeState.solved.applying(WCAParser.parse(model.scramble))
    #expect(model.scramble != previousScramble)
    #expect(model.scrambledCubeState != previousState)
    #expect(model.scrambledCubeState == expectedState)
}

@MainActor
@Test func fullScreenStopOnlyRecordsOnceWhileTimerIsRunning() async throws {
    let clock = TestClock()
    let model = try await makeReadyModel(clock: TimerMonotonicClock(read: clock.now))

    model.stopRunningSolve()
    #expect(model.phase == .idle)
    #expect(model.records.isEmpty)

    model.activateAccessibleTimerControl()
    clock.advance(by: .seconds(4))
    model.stopRunningSolve()
    model.stopRunningSolve()

    #expect(model.phase == .stopped)
    #expect(model.records.count == 1)
    #expect(model.records.first?.rawSeconds == 4)
}

@MainActor
@Test func stoppedFreeAttemptDisplaysAndReusesExactlyOnePreparedScramble() async throws {
    let clock = TestClock()
    let model = try await makeReadyModel(clock: TimerMonotonicClock(read: clock.now))
    let completedScramble = model.scramble

    model.activateAccessibleTimerControl()
    clock.advance(by: .seconds(4))
    model.stopRunningSolve()

    #expect(model.phase == .stopped)
    #expect(model.records.first?.scramble == completedScramble)
    #expect(model.scramble != completedScramble)

    let preparedScramble = model.scramble
    model.pressBegan()
    #expect(model.phase == .holding)
    #expect(model.scramble == preparedScramble)
    model.pressEnded()
    #expect(model.phase == .idle)
    #expect(model.scramble == preparedScramble)

    model.activateAccessibleTimerControl()
    #expect(model.phase == .running)
    #expect(model.scramble == preparedScramble)
    clock.advance(by: .seconds(5))
    model.stopRunningSolve()

    #expect(model.records.count == 2)
    #expect(model.records.first?.scramble == preparedScramble)
    #expect(model.scramble != preparedScramble)
}

@MainActor
@Test func defaultModelInitializationDoesNotWaitForBundledValidation() async {
    let clock = ContinuousClock()
    let startedAt = clock.now
    let model = TimerFeatureModel()
    let initializationDuration = startedAt.duration(to: clock.now)

    #expect(model.scrambleCatalogState == .loading)
    print("TimerFeatureModel synchronous initialization: \(initializationDuration)")

    await model.waitForScrambleCatalog()
    #expect(model.scrambleCatalogState == .ready)
}

@MainActor
@Test func catalogLoadFailureDoesNotCrashAndCanRetry() async throws {
    let scriptedLoader = RetryCatalogLoader(catalog: try makeTestCatalog())
    let model = TimerFeatureModel(
        clock: .continuous,
        initialRecords: [],
        catalogLoader: TimerScrambleCatalogLoader {
            try await scriptedLoader.load()
        },
        scrambleSeed: 42
    )

    await model.waitForScrambleCatalog()
    #expect(model.scrambleCatalogState == .failed)
    #expect(model.scramble.isEmpty)
    #expect(model.scrambledCubeState == nil)

    model.retryScrambleCatalogLoad()
    await model.waitForScrambleCatalog()

    #expect(model.scrambleCatalogState == .ready)
    #expect(!model.scramble.isEmpty)
}

@MainActor
@Test func timerAndScrambleActionsAreIgnoredWhileCatalogLoads() throws {
    let catalog = try makeTestCatalog()
    let model = TimerFeatureModel(
        clock: .continuous,
        initialRecords: [],
        catalogLoader: TimerScrambleCatalogLoader {
            try await Task.sleep(for: .seconds(60))
            return catalog
        },
        scrambleSeed: 42
    )

    model.makeNewScramble()
    model.startInspection()
    model.pressBegan()
    model.pressEnded()
    model.activateAccessibleTimerControl()

    #expect(model.scrambleCatalogState == .loading)
    #expect(model.scramble.isEmpty)
    #expect(model.scrambledCubeState == nil)
    #expect(model.phase == .idle)
    #expect(model.records.isEmpty)
}
