import Testing
@testable import CubeCoachAppLogic

@Test func capturesSixFacesInGuidedOrderThenEntersReview() {
    var flow = CubeScanCaptureFlow()

    #expect(CubeScanCaptureFlow.captureOrder == [
        .up, .front, .right, .down, .back, .left,
    ])

    for face in CubeScanCaptureFlow.captureOrder {
        #expect(flow.phase == .capture)
        #expect(flow.currentFace == face)
        #expect(flow.status(for: face) == .pending)
        flow.acceptCapture()
        #expect(flow.status(for: face) == .captured)
    }

    #expect(flow.phase == .review)
    #expect(flow.currentFace == nil)
    #expect(!flow.manualFallbackIsAvailable)
}

@Test func initialFailureIsRetriableAndRetainsPerFaceStatus() {
    var flow = CubeScanCaptureFlow()

    flow.recordCaptureFailure()

    #expect(flow.phase == .capture)
    #expect(flow.currentFace == .up)
    #expect(flow.didFailCurrentCapture)
    #expect(flow.status(for: .up) == .failed)
    #expect(flow.status(for: .front) == .pending)

    flow.acceptCapture()

    #expect(flow.status(for: .up) == .captured)
    #expect(flow.currentFace == .front)
    #expect(!flow.didFailCurrentCapture)
}

@Test func successfulRetakeReturnsToReviewAndOnlyUpdatesRequestedStatus() {
    var flow = completedFlow()
    let before = flow.captureStatuses

    let didBeginRetake = flow.beginRetake(face: .front)
    #expect(didBeginRetake)
    #expect(flow.currentFace == .front)
    #expect(flow.isRetaking)

    flow.acceptCapture()

    #expect(flow.phase == .review)
    #expect(flow.currentFace == nil)
    #expect(flow.captureStatuses == before)
}

@Test func failedOrCancelledRetakePreservesAcceptedCaptureStatuses() {
    var failedFlow = completedFlow()
    let before = failedFlow.captureStatuses
    failedFlow.beginRetake(face: .back)
    failedFlow.recordCaptureFailure()

    #expect(failedFlow.phase == .review)
    #expect(failedFlow.didFailCurrentCapture)
    #expect(failedFlow.captureStatuses == before)

    var cancelledFlow = completedFlow()
    cancelledFlow.beginRetake(face: .left)
    cancelledFlow.cancelCurrentCapture()

    #expect(cancelledFlow.phase == .review)
    #expect(!cancelledFlow.didFailCurrentCapture)
    #expect(cancelledFlow.captureStatuses == before)
}

@Test func manualReviewAndResetRestoreACompletelyFreshFlow() {
    var flow = CubeScanCaptureFlow()
    flow.acceptCapture()
    flow.startManualReview()
    #expect(flow.phase == .review)

    flow.reset()

    #expect(flow == CubeScanCaptureFlow())
    #expect(flow.currentFace == .up)
    #expect(flow.manualFallbackIsAvailable)
}

private func completedFlow() -> CubeScanCaptureFlow {
    var flow = CubeScanCaptureFlow()
    for _ in CubeScanCaptureFlow.captureOrder {
        flow.acceptCapture()
    }
    return flow
}
