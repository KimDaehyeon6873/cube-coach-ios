import Foundation

/// Classifies a complete cube scan while enforcing the physical invariant that
/// every center-defined color occurs exactly nine times. Centers are fixed to
/// their captured faces; the other 48 facelets are assigned globally to eight
/// remaining slots per color using a deterministic minimum-cost assignment.
public enum CubeBalancedFaceletClassifier {
    public enum ClassificationError: LocalizedError, Equatable, Sendable {
        case missingFace(CubeFace)
        case invalidSampleCount(face: CubeFace, actual: Int)
        case missingCenter(CubeFace)
        case indistinguishableCenters(first: CubeFace, second: CubeFace)

        public var errorDescription: String? {
            switch self {
            case let .missingFace(face):
                "\(face.rawValue) 면의 색상 표본이 없어요."
            case let .invalidSampleCount(face, actual):
                "\(face.rawValue) 면의 색상 표본은 9개여야 해요. 현재 \(actual)개예요."
            case let .missingCenter(face):
                "\(face.rawValue) 면의 중앙 색상 표본이 없어요."
            case let .indistinguishableCenters(first, second):
                "\(first.rawValue)면과 \(second.rawValue)면의 중앙 색상이 너무 비슷해요. 조명을 확인한 뒤 다시 촬영해 주세요."
            }
        }
    }

    public static func validateCenterSeparation(
        _ centers: [CubeFace: CubeRGBSample],
        minimumDistance: Double = 10,
        requiresCompleteSet: Bool = true
    ) throws {
        if requiresCompleteSet {
            for face in CubeFace.faceletOrder where centers[face] == nil {
                throw ClassificationError.missingCenter(face)
            }
        }

        let metric = PerceptualMetric(centers: centers)
        let availableFaces = CubeFace.faceletOrder.filter { centers[$0] != nil }
        for (firstIndex, first) in availableFaces.enumerated() {
            for second in availableFaces.dropFirst(firstIndex + 1) {
                guard let firstSample = centers[first] else { continue }
                if metric.distance(firstSample, to: second) < minimumDistance {
                    throw ClassificationError.indistinguishableCenters(first: first, second: second)
                }
            }
        }
    }

    public static func classify(
        gridsByFace: [CubeFace: [CubeRGBSample]],
        centers: [CubeFace: CubeRGBSample]
    ) throws -> [CubeFace: [CubeClassifiedFacelet]] {
        for face in CubeFace.faceletOrder {
            guard let samples = gridsByFace[face] else {
                throw ClassificationError.missingFace(face)
            }
            guard samples.count == 9 else {
                throw ClassificationError.invalidSampleCount(face: face, actual: samples.count)
            }
            guard centers[face] != nil else {
                throw ClassificationError.missingCenter(face)
            }
        }

        try validateCenterSeparation(centers)
        let metric = PerceptualMetric(centers: centers)
        let positions = CubeFace.faceletOrder.flatMap { face in
            (0..<9).compactMap { index in
                index == 4 ? nil : Position(face: face, index: index)
            }
        }
        let slotFaces = CubeFace.faceletOrder.flatMap { face in
            Array(repeating: face, count: 8)
        }
        let costs = positions.map { position in
            let sample = gridsByFace[position.face]![position.index]
            return slotFaces.map { metric.distance(sample, to: $0) }
        }
        let assignment = minimumCostAssignment(costs)

        var result: [CubeFace: [CubeClassifiedFacelet]] = [:]
        for face in CubeFace.faceletOrder {
            let samples = gridsByFace[face]!
            result[face] = samples.enumerated().map { index, sample in
                if index == 4 {
                    return CubeClassifiedFacelet(
                        colorFace: face,
                        confidence: metric.confidence(sample, assignedTo: face),
                        sample: sample
                    )
                }
                return CubeClassifiedFacelet(colorFace: face, confidence: 0, sample: sample)
            }
        }

        for (row, position) in positions.enumerated() {
            let assignedFace = slotFaces[assignment[row]]
            let sample = gridsByFace[position.face]![position.index]
            result[position.face]![position.index] = CubeClassifiedFacelet(
                colorFace: assignedFace,
                confidence: metric.confidence(sample, assignedTo: assignedFace),
                sample: sample
            )
        }
        return result
    }

    private struct Position {
        let face: CubeFace
        let index: Int
    }

    /// Hungarian algorithm for a square cost matrix. Iteration order and strict
    /// comparisons deliberately provide stable tie-breaking for equal colors.
    private static func minimumCostAssignment(_ costs: [[Double]]) -> [Int] {
        let count = costs.count
        guard count > 0 else { return [] }

        var rowPotential = Array(repeating: 0.0, count: count + 1)
        var columnPotential = Array(repeating: 0.0, count: count + 1)
        var matchedRow = Array(repeating: 0, count: count + 1)
        var predecessor = Array(repeating: 0, count: count + 1)

        for row in 1...count {
            matchedRow[0] = row
            var currentColumn = 0
            var minimumSlack = Array(repeating: Double.infinity, count: count + 1)
            var used = Array(repeating: false, count: count + 1)

            repeat {
                used[currentColumn] = true
                let currentRow = matchedRow[currentColumn]
                var delta = Double.infinity
                var nextColumn = 0
                for column in 1...count where !used[column] {
                    let reducedCost = costs[currentRow - 1][column - 1]
                        - rowPotential[currentRow]
                        - columnPotential[column]
                    if reducedCost < minimumSlack[column] {
                        minimumSlack[column] = reducedCost
                        predecessor[column] = currentColumn
                    }
                    if minimumSlack[column] < delta {
                        delta = minimumSlack[column]
                        nextColumn = column
                    }
                }
                for column in 0...count {
                    if used[column] {
                        rowPotential[matchedRow[column]] += delta
                        columnPotential[column] -= delta
                    } else {
                        minimumSlack[column] -= delta
                    }
                }
                currentColumn = nextColumn
            } while matchedRow[currentColumn] != 0

            repeat {
                let previousColumn = predecessor[currentColumn]
                matchedRow[currentColumn] = matchedRow[previousColumn]
                currentColumn = previousColumn
            } while currentColumn != 0
        }

        var result = Array(repeating: 0, count: count)
        for column in 1...count {
            result[matchedRow[column] - 1] = column - 1
        }
        return result
    }

    /// Matches `CubeCenterColorClassifier`: grey-world normalization followed
    /// by Euclidean CIE Lab distance to the six measured centers.
    private struct PerceptualMetric {
        private struct Lab {
            let l: Double
            let a: Double
            let b: Double
        }

        private let gains: CubeRGBSample
        private let prototypes: [CubeFace: Lab]

        init(centers: [CubeFace: CubeRGBSample]) {
            let samples = CubeFace.faceletOrder.compactMap { centers[$0] }
            let divisor = Double(max(1, samples.count))
            let mean = CubeRGBSample(
                red: samples.map(\.red).reduce(0, +) / divisor,
                green: samples.map(\.green).reduce(0, +) / divisor,
                blue: samples.map(\.blue).reduce(0, +) / divisor
            )
            let gray = max(0.000_001, (mean.red + mean.green + mean.blue) / 3)
            let channelGains = CubeRGBSample(
                red: gray / max(Self.finite(mean.red), 0.000_001),
                green: gray / max(Self.finite(mean.green), 0.000_001),
                blue: gray / max(Self.finite(mean.blue), 0.000_001)
            )
            gains = channelGains
            prototypes = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.compactMap { face in
                centers[face].map { (face, Self.lab(for: $0, gains: channelGains)) }
            })
        }

        func distance(_ sample: CubeRGBSample, to face: CubeFace) -> Double {
            guard let prototype = prototypes[face] else { return 1_000_000 }
            let target = Self.lab(for: sample, gains: gains)
            let dl = target.l - prototype.l
            let da = target.a - prototype.a
            let db = target.b - prototype.b
            return (dl * dl + da * da + db * db).squareRoot()
        }

        func confidence(_ sample: CubeRGBSample, assignedTo face: CubeFace) -> Double {
            let ranked = CubeFace.faceletOrder.map { candidate in
                (candidate, distance(sample, to: candidate))
            }.sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return faceOrder(lhs.0) < faceOrder(rhs.0)
                }
                return lhs.1 < rhs.1
            }
            guard let nearest = ranked.first else { return 0 }
            // A capacity-forced non-nearest assignment is intentionally marked
            // uncertain instead of presenting global consistency as recognition certainty.
            guard nearest.0 == face else { return 0 }
            let secondDistance = ranked.dropFirst().first?.1 ?? nearest.1
            guard secondDistance > 0.000_001 else { return 0 }
            return min(1, max(0, 1 - nearest.1 / secondDistance))
        }

        private func faceOrder(_ face: CubeFace) -> Int {
            CubeFace.faceletOrder.firstIndex(of: face) ?? Int.max
        }

        private static func finite(_ value: Double) -> Double {
            value.isFinite ? value : 0
        }

        private static func lab(for sample: CubeRGBSample, gains: CubeRGBSample) -> Lab {
            func linear(_ rawValue: Double) -> Double {
                let value = min(1, max(0, finite(rawValue)))
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            let r = linear(sample.red * gains.red)
            let g = linear(sample.green * gains.green)
            let b = linear(sample.blue * gains.blue)
            let x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
            let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
            let z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
            func pivot(_ value: Double) -> Double {
                value > 0.008856 ? pow(value, 1.0 / 3.0) : 7.787 * value + 16.0 / 116.0
            }
            let fx = pivot(x)
            let fy = pivot(y)
            let fz = pivot(z)
            return Lab(l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
        }
    }
}
