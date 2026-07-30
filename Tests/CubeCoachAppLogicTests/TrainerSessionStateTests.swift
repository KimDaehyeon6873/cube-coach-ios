@testable import CubeCoachAppLogic
import CubeCoachCore
import Foundation
import XCTest

final class TrainerSessionStateTests: XCTestCase {
    func testFiniteSessionAdvancesExactlyOncePerQueuedCase() {
        var session = TrainerSessionState(itemCount: 3)

        XCTAssertEqual(session.currentIndex, 0)
        XCTAssertTrue(session.advance(from: 0))
        XCTAssertEqual(session.currentIndex, 1)
        XCTAssertTrue(session.advance(from: 1))
        XCTAssertEqual(session.currentIndex, 2)
        XCTAssertTrue(session.advance(from: 2))

        XCTAssertTrue(session.isCompleted)
        XCTAssertEqual(session.reviewedCount, 3)
        XCTAssertNil(session.currentIndex)
        XCTAssertFalse(session.advance(from: 0))
        XCTAssertFalse(session.advance(from: 2))
        XCTAssertEqual(session.reviewedCount, 3)
    }

    func testStaleAdvanceCannotConsumeNextCase() {
        var session = TrainerSessionState(itemCount: 2)

        XCTAssertTrue(session.advance(from: 0))
        XCTAssertFalse(session.advance(from: 0))
        XCTAssertEqual(session.currentIndex, 1)
        XCTAssertEqual(session.reviewedCount, 1)
    }

    func testEmptySessionIsImmediatelyComplete() {
        var session = TrainerSessionState(itemCount: 0)

        XCTAssertTrue(session.isCompleted)
        XCTAssertNil(session.currentIndex)
        XCTAssertFalse(session.advance(from: 0))
        XCTAssertEqual(session.reviewedCount, 0)
    }

    @MainActor
    func testCompletedSessionCannotScheduleMoreThanOneRatingPerQueuedCase() {
        let cases = (0..<3).map { index in
            StudyCaseUI(
                id: "case-\(index)",
                title: "Case \(index)",
                recognition: "Recognition",
                answerTitle: "Algorithm",
                algorithm: "R U R'",
                hint: "Hint",
                level: "Test",
                family: "Test"
            )
        }
        let suite = "TrainerSessionStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = LearningProgressStore(defaults: defaults, catalog: cases)
        var session = TrainerSessionState(itemCount: cases.count)

        for attemptedIndex in [0, 1, 2, 0] {
            guard session.advance(from: attemptedIndex) else { continue }
            store.rate(
                cases[attemptedIndex],
                as: .good,
                assisted: false,
                now: Date(timeIntervalSince1970: Double(attemptedIndex))
            )
        }

        XCTAssertEqual(store.totalReviewCount, cases.count)
        XCTAssertEqual(store.totalReviewCounts, Dictionary(uniqueKeysWithValues: cases.map { ($0.id, 1) }))
        XCTAssertTrue(cases.allSatisfy { store.progressValue(for: $0.id).repetitions == 1 })
    }
}
