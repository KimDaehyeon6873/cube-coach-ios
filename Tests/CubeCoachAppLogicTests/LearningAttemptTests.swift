import CubeCoachCore
import Foundation
import Testing
@testable import CubeCoachAppLogic

private struct V1Snapshot: Codable {
    var progress: [String: ReviewState]
    var records: [SolveRecord]
    var dailyGoal: Int
    var assistedReviewCounts: [String: Int]?
    var totalReviewCounts: [String: Int]?
}

private struct V1Envelope: Codable {
    var schemaVersion: Int
    var payload: V1Snapshot
}

private func attemptDefaults() -> UserDefaults {
    let suite = "CubeCoachAttemptTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

private func attempt(
    caseID: String = "case",
    timestamp: Date = Date(timeIntervalSince1970: 10_000),
    startedAt: Date? = nil,
    preparation: PreparationMethod? = .externallyPrepared,
    hint: LearningHintLevel = .h0,
    playback: Bool = false,
    recognition: RecognitionOutcome = .correct,
    execution: ExecutionOutcome = .matched,
    evidence: OutcomeEvidence = .manualComparison,
    contentVersion: String = "catalog-1"
) -> ReviewAttempt {
    ReviewAttempt(
        caseID: caseID,
        timestamp: timestamp,
        startedAt: startedAt,
        preparation: preparation,
        maxHint: hint,
        playbackUsed: playback,
        recognition: recognition,
        execution: execution,
        evidence: evidence,
        mode: .review,
        contentVersion: contentVersion
    )
}

@MainActor
@Test func v1EnvelopeMigratesToV3WithoutLosingLegacyData() throws {
    let defaults = attemptDefaults()
    let review = ReviewState.new(dueAt: Date(timeIntervalSince1970: 100))
    let solve = SolveRecord(
        timestamp: Date(timeIntervalSince1970: 200),
        rawDuration: 9.87
    )
    let legacy = V1Envelope(
        schemaVersion: 1,
        payload: V1Snapshot(
            progress: ["legacy": review],
            records: [solve],
            dailyGoal: 17,
            assistedReviewCounts: ["legacy": 2],
            totalReviewCounts: ["legacy": 5]
        )
    )
    defaults.set(
        try JSONEncoder().encode(legacy),
        forKey: "cubeCoach.learning.snapshot.v1"
    )

    let store = LearningProgressStore(defaults: defaults, catalog: [])

    #expect(store.progress["legacy"] == review)
    #expect(store.records == [solve])
    #expect(store.dailyGoal == 17)
    #expect(store.assistedReviewCounts["legacy"] == 2)
    #expect(store.totalReviewCounts["legacy"] == 5)
    #expect(store.attempts.isEmpty)

    let migrated = try #require(
        defaults.data(forKey: "cubeCoach.learning.snapshot.v1")
    )
    let object = try #require(
        JSONSerialization.jsonObject(with: migrated) as? [String: Any]
    )
    #expect(object["schemaVersion"] as? Int == 3)
}

@MainActor
@Test func attemptPersistsAndDeleteAllClearsIt() {
    let defaults = attemptDefaults()
    let original = LearningProgressStore(defaults: defaults, catalog: [])
    let reviewAttempt = attempt()

    #expect(original.recordAttempt(reviewAttempt))
    #expect(original.attempts == [reviewAttempt])
    #expect(original.independentAttemptCount == 1)
    #expect(original.assistedAttemptCount == 0)

    let reloaded = LearningProgressStore(defaults: defaults, catalog: [])
    #expect(reloaded.attempts == [reviewAttempt])
    #expect(reloaded.attemptSummary.matched == 1)

    reloaded.deleteAllLocalData()
    #expect(reloaded.attempts.isEmpty)
    #expect(reloaded.independentAttemptCount == 0)
    #expect(
        LearningProgressStore(defaults: defaults, catalog: []).attempts.isEmpty
    )
}

@Test func objectiveOutcomesDeriveDeterministicSchedulerGrades() {
    #expect(attempt(execution: .didNotMatch).schedulerRating == .again)
    #expect(attempt(execution: .unsure).schedulerRating == .again)
    #expect(attempt(hint: .h1).schedulerRating == .hard)
    #expect(attempt(hint: .h2).schedulerRating == .hard)
    #expect(attempt(hint: .h3).schedulerRating == .hard)
    #expect(attempt(hint: .h5).schedulerRating == .hard)
    #expect(attempt(playback: true).schedulerRating == .hard)
    #expect(attempt(recognition: .corrected).schedulerRating == .hard)
    #expect(attempt(preparation: .guidedAcquisition).schedulerRating == .hard)
    #expect(attempt(preparation: nil).schedulerRating == .hard)
    #expect(attempt(hint: .h0).schedulerRating == .good)
    #expect(attempt(recognition: .notAssessed).schedulerRating == .good)
}

@Test func reviewAttemptWithoutExplicitPreparationFailsClosed() {
    let review = ReviewAttempt(
        caseID: "implicit-preparation",
        execution: .matched
    )

    #expect(review.preparation == nil)
    #expect(review.wasAssisted)
    #expect(review.schedulerRating == .hard)
}

@MainActor
@Test func outOfOrderAttemptIsRetainedWithoutRewindingSchedule() {
    let store = LearningProgressStore(defaults: attemptDefaults(), catalog: [])
    let newer = attempt(timestamp: Date(timeIntervalSince1970: 20_000))
    let older = attempt(
        timestamp: Date(timeIntervalSince1970: 10_000),
        execution: .didNotMatch
    )

    #expect(store.recordAttempt(newer))
    let scheduledAfterNewer = store.progressValue(for: newer.caseID)
    #expect(store.recordAttempt(older))

    #expect(store.attempts.count == 2)
    #expect(store.totalReviewCounts[newer.caseID] == 2)
    #expect(store.progressValue(for: newer.caseID) == scheduledAfterNewer)
}

@MainActor
@Test func contentVersionChangeResetsSchedulingBaseline() {
    let store = LearningProgressStore(defaults: attemptDefaults(), catalog: [])
    let first = attempt(
        timestamp: Date(timeIntervalSince1970: 10_000),
        preparation: .externallyPrepared
    )
    let repeated = attempt(
        timestamp: Date(timeIntervalSince1970: 20_000),
        preparation: .externallyPrepared
    )
    let revised = ReviewAttempt(
        caseID: first.caseID,
        timestamp: Date(timeIntervalSince1970: 30_000),
        preparation: .externallyPrepared,
        execution: .matched,
        contentVersion: "catalog-2"
    )

    #expect(store.recordAttempt(first))
    #expect(store.recordAttempt(repeated))
    #expect(store.progressValue(for: first.caseID).repetitions == 2)
    #expect(store.progressValue(for: first.caseID).intervalDays == 3)

    #expect(store.recordAttempt(revised))
    let resetResult = store.progressValue(for: first.caseID)
    #expect(resetResult.repetitions == 1)
    #expect(resetResult.intervalDays == 1)
    #expect(resetResult.lastReviewedAt == revised.timestamp)
}

@MainActor
@Test func persistedContentVersionSurvivesAttemptHistoryTruncation() {
    let defaults = attemptDefaults()
    let original = LearningProgressStore(defaults: defaults, catalog: [])
    let caseID = "versioned-case"

    #expect(original.recordAttempt(attempt(
        caseID: caseID,
        timestamp: Date(timeIntervalSince1970: 1),
        contentVersion: "catalog-1"
    )))
    #expect(original.recordAttempt(attempt(
        caseID: caseID,
        timestamp: Date(timeIntervalSince1970: 2),
        contentVersion: "catalog-1"
    )))
    for offset in 0..<500 {
        #expect(original.recordAttempt(attempt(
            caseID: "filler-\(offset)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(10 + offset)),
            execution: .unsure
        )))
    }
    #expect(original.attempts.allSatisfy { $0.caseID != caseID })

    let reloaded = LearningProgressStore(defaults: defaults, catalog: [])
    #expect(reloaded.recordAttempt(attempt(
        caseID: caseID,
        timestamp: Date(timeIntervalSince1970: 1_000),
        contentVersion: "catalog-1"
    )))
    #expect(reloaded.progressValue(for: caseID).repetitions == 3)
    #expect(reloaded.progressValue(for: caseID).intervalDays == 8)

    #expect(reloaded.recordAttempt(attempt(
        caseID: caseID,
        timestamp: Date(timeIntervalSince1970: 2_000),
        contentVersion: "catalog-2"
    )))
    #expect(reloaded.progressValue(for: caseID).repetitions == 1)
    #expect(reloaded.progressValue(for: caseID).intervalDays == 1)
}

@MainActor
@Test func legacyProgressWithUnknownContentVersionStartsFromNewBaseline() throws {
    let defaults = attemptDefaults()
    let oldProgress = ReviewState(
        repetitions: 8,
        intervalDays: 21,
        easeFactor: 2.8,
        dueAt: Date(timeIntervalSince1970: 50_000),
        lastReviewedAt: Date(timeIntervalSince1970: 20_000)
    )
    let legacy = V1Envelope(
        schemaVersion: 1,
        payload: V1Snapshot(
            progress: ["legacy-version": oldProgress],
            records: [],
            dailyGoal: 10,
            assistedReviewCounts: nil,
            totalReviewCounts: nil
        )
    )
    defaults.set(
        try JSONEncoder().encode(legacy),
        forKey: "cubeCoach.learning.snapshot.v1"
    )

    let store = LearningProgressStore(defaults: defaults, catalog: [])
    let firstObjectiveAttempt = attempt(
        caseID: "legacy-version",
        timestamp: Date(timeIntervalSince1970: 30_000),
        contentVersion: "catalog-current"
    )
    #expect(store.recordAttempt(firstObjectiveAttempt))

    let result = store.progressValue(for: "legacy-version")
    #expect(result.repetitions == 1)
    #expect(result.intervalDays == 1)
    #expect(result.lastReviewedAt == firstObjectiveAttempt.timestamp)
}

@MainActor
@Test func recordAttemptSchedulesOutcomesAndRejectsDuplicates() {
    let store = LearningProgressStore(defaults: attemptDefaults(), catalog: [])
    let mismatch = attempt(execution: .didNotMatch)

    #expect(store.recordAttempt(mismatch))
    #expect(!store.recordAttempt(mismatch))
    #expect(store.progressValue(for: mismatch.caseID).repetitions == 0)
    #expect(store.attempts.count == 1)

    let matched = attempt(
        timestamp: mismatch.timestamp.addingTimeInterval(1),
        hint: .h4,
        execution: .matched,
        evidence: .validatedScan
    )
    #expect(store.recordAttempt(matched))
    #expect(store.progressValue(for: matched.caseID).repetitions == 1)
    #expect(store.assistedAttemptCount == 1)
    #expect(store.attemptSummary.didNotMatch == 1)
    #expect(store.attemptSummary.matched == 1)
}

@MainActor
@Test func attemptHistoryRetainsOnlyTheMostRecentFiveHundred() {
    let store = LearningProgressStore(defaults: attemptDefaults(), catalog: [])

    for offset in 0..<505 {
        #expect(store.recordAttempt(attempt(
            timestamp: Date(timeIntervalSince1970: TimeInterval(offset)),
            execution: .unsure
        )))
    }

    #expect(store.attempts.count == 500)
    #expect(store.attempts.first?.timestamp == Date(timeIntervalSince1970: 5))
    #expect(store.attempts.last?.timestamp == Date(timeIntervalSince1970: 504))
}

@Test func allAttemptOutcomesRoundTripThroughCodable() throws {
    let attempts = [
        attempt(recognition: .correct, execution: .matched),
        attempt(
            timestamp: Date(timeIntervalSince1970: 10_001),
            recognition: .corrected,
            execution: .didNotMatch,
            evidence: .validatedScan
        ),
        attempt(
            timestamp: Date(timeIntervalSince1970: 10_002),
            recognition: .notAssessed,
            execution: .unsure
        ),
    ]

    let data = try JSONEncoder().encode(attempts)
    #expect(try JSONDecoder().decode([ReviewAttempt].self, from: data) == attempts)
}

@Test func legacyOutcomeEvidenceNamesDecodeAndReencodeCanonically() throws {
    let aliases: [(String, OutcomeEvidence, String)] = [
        ("selfCompared", .manualComparison, "manualComparison"),
        ("scanVerified", .validatedScan, "validatedScan"),
    ]

    for (legacyName, expected, canonicalName) in aliases {
        let legacyData = try #require("\"\(legacyName)\"".data(using: .utf8))
        let decoded = try JSONDecoder().decode(OutcomeEvidence.self, from: legacyData)
        #expect(decoded == expected)

        let encoded = try JSONEncoder().encode(decoded)
        #expect(String(decoding: encoded, as: UTF8.self) == "\"\(canonicalName)\"")
    }
}

@Test func legacyPracticeModeNameDecodesAndReencodesCanonically() throws {
    let legacyData = try #require("\"scannedCase\"".data(using: .utf8))
    let decoded = try JSONDecoder().decode(PracticeMode.self, from: legacyData)
    #expect(decoded == .scanRecommendation)
    #expect(
        String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self) ==
            "\"scanRecommendation\""
    )
}

@Test func legacyAttemptWithoutPreparationOrStartedAtDecodesAsAssisted() throws {
    let legacyJSON = """
    {
      "caseID": "legacy-attempt",
      "timestamp": 1000,
      "maxHint": 0,
      "playbackUsed": false,
      "recognition": "correct",
      "execution": "matched",
      "evidence": "selfCompared",
      "mode": "scannedCase",
      "contentVersion": "legacy-v1"
    }
    """
    let data = try #require(legacyJSON.data(using: .utf8))
    let decoded = try JSONDecoder().decode(ReviewAttempt.self, from: data)

    #expect(decoded.preparation == nil)
    #expect(decoded.startedAt == nil)
    #expect(decoded.wasAssisted)
    #expect(decoded.schedulerRating == .hard)
    #expect(decoded.mode == .scanRecommendation)
}

@Test func trainerAttemptStateKeepsHintsMonotonicAndCompletesOnce() throws {
    let startedAt = Date(timeIntervalSince1970: 42)
    let completedAt = Date(timeIntervalSince1970: 84)
    var state = TrainerAttemptState(
        caseID: "state-case",
        timestamp: startedAt,
        mode: .practice,
        contentVersion: "v7"
    )

    let unpreparedAdvance = state.advance(from: .prepare)
    let prematureHint = state.revealHint(.h2)
    #expect(!unpreparedAdvance)
    #expect(!prematureHint)
    let preparationRecorded = state.recordPreparation(.externallyPrepared)
    let duplicatePreparation = state.recordPreparation(.guidedAcquisition)
    let prepared = state.advance(from: .prepare)
    let recognized = state.recordRecognition(.corrected)
    let revealedH2 = state.revealHint(.h2)
    let rejectedH1 = state.revealHint(.h1)
    #expect(revealedH2)
    #expect(!rejectedH1)
    #expect(state.maxHint == .h2)
    #expect(preparationRecorded)
    #expect(!duplicatePreparation)
    let playedBack = state.recordPlaybackUsed()
    let recalled = state.advance(from: .recall)
    let playbackOutsideRecall = state.recordPlaybackUsed()
    #expect(playedBack)
    #expect(!playbackOutsideRecall)
    let executedPlayback = state.advance(from: .playback)
    let executed = state.recordExecution(.matched)
    #expect(prepared)
    #expect(recognized)
    #expect(recalled)
    #expect(executedPlayback)
    #expect(executed)

    let completion = state.complete(
        evidence: .manualComparison,
        completedAt: completedAt
    )
    let completed = try #require(completion)
    #expect(completed.timestamp == completedAt)
    #expect(completed.startedAt == startedAt)
    #expect(completed.preparation == .externallyPrepared)
    #expect(completed.maxHint == .h2)
    #expect(completed.playbackUsed)
    #expect(completed.recognition == .corrected)
    #expect(completed.execution == .matched)
    #expect(completed.schedulerRating == .hard)
    #expect(state.phase == .result)
    let duplicate = state.complete(evidence: .manualComparison)
    let staleAdvance = state.advance(from: .compare)
    #expect(duplicate == nil)
    #expect(!staleAdvance)
}

@Test func correctedRecognitionMarksTrainerAttemptAsAssisted() {
    var state = TrainerAttemptState(caseID: "corrected-case")
    #expect(state.wasAssisted)

    let recorded = state.recordPreparation(.externallyPrepared)
    #expect(!state.wasAssisted)
    let prepared = state.advance(from: .prepare)
    let corrected = state.recordRecognition(.corrected)

    #expect(recorded)
    #expect(prepared)
    #expect(corrected)
    #expect(state.wasAssisted)
}

@Test func guidedAcquisitionIsAssistedWithoutRevealingRecallHint() throws {
    let completedAt = Date(timeIntervalSince1970: 200)
    var state = TrainerAttemptState(
        caseID: "guided-case",
        timestamp: Date(timeIntervalSince1970: 100)
    )

    let prepared = state.recordPreparation(.guidedAcquisition)
    #expect(prepared)
    #expect(state.playbackUsed)
    #expect(state.maxHint == .h0)
    #expect(state.wasAssisted)
    let advancedFromPrepare = state.advance(from: .prepare)
    let recognized = state.recordRecognition(.notAssessed)
    let advancedFromRecall = state.advance(from: .recall)
    let advancedFromPlayback = state.advance(from: .playback)
    let executed = state.recordExecution(.matched)
    let completion = state.complete(
        evidence: .manualComparison,
        completedAt: completedAt
    )
    #expect(advancedFromPrepare)
    #expect(recognized)
    #expect(advancedFromRecall)
    #expect(advancedFromPlayback)
    #expect(executed)
    let review = try #require(completion)
    #expect(review.preparation == .guidedAcquisition)
    #expect(review.maxHint == .h0)
    #expect(review.playbackUsed)
    #expect(review.schedulerRating == .hard)
}

@Test func playbackCanOnlyBeRecordedDuringRecallAndIsMonotonic() {
    var state = TrainerAttemptState(caseID: "playback-case")

    let prematurePlayback = state.recordPlaybackUsed()
    let prepared = state.recordPreparation(.externallyPrepared)
    let advancedFromPrepare = state.advance(from: .prepare)
    let recognized = state.recordRecognition(.correct)
    let firstPlayback = state.recordPlaybackUsed()
    let duplicatePlayback = state.recordPlaybackUsed()
    #expect(!prematurePlayback)
    #expect(prepared)
    #expect(advancedFromPrepare)
    #expect(recognized)
    #expect(firstPlayback)
    #expect(!duplicatePlayback)
    #expect(state.playbackUsed)
    let advancedFromRecall = state.advance(from: .recall)
    let latePlayback = state.recordPlaybackUsed(from: .playback)
    #expect(advancedFromRecall)
    #expect(!latePlayback)
    #expect(state.playbackUsed)
}

@Test func studyCaseContentVersionIsStableAndChangesWithAuthoredInputs() {
    let original = StudyCaseUI(
        id: "case-id",
        title: "Case",
        recognition: "recognition",
        answerTitle: "공식",
        algorithm: "R U R'",
        hint: "hint",
        level: "level",
        family: "family"
    )
    let recreated = StudyCaseUI(
        id: "case-id",
        title: "Renamed display title",
        recognition: "recognition",
        answerTitle: "formula",
        algorithm: "R U R'",
        hint: "changed non-execution copy",
        level: "other level",
        family: "other family"
    )
    let revisedRecognition = StudyCaseUI(
        id: "case-id",
        title: "Case",
        recognition: "revised recognition",
        answerTitle: "공식",
        algorithm: "R U R'",
        hint: "hint",
        level: "level",
        family: "family"
    )
    let revisedNotation = StudyCaseUI(
        id: "case-id",
        title: "Case",
        recognition: "recognition",
        answerTitle: "공식",
        algorithm: "R U2 R'",
        hint: "hint",
        level: "level",
        family: "family"
    )

    #expect(original.contentVersion == recreated.contentVersion)
    #expect(original.contentVersion != revisedRecognition.contentVersion)
    #expect(original.contentVersion != revisedNotation.contentVersion)
    #expect(original.contentVersion == "fnv1a64-7d9786e13d69bebc")
}

@Test func studyCaseWithoutAuthoredExerciseRemainsNonExecutable() {
    let theory = StudyCaseUI(
        id: "theory",
        title: "Theory",
        recognition: "Explain",
        answerTitle: "개념",
        algorithm: "R U R'",
        hint: "No authored physical setup",
        level: "Test",
        family: "Theory"
    )

    #expect(theory.exercise == nil)
}

@Test func builtInCatalogValidationKeepsEveryAuthoredExecutableCase() throws {
    let expectedIDs = CurriculumCatalog.builtIn.flatMap { curriculum in
        curriculum.lessons.flatMap { lesson in
            lesson.algorithms.compactMap { sample in
                sample.exercise == nil ? nil : sample.id
            }
        }
    }
    let validated = try StudyCaseUI.validatedCoreCatalog(
        from: CurriculumCatalog.builtIn
    )

    #expect(validated.map(\.id) == expectedIDs)
    #expect(validated.allSatisfy { $0.exercise != nil })
}

@Test func invalidBuiltInExerciseReturnsTypedValidationFailure() {
    let invalid = Curriculum(
        track: .beginner,
        title: "Invalid",
        lessons: [
            CurriculumLesson(
                id: "invalid-lesson",
                title: "Invalid lesson",
                objective: "Reject invalid notation",
                algorithms: [
                    AlgorithmSample(
                        id: "invalid-case",
                        name: "Invalid case",
                        notation: "Q",
                        recognitionHint: "Invalid",
                        exercise: LearningExerciseSpec(
                            setupNotation: "",
                            solutionNotation: "Q",
                            chunkBoundaries: [0, 1]
                        )
                    ),
                ],
                sources: []
            ),
        ]
    )

    #expect(throws: StudyCaseUI.CatalogValidationError.self) {
        try StudyCaseUI.validatedCoreCatalog(from: [invalid])
    }
}
