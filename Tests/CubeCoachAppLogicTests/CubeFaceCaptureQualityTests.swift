import Testing
@testable import CubeCoachAppLogic

@Test func captureQualityAcceptsUniformCellsAndSmallLiveStillChanges() {
    let still = observation(
        samples: signature(red: 0.8, green: 0.15, blue: 0.05),
        dispersions: Array(repeating: 0.03, count: 9)
    )
    let live = signature(red: 0.72, green: 0.14, blue: 0.05)

    let report = CubeFaceCaptureQualityEvaluator.evaluate(
        observation: still,
        liveSignature: live,
        requiresLiveAgreement: true
    )

    #expect(report.canAcceptFace)
    #expect(report.unreliableCellIndices.isEmpty)
}

@Test func captureQualityRejectsMixedNoncenterColorPatches() {
    var dispersions = Array(repeating: 0.03, count: 9)
    dispersions[2] = 0.3

    let report = CubeFaceCaptureQualityEvaluator.evaluate(
        observation: observation(dispersions: dispersions),
        liveSignature: signature(),
        requiresLiveAgreement: true
    )

    #expect(!report.canAcceptFace)
    #expect(report.unreliableCellIndices == [2])
}

@Test func captureQualityAllowsModerateCenterDispersion() {
    var dispersions = Array(repeating: 0.03, count: 9)
    dispersions[4] = 0.28

    let report = CubeFaceCaptureQualityEvaluator.evaluate(
        observation: observation(dispersions: dispersions),
        liveSignature: signature(),
        requiresLiveAgreement: true
    )

    #expect(report.canAcceptFace)
}

@Test func captureQualityRejectsExcessiveCenterDispersion() {
    var dispersions = Array(repeating: 0.03, count: 9)
    dispersions[4] = 0.5

    let report = CubeFaceCaptureQualityEvaluator.evaluate(
        observation: observation(dispersions: dispersions),
        liveSignature: signature(),
        requiresLiveAgreement: true
    )

    #expect(!report.canAcceptFace)
    #expect(report.unreliableCellIndices == [4])
}

@Test func automaticCaptureRequiresLiveStillAgreement() {
    let report = CubeFaceCaptureQualityEvaluator.evaluate(
        observation: observation(),
        liveSignature: nil,
        requiresLiveAgreement: true
    )

    #expect(!report.canAcceptFace)
}

@Test func manualCaptureCanBeAcceptedWithoutALiveSignature() {
    let report = CubeFaceCaptureQualityEvaluator.evaluate(
        observation: observation(),
        liveSignature: nil,
        requiresLiveAgreement: false
    )

    #expect(report.canAcceptFace)
}

@Test func manualCaptureIgnoresLargeLiveStillMismatch() {
    let report = CubeFaceCaptureQualityEvaluator.evaluate(
        observation: observation(),
        liveSignature: signature(red: 0.85, green: 0.1, blue: 0.05),
        requiresLiveAgreement: false
    )

    #expect(report.canAcceptFace)
    #expect(report.unreliableCellIndices.isEmpty)
    #expect(report.liveStillMeanColorDifference == nil)
}

@Test func manualCaptureStillRejectsExcessiveCellDispersion() {
    var dispersions = Array(repeating: 0.03, count: 9)
    dispersions[3] = 0.5

    let report = CubeFaceCaptureQualityEvaluator.evaluate(
        observation: observation(dispersions: dispersions),
        liveSignature: signature(red: 0.85, green: 0.1, blue: 0.05),
        requiresLiveAgreement: false
    )

    #expect(!report.canAcceptFace)
    #expect(report.unreliableCellIndices == [3])
}

@Test func captureQualityRejectsLargeLiveStillCellChanges() {
    var live = signature()
    live[7] = CubeRGBSample(red: 0.05, green: 0.1, blue: 0.85)

    let report = CubeFaceCaptureQualityEvaluator.evaluate(
        observation: observation(),
        liveSignature: live,
        requiresLiveAgreement: true
    )

    #expect(!report.canAcceptFace)
    #expect(report.unreliableCellIndices == [7])
}

private func observation(
    samples: [CubeRGBSample] = signature(),
    dispersions: [Double] = Array(repeating: 0.03, count: 9)
) -> CubeSingleFaceObservation {
    CubeSingleFaceObservation(
        face: .front,
        samples: samples,
        cellColorDispersions: dispersions
    )
}

private func signature(
    red: Double = 0.1,
    green: Double = 0.8,
    blue: Double = 0.1
) -> [CubeRGBSample] {
    Array(
        repeating: CubeRGBSample(red: red, green: green, blue: blue),
        count: 9
    )
}
