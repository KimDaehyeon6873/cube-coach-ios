import Combine
import CubeCoachCore
import Foundation

@MainActor
final class LearningProgressStore: ObservableObject {
    @Published private(set) var progress: [String: ReviewState]
    @Published private(set) var records: [SolveRecord]
    @Published private(set) var attempts: [ReviewAttempt]
    @Published private(set) var assistedReviewCounts: [String: Int]
    @Published private(set) var totalReviewCounts: [String: Int]
    @Published private(set) var persistenceWarning: String?
    @Published var dailyGoal: Int {
        didSet { save() }
    }

    let catalog: [StudyCaseUI]

    private let defaults: UserDefaults
    private let storageKey = "cubeCoach.learning.snapshot.v1"
    private let recoveryKey = "cubeCoach.learning.snapshot.recovery"
    private var suppressesPersistence = false
    private var lastScheduledContentVersions: [String: String]
    private static let currentSchemaVersion = 3
    private static let attemptHistoryLimit = 500

    private struct Snapshot: Codable {
        var progress: [String: ReviewState]
        var records: [SolveRecord]
        var dailyGoal: Int
        var assistedReviewCounts: [String: Int]?
        var totalReviewCounts: [String: Int]?
        var attempts: [ReviewAttempt]?
        var lastScheduledContentVersions: [String: String]?
    }

    private struct SnapshotEnvelope: Codable {
        var schemaVersion: Int
        var payload: Snapshot
    }

    init(defaults: UserDefaults = .standard, catalog: [StudyCaseUI] = StudyCaseUI.coreCatalog) {
        self.defaults = defaults
        self.catalog = catalog

        var loadedSnapshot: Snapshot?
        var warning: String?
        var requiresMigration = false

        if let data = defaults.data(forKey: storageKey) {
            do {
                let envelope = try JSONDecoder().decode(SnapshotEnvelope.self, from: data)
                guard (1...Self.currentSchemaVersion).contains(envelope.schemaVersion)
                else {
                    throw PersistenceError.unsupportedSchema(envelope.schemaVersion)
                }
                loadedSnapshot = envelope.payload
                requiresMigration = envelope.schemaVersion < Self.currentSchemaVersion
            } catch {
                // Migrate the unversioned prototype payload before treating it as corrupt.
                if let legacy = try? JSONDecoder().decode(Snapshot.self, from: data) {
                    loadedSnapshot = legacy
                    requiresMigration = true
                } else {
                    defaults.set(data, forKey: recoveryKey)
                    defaults.removeObject(forKey: storageKey)
                    warning = "기존 학습 기록을 읽지 못해 원본을 복구용 사본으로 보관했습니다."
                }
            }
        }

        if let snapshot = loadedSnapshot {
            progress = snapshot.progress
            records = snapshot.records
            attempts = Array((snapshot.attempts ?? []).suffix(Self.attemptHistoryLimit))
            assistedReviewCounts = snapshot.assistedReviewCounts ?? [:]
            totalReviewCounts = snapshot.totalReviewCounts ?? [:]
            lastScheduledContentVersions = snapshot.lastScheduledContentVersions ?? [:]
            dailyGoal = max(1, snapshot.dailyGoal)
        } else {
            progress = [:]
            records = []
            attempts = []
            assistedReviewCounts = [:]
            totalReviewCounts = [:]
            lastScheduledContentVersions = [:]
            dailyGoal = 10
        }
        persistenceWarning = warning

        if requiresMigration {
            persistCurrentSnapshot()
        }
    }

    var dueCases: [StudyCaseUI] {
        let now = Date.now
        return catalog.filter { (progress[$0.id]?.dueAt ?? .distantPast) <= now }
    }

    var learnedCount: Int { progress.values.filter { $0.repetitions > 0 }.count }
    var assistedReviewCount: Int { assistedReviewCounts.values.reduce(0, +) }
    var totalReviewCount: Int { totalReviewCounts.values.reduce(0, +) }
    var attemptSummary: ReviewAttemptSummary {
        ReviewAttemptSummary(attempts: attempts)
    }
    var attemptSummaries: [String: ReviewAttemptSummary] {
        Dictionary(grouping: attempts, by: \.caseID)
            .mapValues { ReviewAttemptSummary(attempts: $0) }
    }
    var independentAttemptCount: Int { attemptSummary.independent }
    var assistedAttemptCount: Int { attemptSummary.assisted }
    var independentReviewRate: Double? {
        guard totalReviewCount > 0 else { return nil }
        return Double(totalReviewCount - assistedReviewCount) / Double(totalReviewCount)
    }

    func progressValue(for caseID: String) -> ReviewState {
        progress[caseID] ?? .new()
    }

    func attempts(for caseID: String) -> [ReviewAttempt] {
        attempts.filter { $0.caseID == caseID }
    }

    func attemptSummary(for caseID: String) -> ReviewAttemptSummary {
        ReviewAttemptSummary(attempts: attempts.lazy.filter { $0.caseID == caseID })
    }

    /// Persists objective attempt evidence and derives the scheduler grade.
    /// `.easy` is deliberately unreachable from this path.
    @discardableResult
    func recordAttempt(_ attempt: ReviewAttempt) -> Bool {
        guard !attempts.contains(attempt) else { return false }

        attempts.append(attempt)
        if attempts.count > Self.attemptHistoryLimit {
            attempts.removeFirst(attempts.count - Self.attemptHistoryLimit)
        }
        totalReviewCounts[attempt.caseID, default: 0] += 1
        if attempt.wasAssisted {
            assistedReviewCounts[attempt.caseID, default: 0] += 1
        }
        let currentProgress = progressValue(for: attempt.caseID)
        let isOutOfOrder = currentProgress.lastReviewedAt.map {
            attempt.timestamp < $0
        } ?? false
        if !isOutOfOrder {
            let schedulingBaseline: ReviewState
            if lastScheduledContentVersions[attempt.caseID] != attempt.contentVersion {
                schedulingBaseline = .new(dueAt: attempt.timestamp)
            } else {
                schedulingBaseline = currentProgress
            }
            progress[attempt.caseID] = ReviewScheduler.schedule(
                schedulingBaseline,
                rating: attempt.schedulerRating,
                reviewedAt: attempt.timestamp
            )
            lastScheduledContentVersions[attempt.caseID] = attempt.contentVersion
        }
        save()
        return true
    }

    /// Compatibility bridge for the legacy trainer. New training flows should
    /// submit `ReviewAttempt` evidence through `recordAttempt(_:)`.
    func rate(
        _ learningCase: StudyCaseUI,
        as rating: ReviewRating,
        assisted: Bool,
        now: Date = .now
    ) {
        let item = progressValue(for: learningCase.id)
        let effectiveRating: ReviewRating
        if assisted {
            effectiveRating = switch rating {
            case .easy: .good
            case .good: .hard
            case .hard: .hard
            case .again: .again
            }
        } else {
            effectiveRating = rating
        }
        totalReviewCounts[learningCase.id, default: 0] += 1
        if assisted {
            assistedReviewCounts[learningCase.id, default: 0] += 1
        }
        progress[learningCase.id] = ReviewScheduler.schedule(
            item,
            rating: effectiveRating,
            reviewedAt: now
        )
        save()
    }

    func addRecord(_ record: SolveRecord) {
        guard !records.contains(where: { $0.id == record.id }) else { return }
        records.append(record)
        if records.count > 500 { records.removeFirst(records.count - 500) }
        save()
    }

    func replaceRecords(_ newRecords: [SolveRecord]) {
        let normalizedRecords = Array(
            newRecords
                .sorted { $0.timestamp < $1.timestamp }
                .suffix(500)
        )
        guard records != normalizedRecords else { return }
        records = normalizedRecords
        save()
    }

    func dismissPersistenceWarning() {
        persistenceWarning = nil
    }

    /// Removes every locally persisted learning and solve artifact, including
    /// the recovery copy retained after a snapshot decoding failure.
    func deleteAllLocalData() {
        suppressesPersistence = true
        progress.removeAll()
        records.removeAll()
        attempts.removeAll()
        assistedReviewCounts.removeAll()
        totalReviewCounts.removeAll()
        lastScheduledContentVersions.removeAll()
        persistenceWarning = nil
        dailyGoal = 10
        suppressesPersistence = false

        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: recoveryKey)
    }

    private func save() {
        guard !suppressesPersistence else { return }
        let snapshot = Snapshot(
            progress: progress,
            records: records,
            dailyGoal: dailyGoal,
            assistedReviewCounts: assistedReviewCounts,
            totalReviewCounts: totalReviewCounts,
            attempts: attempts,
            lastScheduledContentVersions: lastScheduledContentVersions
        )
        let envelope = SnapshotEnvelope(
            schemaVersion: Self.currentSchemaVersion,
            payload: snapshot
        )
        do {
            defaults.set(try JSONEncoder().encode(envelope), forKey: storageKey)
        } catch {
            persistenceWarning = "학습 기록을 로컬에 저장하지 못했습니다. 앱을 종료하기 전에 다시 시도해 주세요."
        }
    }

    private func persistCurrentSnapshot() {
        let snapshot = Snapshot(
            progress: progress,
            records: records,
            dailyGoal: dailyGoal,
            assistedReviewCounts: assistedReviewCounts,
            totalReviewCounts: totalReviewCounts,
            attempts: attempts,
            lastScheduledContentVersions: lastScheduledContentVersions
        )
        let envelope = SnapshotEnvelope(
            schemaVersion: Self.currentSchemaVersion,
            payload: snapshot
        )
        do {
            defaults.set(try JSONEncoder().encode(envelope), forKey: storageKey)
        } catch {
            persistenceWarning = "학습 기록을 로컬에 저장하지 못했습니다. 앱을 종료하기 전에 다시 시도해 주세요."
        }
    }

    private enum PersistenceError: Error {
        case unsupportedSchema(Int)
    }
}
