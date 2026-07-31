public enum CubeAutoCaptureGuidance: Equatable, Sendable {
    case alignCube
    case holdSteady
    case improveSharpness
    case adjustExposure
    case stabilizing
    case ready
    case capturing
    case cooldown
    case changeScene
}

public struct CubeAutoCaptureGate: Equatable, Sendable {
    public struct Configuration: Equatable, Sendable {
        public var requiredRectangleCandidateCount: Int
        public var minimumAlignmentConfidence: Double
        public var minimumSharpness: Double
        public var acceptableExposure: ClosedRange<Double>
        public var requiredStableFrameCount: Int
        public var minimumStableDwell: Double
        public var cooldown: Double
        public var signatureChangeThreshold: Double
        public var maximumStableFrameInterval: Double
        public var maximumInterframeSignatureMeanChannelDifference: Double
        public var requiredSceneChangeEvidenceFrameCount: Int
        public var requiresCameraSettled: Bool

        public init(
            requiredRectangleCandidateCount: Int = 1,
            minimumAlignmentConfidence: Double = 0.50,
            minimumSharpness: Double = 0.32,
            acceptableExposure: ClosedRange<Double> = 0.15...0.95,
            requiredStableFrameCount: Int = 2,
            minimumStableDwell: Double = 0.18,
            cooldown: Double = 0.7,
            signatureChangeThreshold: Double = 0.12,
            maximumStableFrameInterval: Double = 0.5,
            maximumInterframeSignatureMeanChannelDifference: Double = 0.14,
            requiredSceneChangeEvidenceFrameCount: Int = 2,
            requiresCameraSettled: Bool = false
        ) {
            self.requiredRectangleCandidateCount = max(1, requiredRectangleCandidateCount)
            self.minimumAlignmentConfidence = Self.unitValue(
                minimumAlignmentConfidence,
                fallback: 0.50
            )
            self.minimumSharpness = Self.unitValue(minimumSharpness, fallback: 0.32)
            self.acceptableExposure = Self.unitRange(
                acceptableExposure,
                fallback: 0.15...0.95
            )
            self.requiredStableFrameCount = max(1, requiredStableFrameCount)
            self.minimumStableDwell = Self.nonnegativeFinite(
                minimumStableDwell,
                fallback: 0.18
            )
            self.cooldown = Self.nonnegativeFinite(cooldown, fallback: 0.7)
            self.signatureChangeThreshold = Self.positiveUnitValue(
                signatureChangeThreshold,
                fallback: 0.12
            )
            self.maximumStableFrameInterval = Self.positiveFinite(
                maximumStableFrameInterval,
                fallback: 0.5
            )
            self.maximumInterframeSignatureMeanChannelDifference = Self.positiveUnitValue(
                maximumInterframeSignatureMeanChannelDifference,
                fallback: 0.14
            )
            self.requiredSceneChangeEvidenceFrameCount = max(
                1,
                requiredSceneChangeEvidenceFrameCount
            )
            self.requiresCameraSettled = requiresCameraSettled
        }

        private static func unitValue(_ value: Double, fallback: Double) -> Double {
            guard value.isFinite, (0...1).contains(value) else { return fallback }
            return value
        }

        private static func unitRange(
            _ range: ClosedRange<Double>,
            fallback: ClosedRange<Double>
        ) -> ClosedRange<Double> {
            guard
                range.lowerBound.isFinite,
                range.upperBound.isFinite,
                (0...1).contains(range.lowerBound),
                (0...1).contains(range.upperBound)
            else {
                return fallback
            }
            return range
        }

        private static func nonnegativeFinite(_ value: Double, fallback: Double) -> Double {
            guard value.isFinite else { return fallback }
            return max(0, value)
        }

        private static func positiveFinite(_ value: Double, fallback: Double) -> Double {
            guard value.isFinite, value > 0 else { return fallback }
            return value
        }

        private static func positiveUnitValue(_ value: Double, fallback: Double) -> Double {
            guard value.isFinite, value > 0, value <= 1 else { return fallback }
            return value
        }
    }

    public struct Update: Equatable, Sendable {
        public let guidance: CubeAutoCaptureGuidance
        public let stableFrameCount: Int
        public let requiredStableFrameCount: Int
        public let shouldCapture: Bool

        public var stableFrameProgress: Double {
            min(1, Double(stableFrameCount) / Double(requiredStableFrameCount))
        }

        public init(
            guidance: CubeAutoCaptureGuidance,
            stableFrameCount: Int,
            requiredStableFrameCount: Int,
            shouldCapture: Bool
        ) {
            self.guidance = guidance
            self.stableFrameCount = stableFrameCount
            self.requiredStableFrameCount = requiredStableFrameCount
            self.shouldCapture = shouldCapture
        }
    }

    public let configuration: Configuration

    public private(set) var isCaptureInFlight = false
    public private(set) var stableFrameCount = 0

    private var stableSequenceStart: Double?
    private var lastAssessmentTimestamp: Double?
    private var cooldownStart: Double?
    private var captureSignature: [CubeRGBSample]?
    private var successfulCaptureSignature: [CubeRGBSample]?
    private var requiresSceneChange = false
    private var sceneChangeEvidenceFrameCount = 0
    private var lastStableFrameTimestamp: Double?
    private var lastStableFrameSignature: [CubeRGBSample]?

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    @discardableResult
    public mutating func evaluate(
        _ assessment: CubeLiveCaptureAssessment,
        canReserveCapture: Bool = true
    ) -> Update {
        if isCaptureInFlight {
            return update(guidance: .capturing)
        }

        guard canReserveCapture else {
            invalidateStability()
            return update(guidance: .capturing)
        }

        guard assessment.timestamp.isFinite, assessment.timestamp >= 0 else {
            resetStableSequence()
            sceneChangeEvidenceFrameCount = 0
            return update(guidance: .alignCube)
        }

        if timestampMovedBackward(to: assessment.timestamp) {
            resetStableSequence()
            sceneChangeEvidenceFrameCount = 0
        }
        lastAssessmentTimestamp = assessment.timestamp

        let alignmentIsValid = assessment.rectangleCandidateCount
            >= configuration.requiredRectangleCandidateCount
            && assessment.alignmentConfidence >= configuration.minimumAlignmentConfidence

        if isCoolingDown(at: assessment.timestamp) {
            resetStableSequence()
            sceneChangeEvidenceFrameCount = 0
            return update(guidance: .cooldown)
        }

        guard assessmentIsValid(assessment) else {
            resetStableSequence()
            sceneChangeEvidenceFrameCount = 0
            return update(guidance: .alignCube)
        }

        let sharpnessIsValid = assessment.sharpness >= configuration.minimumSharpness
        let exposureIsValid = configuration.acceptableExposure.contains(assessment.exposure)

        if requiresSceneChange {
            let isValidSettledEvidence = sharpnessIsValid
                && exposureIsValid
                && (!configuration.requiresCameraSettled || assessment.isCameraSettled)
            let showsAlignmentLoss = !alignmentIsValid
            let showsChangedSignature = alignmentIsValid
                && signatureChanged(to: assessment.signature)

            if isValidSettledEvidence && (showsAlignmentLoss || showsChangedSignature) {
                sceneChangeEvidenceFrameCount += 1
            } else {
                sceneChangeEvidenceFrameCount = 0
            }

            guard sceneChangeEvidenceFrameCount
                    >= configuration.requiredSceneChangeEvidenceFrameCount
            else {
                resetStableSequence()
                return update(guidance: .changeScene)
            }

            requiresSceneChange = false
            sceneChangeEvidenceFrameCount = 0
        }

        guard alignmentIsValid else {
            resetStableSequence()
            return update(guidance: .alignCube)
        }
        guard sharpnessIsValid else {
            resetStableSequence()
            return update(guidance: .improveSharpness)
        }
        guard exposureIsValid else {
            resetStableSequence()
            return update(guidance: .adjustExposure)
        }
        guard !configuration.requiresCameraSettled || assessment.isCameraSettled else {
            resetStableSequence()
            return update(guidance: .holdSteady)
        }

        if stableSequenceWasInterrupted(by: assessment) {
            resetStableSequence()
        }
        if stableSequenceStart == nil {
            stableSequenceStart = assessment.timestamp
        }
        stableFrameCount += 1
        lastStableFrameTimestamp = assessment.timestamp
        lastStableFrameSignature = assessment.signature

        let hasEnoughFrames = stableFrameCount >= configuration.requiredStableFrameCount
        let dwell = assessment.timestamp - (stableSequenceStart ?? assessment.timestamp)
        let hasEnoughDwell = dwell >= configuration.minimumStableDwell

        guard hasEnoughFrames && hasEnoughDwell else {
            return update(guidance: .stabilizing)
        }

        let captureUpdate = update(guidance: .ready, shouldCapture: true)
        isCaptureInFlight = true
        captureSignature = assessment.signature
        resetStableSequence()
        return captureUpdate
    }

    /// Marks a caller-initiated capture as in flight. Manual capture bypasses
    /// quality and cooldown checks, but never bypasses the single-flight guard.
    @discardableResult
    public mutating func beginManualCapture(
        at timestamp: Double,
        signature: [CubeRGBSample]? = nil
    ) -> Bool {
        guard !isCaptureInFlight,
              timestamp.isFinite,
              timestamp >= 0,
              signature.map(signatureIsValid) ?? true else {
            return false
        }
        isCaptureInFlight = true
        captureSignature = signature
        lastAssessmentTimestamp = timestamp
        resetStableSequence()
        return true
    }

    /// Completes either an automatic or manual capture. A successful capture
    /// must see alignment loss or a changed signature before auto-capture can
    /// arm again. A failed capture can retry unchanged after the cooldown.
    public mutating func completeCapture(
        succeeded: Bool,
        at timestamp: Double,
        signature: [CubeRGBSample]? = nil
    ) {
        guard isCaptureInFlight, timestamp.isFinite, timestamp >= 0 else {
            return
        }

        isCaptureInFlight = false
        cooldownStart = timestamp
        if succeeded {
            successfulCaptureSignature = if let captureSignature,
                                            signatureIsValid(captureSignature) {
                captureSignature
            } else if let signature, signatureIsValid(signature) {
                signature
            } else {
                nil
            }
            requiresSceneChange = true
            sceneChangeEvidenceFrameCount = 0
        } else {
            requiresSceneChange = false
            sceneChangeEvidenceFrameCount = 0
        }
        captureSignature = nil
        lastAssessmentTimestamp = timestamp
        resetStableSequence()
    }

    public mutating func reset() {
        self = Self(configuration: configuration)
    }

    /// Clears consecutive evidence after an analysis gap while preserving the
    /// capture, cooldown, and scene-change latch lifecycle.
    public mutating func invalidateStability() {
        resetStableSequence()
        sceneChangeEvidenceFrameCount = 0
    }

    private func update(
        guidance: CubeAutoCaptureGuidance,
        shouldCapture: Bool = false
    ) -> Update {
        Update(
            guidance: guidance,
            stableFrameCount: stableFrameCount,
            requiredStableFrameCount: configuration.requiredStableFrameCount,
            shouldCapture: shouldCapture
        )
    }

    private mutating func resetStableSequence() {
        stableFrameCount = 0
        stableSequenceStart = nil
        lastStableFrameTimestamp = nil
        lastStableFrameSignature = nil
    }

    private func timestampMovedBackward(to timestamp: Double) -> Bool {
        guard let lastAssessmentTimestamp else {
            return false
        }
        return timestamp < lastAssessmentTimestamp
    }

    private func isCoolingDown(at timestamp: Double) -> Bool {
        guard let cooldownStart else {
            return false
        }
        return timestamp - cooldownStart < configuration.cooldown
    }

    private func signatureChanged(to signature: [CubeRGBSample]) -> Bool {
        guard let previous = successfulCaptureSignature,
              signatureIsValid(previous),
              signatureIsValid(signature)
        else {
            return false
        }
        return meanChannelDifference(previous, signature)
            >= configuration.signatureChangeThreshold
    }

    private func stableSequenceWasInterrupted(
        by assessment: CubeLiveCaptureAssessment
    ) -> Bool {
        guard let lastStableFrameTimestamp,
              let lastStableFrameSignature
        else {
            return false
        }
        let interval = assessment.timestamp - lastStableFrameTimestamp
        return interval > configuration.maximumStableFrameInterval
            || meanChannelDifference(lastStableFrameSignature, assessment.signature)
                > configuration.maximumInterframeSignatureMeanChannelDifference
    }

    private func assessmentIsValid(_ assessment: CubeLiveCaptureAssessment) -> Bool {
        assessment.timestamp.isFinite
            && assessment.timestamp >= 0
            && assessment.rectangleCandidateCount >= 0
            && unitMetricIsValid(assessment.alignmentConfidence)
            && unitMetricIsValid(assessment.sharpness)
            && unitMetricIsValid(assessment.exposure)
            && signatureIsValid(assessment.signature)
    }

    private func unitMetricIsValid(_ value: Double) -> Bool {
        value.isFinite && (0...1).contains(value)
    }

    private func signatureIsValid(_ signature: [CubeRGBSample]) -> Bool {
        signature.count == 9 && signature.allSatisfy {
            unitMetricIsValid($0.red)
                && unitMetricIsValid($0.green)
                && unitMetricIsValid($0.blue)
        }
    }

    private func meanChannelDifference(
        _ lhs: [CubeRGBSample],
        _ rhs: [CubeRGBSample]
    ) -> Double {
        let totalDifference = zip(lhs, rhs).reduce(0.0) { result, pair in
            result
                + abs(pair.0.red - pair.1.red)
                + abs(pair.0.green - pair.1.green)
                + abs(pair.0.blue - pair.1.blue)
        }
        return totalDifference / Double(lhs.count * 3)
    }
}
