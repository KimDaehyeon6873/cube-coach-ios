import Testing
@testable import CubeCoachAppLogic

@Test func autoCaptureRequiresBothConsecutiveFramesAndMinimumDwell() {
    var gate = makeGate(stableFrames: 3, dwell: 0.5)

    let first = gate.evaluate(assessment(at: 1))
    let second = gate.evaluate(assessment(at: 1.25))
    let third = gate.evaluate(assessment(at: 1.4))
    let fourth = gate.evaluate(assessment(at: 1.5))

    #expect(first.guidance == .stabilizing)
    #expect(first.stableFrameCount == 1)
    #expect(first.stableFrameProgress == 1.0 / 3.0)
    #expect(second.stableFrameCount == 2)
    #expect(!third.shouldCapture)
    #expect(third.stableFrameCount == 3)
    #expect(fourth.shouldCapture)
    #expect(fourth.guidance == .ready)
    #expect(gate.isCaptureInFlight)
}

@Test func qualityFailuresGiveSpecificGuidanceAndBreakConsecutiveStability() {
    var gate = makeGate(stableFrames: 2, dwell: 0)
    _ = gate.evaluate(assessment(at: 0))

    #expect(gate.evaluate(assessment(at: 0.1, rectangles: 0)).guidance == .alignCube)
    #expect(gate.evaluate(assessment(at: 0.2, alignment: 0.2)).guidance == .alignCube)
    #expect(gate.evaluate(assessment(at: 0.3, sharpness: 0.2)).guidance == .improveSharpness)
    #expect(gate.evaluate(assessment(at: 0.4, exposure: 0.05)).guidance == .adjustExposure)
    #expect(gate.evaluate(assessment(at: 0.5, settled: false)).guidance == .holdSteady)

    let restarted = gate.evaluate(assessment(at: 0.6))
    #expect(restarted.stableFrameCount == 1)
    #expect(!restarted.shouldCapture)
}

@Test func rectangleCandidateCountIsAMinimumTelemetryThreshold() {
    for count in [1, 9, 10] {
        var gate = makeGate(stableFrames: 1, dwell: 0)
        #expect(gate.evaluate(assessment(at: 0, rectangles: count)).shouldCapture)
    }
}

@Test func automaticAndManualCaptureAreSingleFlight() {
    var automatic = makeGate(stableFrames: 1, dwell: 0)
    #expect(automatic.evaluate(assessment(at: 0)).shouldCapture)

    let whileCapturing = automatic.evaluate(assessment(at: 10))
    #expect(whileCapturing.guidance == .capturing)
    #expect(!whileCapturing.shouldCapture)
    let automaticManualStart = automatic.beginManualCapture(at: 10)
    #expect(!automaticManualStart)

    var manual = makeGate(stableFrames: 1, dwell: 0)
    let manualStart = manual.beginManualCapture(at: 0, signature: signature(0.2))
    let duplicateManualStart = manual.beginManualCapture(at: 0.1)
    #expect(manualStart)
    #expect(!duplicateManualStart)
    #expect(manual.evaluate(assessment(at: 0.2)).guidance == .capturing)
}

@Test func successfulCaptureNeedsSceneChangeAfterCooldown() {
    var gate = makeGate(
        stableFrames: 2,
        dwell: 0,
        cooldown: 1,
        sceneChangeEvidenceFrames: 2
    )
    _ = gate.evaluate(assessment(at: 0, signature: signature(0.2)))
    #expect(gate.evaluate(assessment(at: 0.1, signature: signature(0.2))).shouldCapture)
    gate.completeCapture(succeeded: true, at: 0.2)

    #expect(gate.evaluate(assessment(at: 0.5, signature: signature(0.5))).guidance == .cooldown)
    #expect(gate.evaluate(assessment(at: 1.2, signature: signature(0.2))).guidance == .changeScene)

    #expect(gate.evaluate(assessment(at: 1.3, signature: signature(0.5))).guidance == .changeScene)
    let changed = gate.evaluate(assessment(at: 1.4, signature: signature(0.5)))
    #expect(changed.guidance == .stabilizing)
    #expect(changed.stableFrameCount == 1)
    #expect(gate.evaluate(assessment(at: 1.5, signature: signature(0.5))).shouldCapture)
}

@Test func cooldownDoesNotConsumeTransientMotionAsSceneChangeEvidence() {
    var gate = makeGate(
        stableFrames: 1,
        dwell: 0,
        cooldown: 0.5,
        sceneChangeEvidenceFrames: 2
    )
    #expect(gate.evaluate(assessment(at: 0)).shouldCapture)
    gate.completeCapture(succeeded: true, at: 0.1)

    #expect(gate.evaluate(assessment(at: 0.2, rectangles: 0)).guidance == .cooldown)
    #expect(gate.evaluate(assessment(at: 0.3, signature: signature(0.8))).guidance == .cooldown)
    #expect(
        gate.evaluate(
            assessment(at: 0.4, signature: Array(signature(0.8).prefix(8)))
        ).guidance == .cooldown
    )
    #expect(gate.evaluate(assessment(at: 0.6)).guidance == .changeScene)
    #expect(gate.evaluate(assessment(at: 0.7, signature: signature(0.8))).guidance == .changeScene)
    #expect(gate.evaluate(assessment(at: 0.8)).guidance == .changeScene)
}

@Test func sceneChangeRequiresConsecutiveValidSettledEvidence() {
    var gate = makeGate(
        stableFrames: 1,
        dwell: 0,
        cooldown: 0,
        sceneChangeEvidenceFrames: 2
    )
    #expect(gate.evaluate(assessment(at: 0)).shouldCapture)
    gate.completeCapture(succeeded: true, at: 0.1)

    #expect(gate.evaluate(assessment(at: 0.2, rectangles: 0)).guidance == .changeScene)
    #expect(
        gate.evaluate(assessment(at: 0.3, rectangles: 0, sharpness: 0.1)).guidance
            == .changeScene
    )
    #expect(gate.evaluate(assessment(at: 0.4, rectangles: 0)).guidance == .changeScene)
    #expect(gate.evaluate(assessment(at: 0.5, rectangles: 0)).guidance == .alignCube)
    #expect(gate.evaluate(assessment(at: 0.6)).shouldCapture)
}

@Test func unsettledOrInvalidChangedSignaturesDoNotRearmSceneChange() {
    var gate = makeGate(
        stableFrames: 1,
        dwell: 0,
        cooldown: 0,
        sceneChangeEvidenceFrames: 2
    )
    #expect(gate.evaluate(assessment(at: 0)).shouldCapture)
    gate.completeCapture(succeeded: true, at: 0.1)

    #expect(
        gate.evaluate(
            assessment(at: 0.2, settled: false, signature: signature(0.8))
        ).guidance == .changeScene
    )
    #expect(
        gate.evaluate(
            assessment(at: 0.3, signature: Array(signature(0.8).prefix(8)))
        ).guidance == .alignCube
    )
    #expect(
        gate.evaluate(assessment(at: 0.4, signature: signature(0.8))).guidance
            == .changeScene
    )
    #expect(gate.evaluate(assessment(at: 0.5, signature: signature(0.8))).shouldCapture)
}

@Test func failedCaptureRetriesAfterCooldownWithoutSceneChange() {
    var gate = makeGate(stableFrames: 1, dwell: 0, cooldown: 1)
    #expect(gate.evaluate(assessment(at: 0, signature: signature(0.2))).shouldCapture)
    gate.completeCapture(succeeded: false, at: 0.1)

    #expect(gate.evaluate(assessment(at: 1.09, signature: signature(0.2))).guidance == .cooldown)
    let retry = gate.evaluate(assessment(at: 1.1, signature: signature(0.2)))
    #expect(retry.shouldCapture)
}

@Test func failedManualCaptureAlsoRetriesAfterCooldown() {
    var gate = makeGate(stableFrames: 1, dwell: 0, cooldown: 0.5)
    let started = gate.beginManualCapture(at: 0, signature: signature(0.2))
    #expect(started)
    gate.completeCapture(succeeded: false, at: 0.1)

    #expect(gate.evaluate(assessment(at: 0.59)).guidance == .cooldown)
    #expect(gate.evaluate(assessment(at: 0.6)).shouldCapture)
}

@Test func manualCaptureRejectsInvalidEvidenceAndCanUseCapturedSignature() {
    var gate = makeGate(
        stableFrames: 1,
        dwell: 0,
        cooldown: 0,
        sceneChangeEvidenceFrames: 1
    )

    let invalidTimestampStarted = gate.beginManualCapture(at: .nan)
    let invalidSignatureStarted = gate.beginManualCapture(
        at: 0,
        signature: Array(signature(0.2).prefix(8))
    )
    let validCaptureStarted = gate.beginManualCapture(at: 0)
    #expect(!invalidTimestampStarted)
    #expect(!invalidSignatureStarted)
    #expect(validCaptureStarted)

    gate.completeCapture(
        succeeded: true,
        at: 0.1,
        signature: signature(0.2)
    )

    #expect(
        gate.evaluate(assessment(at: 0.2, signature: signature(0.5))).shouldCapture
    )
}

@Test func signatureChangeThresholdIsConfigurableAndInclusive() {
    var gate = makeGate(
        stableFrames: 1,
        dwell: 0,
        cooldown: 0,
        signatureChangeThreshold: 0.1,
        sceneChangeEvidenceFrames: 1
    )
    #expect(gate.evaluate(assessment(at: 0, signature: signature(0.2))).shouldCapture)
    gate.completeCapture(succeeded: true, at: 0.1)

    #expect(gate.evaluate(assessment(at: 0.2, signature: signature(0.29))).guidance == .changeScene)
    #expect(gate.evaluate(assessment(at: 0.3, signature: signature(0.31))).shouldCapture)
}

@Test func longFrameGapsAndInterframeSignatureChangesRestartStability() {
    var gapGate = makeGate(
        stableFrames: 2,
        dwell: 0,
        maximumStableFrameInterval: 0.2
    )
    _ = gapGate.evaluate(assessment(at: 0, signature: signature(0.2)))
    let afterGap = gapGate.evaluate(assessment(at: 0.21, signature: signature(0.2)))
    #expect(afterGap.stableFrameCount == 1)
    #expect(!afterGap.shouldCapture)
    #expect(gapGate.evaluate(assessment(at: 0.4, signature: signature(0.2))).shouldCapture)

    var signatureGate = makeGate(
        stableFrames: 2,
        dwell: 0,
        maximumInterframeSignatureMeanChannelDifference: 0.05
    )
    _ = signatureGate.evaluate(assessment(at: 0, signature: signature(0.2)))
    let changed = signatureGate.evaluate(assessment(at: 0.1, signature: signature(0.3)))
    #expect(changed.stableFrameCount == 1)
    #expect(!changed.shouldCapture)
    #expect(
        signatureGate.evaluate(assessment(at: 0.2, signature: signature(0.3))).shouldCapture
    )
}

@Test func unchangedSolvedFaceSignatureRemainsStableAcrossFrames() {
    var gate = makeGate(
        stableFrames: 3,
        dwell: 0,
        maximumInterframeSignatureMeanChannelDifference: 0.01
    )
    _ = gate.evaluate(assessment(at: 0, signature: solvedFaceSignature()))
    _ = gate.evaluate(assessment(at: 0.1, signature: solvedFaceSignature()))
    #expect(gate.evaluate(assessment(at: 0.2, signature: solvedFaceSignature())).shouldCapture)
}

@Test func backwardTimestampRestartsDwellAndStableFrameSequence() {
    var gate = makeGate(stableFrames: 2, dwell: 0.5)
    _ = gate.evaluate(assessment(at: 10))
    let backward = gate.evaluate(assessment(at: 9))

    #expect(backward.stableFrameCount == 1)
    #expect(!backward.shouldCapture)
    #expect(!gate.evaluate(assessment(at: 9.4)).shouldCapture)
    #expect(gate.evaluate(assessment(at: 9.5)).shouldCapture)
}

@Test func invalidAssessmentsFailClosedAndResetStability() {
    let invalidAssessments = [
        assessment(at: .nan),
        assessment(at: 0, rectangles: -1),
        assessment(at: 0, alignment: .infinity),
        assessment(at: 0, alignment: 1.1),
        assessment(at: 0, sharpness: -.infinity),
        assessment(at: 0, exposure: -0.1),
        assessment(at: 0, signature: Array(signature(0.2).prefix(8))),
        assessment(at: 0, signature: signature(.nan)),
        assessment(at: 0, signature: signature(1.1)),
    ]

    for invalid in invalidAssessments {
        var gate = makeGate(stableFrames: 2, dwell: 0)
        _ = gate.evaluate(assessment(at: 0))
        let result = gate.evaluate(invalid)
        #expect(!result.shouldCapture)
        #expect(result.stableFrameCount == 0)
        #expect(result.guidance == .alignCube)
    }
}

@Test func configurationSanitizesUnsafeValues() {
    let configuration = CubeAutoCaptureGate.Configuration(
        requiredRectangleCandidateCount: -1,
        minimumAlignmentConfidence: .nan,
        minimumSharpness: .infinity,
        acceptableExposure: -.infinity ... .infinity,
        minimumStableDwell: .nan,
        cooldown: .infinity,
        signatureChangeThreshold: 0,
        maximumStableFrameInterval: -.infinity,
        maximumInterframeSignatureMeanChannelDifference: 0,
        requiredSceneChangeEvidenceFrameCount: 0
    )

    #expect(configuration.requiredRectangleCandidateCount == 1)
    #expect(configuration.minimumAlignmentConfidence == 0.50)
    #expect(configuration.minimumSharpness == 0.32)
    #expect(configuration.acceptableExposure == 0.15...0.95)
    #expect(configuration.minimumStableDwell == 0.18)
    #expect(configuration.cooldown == 0.7)
    #expect(configuration.signatureChangeThreshold > 0)
    #expect(configuration.maximumStableFrameInterval > 0)
    #expect(configuration.maximumInterframeSignatureMeanChannelDifference > 0)
    #expect(configuration.requiredSceneChangeEvidenceFrameCount == 1)
    #expect(!configuration.requiresCameraSettled)
}

@Test func configurationFallsBackForFiniteOutOfDomainQualityThresholds() {
    let configuration = CubeAutoCaptureGate.Configuration(
        minimumAlignmentConfidence: -0.1,
        minimumSharpness: 1.1,
        acceptableExposure: -0.2...1.2,
        signatureChangeThreshold: 1.1,
        maximumInterframeSignatureMeanChannelDifference: 2
    )

    #expect(configuration.minimumAlignmentConfidence == 0.50)
    #expect(configuration.minimumSharpness == 0.32)
    #expect(configuration.acceptableExposure == 0.15...0.95)
    #expect(configuration.signatureChangeThreshold == 0.12)
    #expect(configuration.maximumInterframeSignatureMeanChannelDifference == 0.14)
}

@Test func defaultGateUsesImageEvidenceWithoutWaitingForCameraAdjustmentFlags() {
    var gate = CubeAutoCaptureGate(configuration: .init(
        requiredStableFrameCount: 1,
        minimumStableDwell: 0
    ))

    let result = gate.evaluate(assessment(at: 0, settled: false))

    #expect(result.shouldCapture)
}

@Test func defaultGateCanRearmNextFaceWhileCameraAdjustmentFlagsContinue() {
    var gate = CubeAutoCaptureGate(configuration: .init(
        requiredStableFrameCount: 1,
        minimumStableDwell: 0,
        cooldown: 0,
        requiredSceneChangeEvidenceFrameCount: 1
    ))
    #expect(gate.evaluate(assessment(at: 0, settled: false)).shouldCapture)
    gate.completeCapture(succeeded: true, at: 0.1)

    let nextFace = gate.evaluate(assessment(
        at: 0.2,
        settled: false,
        signature: signature(0.8)
    ))

    #expect(nextFace.shouldCapture)
}

@Test func invalidateStabilityPreservesCaptureLifecycleState() {
    var gate = makeGate(stableFrames: 2, dwell: 0, cooldown: 1)
    _ = gate.evaluate(assessment(at: 0))
    gate.invalidateStability()
    #expect(gate.stableFrameCount == 0)
    #expect(!gate.evaluate(assessment(at: 0.1)).shouldCapture)
    #expect(gate.evaluate(assessment(at: 0.2)).shouldCapture)

    gate.completeCapture(succeeded: true, at: 0.3)
    gate.invalidateStability()
    #expect(gate.evaluate(assessment(at: 0.4)).guidance == .cooldown)
}

@Test func invalidateStabilityBreaksConsecutiveSceneChangeEvidence() {
    var gate = makeGate(
        stableFrames: 1,
        dwell: 0,
        cooldown: 0,
        sceneChangeEvidenceFrames: 2
    )
    #expect(gate.evaluate(assessment(at: 0)).shouldCapture)
    gate.completeCapture(succeeded: true, at: 0.1)

    #expect(
        gate.evaluate(assessment(at: 0.2, signature: signature(0.8))).guidance
            == .changeScene
    )
    gate.invalidateStability()
    #expect(
        gate.evaluate(assessment(at: 0.3, signature: signature(0.8))).guidance
            == .changeScene
    )
    #expect(
        gate.evaluate(assessment(at: 0.4, signature: signature(0.8))).shouldCapture
    )
}

@Test func resetRestoresFreshStateWhileRetainingConfiguration() {
    let configuration = CubeAutoCaptureGate.Configuration(
        requiredStableFrameCount: 1,
        minimumStableDwell: 0,
        cooldown: 3
    )
    var gate = CubeAutoCaptureGate(configuration: configuration)
    #expect(gate.evaluate(assessment(at: 0)).shouldCapture)
    gate.completeCapture(succeeded: true, at: 0.1)

    gate.reset()

    #expect(gate == CubeAutoCaptureGate(configuration: configuration))
    #expect(gate.evaluate(assessment(at: 0.2)).shouldCapture)
}

@Test func unavailableCaptureDispatcherDoesNotReserveAfterLifecycleReset() {
    var gate = makeGate(stableFrames: 1, dwell: 0)
    #expect(gate.evaluate(assessment(at: 0)).shouldCapture)

    gate.reset()
    let blocked = gate.evaluate(
        assessment(at: 1),
        canReserveCapture: false
    )

    #expect(blocked.guidance == .capturing)
    #expect(!blocked.shouldCapture)
    #expect(!gate.isCaptureInFlight)
    #expect(gate.stableFrameCount == 0)

    let resumed = gate.evaluate(
        assessment(at: 2),
        canReserveCapture: true
    )
    #expect(resumed.shouldCapture)
    #expect(gate.isCaptureInFlight)
}

@Test func unavailableCaptureDispatcherBreaksAccumulatedStability() {
    var gate = makeGate(stableFrames: 2, dwell: 0)
    _ = gate.evaluate(assessment(at: 0), canReserveCapture: true)
    _ = gate.evaluate(assessment(at: 0.1), canReserveCapture: false)

    let restarted = gate.evaluate(
        assessment(at: 0.2),
        canReserveCapture: true
    )
    #expect(restarted.stableFrameCount == 1)
    #expect(!restarted.shouldCapture)
    #expect(
        gate.evaluate(
            assessment(at: 0.3),
            canReserveCapture: true
        ).shouldCapture
    )
}

private func makeGate(
    stableFrames: Int,
    dwell: Double,
    cooldown: Double = 1,
    signatureChangeThreshold: Double = 0.12,
    maximumStableFrameInterval: Double = 0.5,
    maximumInterframeSignatureMeanChannelDifference: Double = 0.08,
    sceneChangeEvidenceFrames: Int = 2
) -> CubeAutoCaptureGate {
    CubeAutoCaptureGate(configuration: .init(
        minimumAlignmentConfidence: 0.8,
        minimumSharpness: 0.6,
        acceptableExposure: 0.25...0.85,
        requiredStableFrameCount: stableFrames,
        minimumStableDwell: dwell,
        cooldown: cooldown,
        signatureChangeThreshold: signatureChangeThreshold,
        maximumStableFrameInterval: maximumStableFrameInterval,
        maximumInterframeSignatureMeanChannelDifference:
            maximumInterframeSignatureMeanChannelDifference,
        requiredSceneChangeEvidenceFrameCount: sceneChangeEvidenceFrames,
        requiresCameraSettled: true
    ))
}

private func assessment(
    at timestamp: Double,
    rectangles: Int = 1,
    alignment: Double = 0.9,
    sharpness: Double = 0.8,
    exposure: Double = 0.5,
    settled: Bool = true,
    signature: [CubeRGBSample] = signature(0.2)
) -> CubeLiveCaptureAssessment {
    CubeLiveCaptureAssessment(
        timestamp: timestamp,
        rectangleCandidateCount: rectangles,
        alignmentConfidence: alignment,
        sharpness: sharpness,
        exposure: exposure,
        isCameraSettled: settled,
        signature: signature
    )
}

private func signature(_ value: Double) -> [CubeRGBSample] {
    Array(repeating: .init(red: value, green: value, blue: value), count: 9)
}

private func solvedFaceSignature() -> [CubeRGBSample] {
    [
        .init(red: 0.9, green: 0.1, blue: 0.1),
        .init(red: 0.1, green: 0.9, blue: 0.1),
        .init(red: 0.1, green: 0.1, blue: 0.9),
        .init(red: 0.9, green: 0.9, blue: 0.1),
        .init(red: 0.9, green: 0.5, blue: 0.1),
        .init(red: 0.9, green: 0.9, blue: 0.9),
        .init(red: 0.2, green: 0.3, blue: 0.4),
        .init(red: 0.4, green: 0.3, blue: 0.2),
        .init(red: 0.5, green: 0.5, blue: 0.5),
    ]
}
