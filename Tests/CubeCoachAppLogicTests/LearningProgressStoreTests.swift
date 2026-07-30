import CubeCoachCore
import Foundation
import Testing
@testable import CubeCoachAppLogic

private struct LegacySnapshot: Codable {
    var progress: [String: ReviewState]
    var records: [SolveRecord]
    var dailyGoal: Int
}

private func isolatedDefaults() -> UserDefaults {
    let suite = "CubeCoachAppLogicTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@MainActor
@Test func legacySnapshotMigratesWithoutLosingData() throws {
    let defaults = isolatedDefaults()
    let review = ReviewState.new(dueAt: Date(timeIntervalSince1970: 1_000))
    let record = SolveRecord(
        timestamp: Date(timeIntervalSince1970: 2_000),
        rawDuration: 12.34
    )
    let legacy = LegacySnapshot(
        progress: ["case": review],
        records: [record],
        dailyGoal: 7
    )
    defaults.set(try JSONEncoder().encode(legacy), forKey: "cubeCoach.learning.snapshot.v1")

    let store = LearningProgressStore(defaults: defaults, catalog: [])

    #expect(store.progress["case"] == review)
    #expect(store.records == [record])
    #expect(store.dailyGoal == 7)
}

@MainActor
@Test func legacySnapshotIsRewrittenWithSchemaVersion() throws {
    let defaults = isolatedDefaults()
    let legacy = LegacySnapshot(progress: [:], records: [], dailyGoal: 10)
    defaults.set(try JSONEncoder().encode(legacy), forKey: "cubeCoach.learning.snapshot.v1")

    _ = LearningProgressStore(defaults: defaults, catalog: [])

    let migrated = try #require(defaults.data(forKey: "cubeCoach.learning.snapshot.v1"))
    let object = try #require(
        JSONSerialization.jsonObject(with: migrated) as? [String: Any]
    )
    #expect(object["schemaVersion"] as? Int == 3)
}

@MainActor
@Test func corruptSnapshotIsBackedUpBeforeReset() {
    let defaults = isolatedDefaults()
    let corrupt = Data("not-json".utf8)
    defaults.set(corrupt, forKey: "cubeCoach.learning.snapshot.v1")

    let store = LearningProgressStore(defaults: defaults, catalog: [])

    #expect(defaults.data(forKey: "cubeCoach.learning.snapshot.recovery") == corrupt)
    #expect(defaults.data(forKey: "cubeCoach.learning.snapshot.v1") == nil)
    #expect(store.persistenceWarning != nil)
}

@MainActor
@Test func hintAssistedRecallCannotReceiveTheLongestEasyInterval() {
    let learningCase = StudyCaseUI(
        id: "assisted-case",
        title: "테스트 케이스",
        recognition: "먼저 인식",
        answerTitle: "공식",
        algorithm: "R U R'",
        hint: "힌트",
        level: "테스트",
        family: "테스트"
    )
    let reviewedAt = Date(timeIntervalSince1970: 10_000)
    let assistedDefaults = isolatedDefaults()
    let assistedStore = LearningProgressStore(
        defaults: assistedDefaults,
        catalog: [learningCase]
    )
    let unassistedStore = LearningProgressStore(
        defaults: isolatedDefaults(),
        catalog: [learningCase]
    )

    assistedStore.rate(learningCase, as: .easy, assisted: true, now: reviewedAt)
    unassistedStore.rate(learningCase, as: .easy, assisted: false, now: reviewedAt)

    #expect(assistedStore.progressValue(for: learningCase.id).intervalDays == 1)
    #expect(unassistedStore.progressValue(for: learningCase.id).intervalDays == 4)
    #expect(assistedStore.assistedReviewCount == 1)
    #expect(assistedStore.totalReviewCount == 1)
    #expect(assistedStore.independentReviewRate == 0)
    #expect(unassistedStore.independentReviewRate == 1)

    let reloadedStore = LearningProgressStore(
        defaults: assistedDefaults,
        catalog: [learningCase]
    )
    #expect(reloadedStore.assistedReviewCount == 1)
    #expect(reloadedStore.totalReviewCount == 1)
}

@MainActor
@Test func deletingAllLocalDataClearsActiveSnapshotRecoveryCopyAndMemory() throws {
    let defaults = isolatedDefaults()
    let corrupt = Data("unreadable-snapshot".utf8)
    defaults.set(corrupt, forKey: "cubeCoach.learning.snapshot.v1")

    let learningCase = StudyCaseUI(
        id: "privacy-delete-case",
        title: "삭제 테스트",
        recognition: "테스트 인식",
        answerTitle: "공식",
        algorithm: "R U R'",
        hint: "테스트 힌트",
        level: "테스트",
        family: "테스트"
    )
    let store = LearningProgressStore(defaults: defaults, catalog: [learningCase])
    store.rate(
        learningCase,
        as: .good,
        assisted: true,
        now: Date(timeIntervalSince1970: 3_000)
    )
    store.addRecord(
        SolveRecord(
            timestamp: Date(timeIntervalSince1970: 4_000),
            rawDuration: 15.2
        )
    )
    store.dailyGoal = 24

    #expect(defaults.data(forKey: "cubeCoach.learning.snapshot.v1") != nil)
    #expect(defaults.data(forKey: "cubeCoach.learning.snapshot.recovery") == corrupt)

    store.deleteAllLocalData()

    #expect(store.progress.isEmpty)
    #expect(store.records.isEmpty)
    #expect(store.attempts.isEmpty)
    #expect(store.assistedReviewCount == 0)
    #expect(store.totalReviewCount == 0)
    #expect(store.dailyGoal == 10)
    #expect(store.persistenceWarning == nil)
    #expect(defaults.data(forKey: "cubeCoach.learning.snapshot.v1") == nil)
    #expect(defaults.data(forKey: "cubeCoach.learning.snapshot.recovery") == nil)

    let reloadedStore = LearningProgressStore(defaults: defaults, catalog: [learningCase])
    #expect(reloadedStore.progress.isEmpty)
    #expect(reloadedStore.records.isEmpty)
    #expect(reloadedStore.attempts.isEmpty)
    #expect(reloadedStore.dailyGoal == 10)
    #expect(reloadedStore.assistedReviewCount == 0)
    #expect(reloadedStore.totalReviewCount == 0)
}
