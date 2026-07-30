import Foundation

/// Tracks one finite pass through a snapshot of study cases.
///
/// Scheduling changes made while a session is in progress do not add, remove,
/// or repeat cases in that same session.
struct TrainerSessionState: Equatable, Sendable {
    let itemCount: Int
    private(set) var reviewedCount: Int

    init(itemCount: Int) {
        self.itemCount = max(0, itemCount)
        reviewedCount = 0
    }

    var currentIndex: Int? {
        reviewedCount < itemCount ? reviewedCount : nil
    }

    var isCompleted: Bool {
        currentIndex == nil
    }

    /// Consumes the currently displayed item exactly once.
    ///
    /// The expected index prevents a stale or duplicated UI action from
    /// rating another case after the session has already advanced.
    @discardableResult
    mutating func advance(from expectedIndex: Int) -> Bool {
        guard currentIndex == expectedIndex else { return false }
        reviewedCount += 1
        return true
    }
}
