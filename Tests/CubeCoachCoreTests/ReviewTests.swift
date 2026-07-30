import Foundation
import Testing
@testable import CubeCoachCore

@Test func schedulerIsDeterministicForEveryRating() {
    let now = Date(timeIntervalSince1970: 1_000)
    let initial = ReviewState.new(dueAt: now)
    let again = ReviewScheduler.schedule(initial, rating: .again, reviewedAt: now)
    let hard = ReviewScheduler.schedule(initial, rating: .hard, reviewedAt: now)
    let good = ReviewScheduler.schedule(initial, rating: .good, reviewedAt: now)
    let easy = ReviewScheduler.schedule(initial, rating: .easy, reviewedAt: now)
    #expect(again.dueAt == now.addingTimeInterval(600))
    #expect(hard.intervalDays == 1)
    #expect(good.intervalDays == 1)
    #expect(easy.intervalDays == 4)
    #expect(easy.easeFactor > good.easeFactor)
}
