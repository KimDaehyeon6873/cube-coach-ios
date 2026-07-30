import Testing
@testable import CubeCoachAppLogic

@Test func readyCameraCaptureFailureCanCompleteBothPosesManually() {
    var flow = CubeScanCaptureFlow()

    // Camera availability does not gate the fallback: it is exposed by capture
    // phase, including while a ready camera remains usable after an error.
    #expect(flow.phase == .firstCorner)
    #expect(flow.manualFallbackIsAvailable)

    flow.recordCaptureFailure()
    #expect(flow.phase == .firstCorner)
    #expect(flow.didFailCurrentCapture)
    #expect(flow.manualFallbackIsAvailable)

    flow.acceptCapture()
    #expect(flow.phase == .oppositeCorner)
    #expect(!flow.didFailCurrentCapture)
    #expect(flow.manualFallbackIsAvailable)

    flow.acceptCapture()
    #expect(flow.phase == .review)
    #expect(!flow.manualFallbackIsAvailable)
}

@Test func resettingScanRestoresFirstPoseManualFallback() {
    var flow = CubeScanCaptureFlow(phase: .review)

    flow.reset()

    #expect(flow == CubeScanCaptureFlow())
    #expect(flow.manualFallbackIsAvailable)
}

@Test func choosingManualEntrySkipsBothCameraPoses() {
    var flow = CubeScanCaptureFlow()

    flow.startManualReview()

    #expect(flow.phase == .review)
    #expect(!flow.didFailCurrentCapture)
    #expect(!flow.manualFallbackIsAvailable)
}
