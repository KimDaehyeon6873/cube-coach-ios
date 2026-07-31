import Foundation

public struct CubeFaceCaptureQualityReport: Equatable, Sendable {
    public let unreliableCellIndices: [Int]
    public let liveStillMeanColorDifference: Double?
    public let canAcceptFace: Bool

    public init(
        unreliableCellIndices: [Int],
        liveStillMeanColorDifference: Double?,
        canAcceptFace: Bool
    ) {
        self.unreliableCellIndices = unreliableCellIndices
        self.liveStillMeanColorDifference = liveStillMeanColorDifference
        self.canAcceptFace = canAcceptFace
    }
}

public enum CubeFaceCaptureQualityEvaluator {
    public struct Configuration: Equatable, Sendable {
        public var maximumCellColorDispersion: Double
        public var maximumLiveStillMeanColorDifference: Double
        public var maximumPerCellLiveStillColorDifference: Double
        public var maximumCenterCellColorDispersion: Double

        public init(
            maximumCellColorDispersion: Double = 0.22,
            maximumLiveStillMeanColorDifference: Double = 0.18,
            maximumPerCellLiveStillColorDifference: Double = 0.28,
            maximumCenterCellColorDispersion: Double = 0.32
        ) {
            self.maximumCellColorDispersion = Self.unitValue(
                maximumCellColorDispersion,
                fallback: 0.22
            )
            self.maximumLiveStillMeanColorDifference = Self.unitValue(
                maximumLiveStillMeanColorDifference,
                fallback: 0.18
            )
            self.maximumPerCellLiveStillColorDifference = Self.unitValue(
                maximumPerCellLiveStillColorDifference,
                fallback: 0.28
            )
            self.maximumCenterCellColorDispersion = Self.unitValue(
                maximumCenterCellColorDispersion,
                fallback: 0.32
            )
        }

        private static func unitValue(_ value: Double, fallback: Double) -> Double {
            guard value.isFinite else { return fallback }
            return min(1, max(0, value))
        }
    }

    public static func evaluate(
        observation: CubeSingleFaceObservation,
        liveSignature: [CubeRGBSample]?,
        requiresLiveAgreement: Bool,
        configuration: Configuration = .init()
    ) -> CubeFaceCaptureQualityReport {
        guard samplesAreValid(observation.samples) else {
            return CubeFaceCaptureQualityReport(
                unreliableCellIndices: Array(0..<9),
                liveStillMeanColorDifference: nil,
                canAcceptFace: false
            )
        }

        var unreliableIndices = Set<Int>()
        if observation.cellColorDispersions.count == 9 {
            for (index, dispersion) in observation.cellColorDispersions.enumerated() {
                let maximumDispersion = index == 4
                    ? configuration.maximumCenterCellColorDispersion
                    : configuration.maximumCellColorDispersion
                if !dispersion.isFinite
                    || dispersion < 0
                    || dispersion > maximumDispersion {
                    unreliableIndices.insert(index)
                }
            }
        } else if !observation.cellColorDispersions.isEmpty {
            unreliableIndices.formUnion(0..<9)
        }

        var meanDifference: Double?
        var liveAgreementIsValid = true
        if requiresLiveAgreement {
            if let liveSignature, samplesAreValid(liveSignature) {
                let differences = zip(liveSignature, observation.samples).map { pair in
                    chromaticityDifference(pair.0, pair.1)
                }
                for (index, difference) in differences.enumerated()
                where difference > configuration.maximumPerCellLiveStillColorDifference {
                    unreliableIndices.insert(index)
                }
                let calculatedMeanDifference =
                    differences.reduce(0, +) / Double(differences.count)
                meanDifference = calculatedMeanDifference
                liveAgreementIsValid =
                    calculatedMeanDifference
                    <= configuration.maximumLiveStillMeanColorDifference
            } else {
                liveAgreementIsValid = false
            }
        }

        return CubeFaceCaptureQualityReport(
            unreliableCellIndices: unreliableIndices.sorted(),
            liveStillMeanColorDifference: meanDifference,
            canAcceptFace: unreliableIndices.isEmpty && liveAgreementIsValid
        )
    }

    private static func samplesAreValid(_ samples: [CubeRGBSample]) -> Bool {
        samples.count == 9 && samples.allSatisfy { sample in
            [sample.red, sample.green, sample.blue].allSatisfy {
                $0.isFinite && (0...1).contains($0)
            }
        }
    }

    private static func chromaticityDifference(
        _ lhs: CubeRGBSample,
        _ rhs: CubeRGBSample
    ) -> Double {
        let lhsChromaticity = chromaticity(lhs)
        let rhsChromaticity = chromaticity(rhs)
        let red = lhsChromaticity.red - rhsChromaticity.red
        let green = lhsChromaticity.green - rhsChromaticity.green
        let blue = lhsChromaticity.blue - rhsChromaticity.blue
        return sqrt(red * red + green * green + blue * blue) / sqrt(2)
    }

    private static func chromaticity(_ sample: CubeRGBSample) -> CubeRGBSample {
        let total = sample.red + sample.green + sample.blue
        guard total.isFinite, total > 0.03 else {
            return CubeRGBSample(red: 0, green: 0, blue: 0)
        }
        return CubeRGBSample(
            red: sample.red / total,
            green: sample.green / total,
            blue: sample.blue / total
        )
    }
}
