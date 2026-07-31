import Foundation

public enum CubeCameraAvailability: Equatable, Sendable {
    case idle
    case requestingPermission
    case ready
    case denied
    case unavailable(String)
    case failed(String)
}

public struct CubePhotoAnalysis: Equatable, Sendable {
    public let rectangleCandidateCount: Int
    public let confidence: Double
    /// Present only when capture was requested for a specific guided pose.
    /// This is guide-aligned sampling, not arbitrary cube detection.
    public let poseObservation: CubePoseObservation?
    /// Present only when capture was requested for one frontal face.
    public let singleFaceObservation: CubeSingleFaceObservation?

    public init(
        rectangleCandidateCount: Int,
        confidence: Double,
        poseObservation: CubePoseObservation? = nil,
        singleFaceObservation: CubeSingleFaceObservation? = nil
    ) {
        self.rectangleCandidateCount = rectangleCandidateCount
        self.confidence = confidence
        self.poseObservation = poseObservation
        self.singleFaceObservation = singleFaceObservation
    }
}

/// A platform-neutral summary of one live camera frame. The camera engine can
/// use these values to decide when to capture without coupling that policy to
/// Vision, AVFoundation, or image-buffer types.
public struct CubeLiveCaptureAssessment: Equatable, Sendable {
    public let timestamp: Double
    public let rectangleCandidateCount: Int
    public let alignmentConfidence: Double
    public let sharpness: Double
    public let exposure: Double
    public let isCameraSettled: Bool
    public let signature: [CubeRGBSample]

    public init(
        timestamp: Double,
        rectangleCandidateCount: Int,
        alignmentConfidence: Double,
        sharpness: Double,
        exposure: Double,
        isCameraSettled: Bool,
        signature: [CubeRGBSample]
    ) {
        self.timestamp = timestamp
        self.rectangleCandidateCount = rectangleCandidateCount
        self.alignmentConfidence = alignmentConfidence
        self.sharpness = sharpness
        self.exposure = exposure
        self.isCameraSettled = isCameraSettled
        self.signature = signature
    }
}

// MARK: - Two-corner cube capture domain

/// Singmaster face identifiers. Facelet exports always use the WCA-compatible
/// `U R F D L B` face order.
public enum CubeFace: String, CaseIterable, Codable, Hashable, Sendable {
    case up = "U"
    case right = "R"
    case front = "F"
    case down = "D"
    case left = "L"
    case back = "B"

    public static let faceletOrder: [CubeFace] = [.up, .right, .front, .down, .left, .back]
    /// Guided frontal capture order. Adjacent steps require only a quarter turn
    /// or half turn of the cube and keep the protocol easy to narrate.
    public static let singleFaceCaptureOrder: [CubeFace] = [.up, .front, .right, .down, .back, .left]
}

// MARK: - Six frontal-face capture domain

/// Orientation contract for a frontal capture. The named adjacent face must be
/// held above the photographed face; the resulting grid transform maps camera
/// row-major samples into the standard Singmaster diagram.
public struct CubeSingleFaceCaptureOrientation: Equatable, Codable, Sendable {
    public let face: CubeFace
    public let topEdgeFace: CubeFace
    public let transform: CubeFaceGridTransform
    public let instruction: String

    public init(
        face: CubeFace,
        topEdgeFace: CubeFace,
        transform: CubeFaceGridTransform = .identity,
        instruction: String
    ) {
        self.face = face
        self.topEdgeFace = topEdgeFace
        self.transform = transform
        self.instruction = instruction
    }

    /// Orientations match the standard URFDLB face diagrams, so no implicit
    /// mirroring or post-capture guesswork is required.
    public static func standard(for face: CubeFace) -> Self {
        let topEdgeFace: CubeFace = switch face {
        case .up: .back
        case .right, .front, .back, .left: .up
        case .down: .front
        }
        return Self(
            face: face,
            topEdgeFace: topEdgeFace,
            instruction: "\(face.rawValue) 면을 정면으로 두고 \(topEdgeFace.rawValue) 면이 위쪽에 오게 맞춰 주세요."
        )
    }
}

/// A centered square guide in portrait display coordinates. At the standard
/// 3:4 photo aspect ratio its pixel width and height are equal.
public struct CubeSingleFaceGuideLayout: Equatable, Codable, Sendable {
    public let quadrilateral: CubeNormalizedGuideQuadrilateral

    public init(quadrilateral: CubeNormalizedGuideQuadrilateral) {
        self.quadrilateral = quadrilateral
    }

    public static let portraitCentralSquare = CubeSingleFaceGuideLayout(
        quadrilateral: .init(
            topLeft: .init(x: 0.20, y: 0.275),
            topRight: .init(x: 0.80, y: 0.275),
            bottomRight: .init(x: 0.80, y: 0.725),
            bottomLeft: .init(x: 0.20, y: 0.725)
        )
    )
}

public struct CubeSingleFaceObservation: Equatable, Codable, Sendable {
    public let face: CubeFace
    public let samples: [CubeRGBSample]
    /// Per-cell robust RGB dispersion in `0...1`. Empty means the observation
    /// predates quality-aware sampling or was supplied by a synthetic fixture.
    public let cellColorDispersions: [Double]
    public let orientation: CubeSingleFaceCaptureOrientation

    public init(
        face: CubeFace,
        samples: [CubeRGBSample],
        cellColorDispersions: [Double] = [],
        orientation: CubeSingleFaceCaptureOrientation? = nil
    ) {
        self.face = face
        self.samples = samples
        self.cellColorDispersions = cellColorDispersions
        self.orientation = orientation ?? .standard(for: face)
    }
}

/// The three regions in the capture guide. A Vision implementation can rectify
/// each region independently before producing its nine samples.
public enum CubePoseFaceSlot: String, CaseIterable, Codable, Hashable, Sendable {
    case top
    case left
    case right
}

/// Portrait display-space point (`0,0` is top-left, `1,1` is bottom-right).
public struct CubeNormalizedGuidePoint: Equatable, Codable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A face boundary drawn by the capture guide. This is deliberately supplied
/// by the UI/capture protocol rather than inferred as an arbitrary cube.
public struct CubeNormalizedGuideQuadrilateral: Equatable, Codable, Sendable {
    public let topLeft: CubeNormalizedGuidePoint
    public let topRight: CubeNormalizedGuidePoint
    public let bottomRight: CubeNormalizedGuidePoint
    public let bottomLeft: CubeNormalizedGuidePoint

    public init(
        topLeft: CubeNormalizedGuidePoint,
        topRight: CubeNormalizedGuidePoint,
        bottomRight: CubeNormalizedGuidePoint,
        bottomLeft: CubeNormalizedGuidePoint
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }
}

/// Scores rectangle observations against the single-face capture guide.
///
/// A detector may report either the outside boundary of the face or its nine
/// sticker boundaries, so the better of those two interpretations is returned.
/// All calculations use normalized display coordinates and return `0...1`.
public struct CubeSingleFaceGuideMatch: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case outerBoundary
        case stickerGrid
    }

    public let alignmentConfidence: Double
    public let samplingQuadrilateral: CubeNormalizedGuideQuadrilateral
    public let source: Source

    public init(
        alignmentConfidence: Double,
        samplingQuadrilateral: CubeNormalizedGuideQuadrilateral,
        source: Source
    ) {
        self.alignmentConfidence = alignmentConfidence
        self.samplingQuadrilateral = samplingQuadrilateral
        self.source = source
    }
}

public enum CubeSingleFaceGuideAlignmentScorer {
    public static func score(
        _ candidates: [CubeNormalizedGuideQuadrilateral],
        guide: CubeSingleFaceGuideLayout = .portraitCentralSquare
    ) -> Double {
        match(candidates, guide: guide)?.alignmentConfidence ?? 0
    }

    /// Returns both readiness confidence and the detected region that should
    /// actually be sampled. This keeps a small framing margin from leaking
    /// background or neighboring stickers into a fixed guide crop.
    public static func match(
        _ candidates: [CubeNormalizedGuideQuadrilateral],
        guide: CubeSingleFaceGuideLayout = .portraitCentralSquare
    ) -> CubeSingleFaceGuideMatch? {
        guard !candidates.isEmpty else { return nil }

        guard isValid(guide.quadrilateral) else { return nil }
        let target = Bounds(guide.quadrilateral)
        let validCandidates = candidates.filter(isValid)
        guard !validCandidates.isEmpty else { return nil }

        let bestOuter = validCandidates
            .map { candidate in
                (
                    candidate,
                    outerAlignmentScore(
                        candidate,
                        guide: guide.quadrilateral,
                        targetBounds: target
                    )
                )
            }
            .max { lhs, rhs in lhs.1 < rhs.1 }
        let stickerMatch = stickerGridMatch(validCandidates, in: target)

        if let stickerMatch,
           stickerMatch.alignmentConfidence > (bestOuter?.1 ?? 0) {
            return stickerMatch
        }
        guard let bestOuter, bestOuter.1 > 0 else { return stickerMatch }
        return CubeSingleFaceGuideMatch(
            alignmentConfidence: min(1, max(0, bestOuter.1)),
            samplingQuadrilateral: bestOuter.0,
            source: .outerBoundary
        )
    }

    private static func outerAlignmentScore(
        _ candidate: CubeNormalizedGuideQuadrilateral,
        guide: CubeNormalizedGuideQuadrilateral,
        targetBounds: Bounds
    ) -> Double {
        let candidateBounds = Bounds(candidate)
        let diagonal = hypot(targetBounds.width, targetBounds.height)
        guard diagonal > 0 else { return 0 }

        let candidatePoints = [
            candidate.topLeft,
            candidate.topRight,
            candidate.bottomRight,
            candidate.bottomLeft,
        ]
        let guidePoints = [
            guide.topLeft,
            guide.topRight,
            guide.bottomRight,
            guide.bottomLeft,
        ]
        let meanNormalizedCornerDistance = zip(candidatePoints, guidePoints)
            .map { candidatePoint, guidePoint in
                hypot(
                    candidatePoint.x - guidePoint.x,
                    candidatePoint.y - guidePoint.y
                ) / diagonal
            }
            .reduce(0, +) / 4
        // A mean corner displacement of one quarter of the guide diagonal has
        // no outer-boundary confidence. Small perspective offsets retain most
        // of their score, while a diamond sharing the same bounds cannot pass
        // on axis-aligned IoU alone.
        let cornerScore = max(0, 1 - meanNormalizedCornerDistance / 0.25)
        return candidateBounds.intersectionOverUnion(with: targetBounds) * cornerScore
    }

    /// Vision rectangles are expected to be four distinct, normalized points
    /// ordered around a convex perimeter. Bounds alone would otherwise make a
    /// bow-tie or a quadrilateral containing NaN look like a valid rectangle.
    private static func isValid(_ quadrilateral: CubeNormalizedGuideQuadrilateral) -> Bool {
        let points = [
            quadrilateral.topLeft,
            quadrilateral.topRight,
            quadrilateral.bottomRight,
            quadrilateral.bottomLeft,
        ]
        guard points.allSatisfy({
            $0.x.isFinite && $0.y.isFinite &&
                (0...1).contains($0.x) && (0...1).contains($0.y)
        }) else {
            return false
        }

        var crossProducts: [Double] = []
        crossProducts.reserveCapacity(4)
        for index in points.indices {
            let first = points[index]
            let second = points[(index + 1) % points.count]
            let third = points[(index + 2) % points.count]
            let cross = (second.x - first.x) * (third.y - second.y)
                - (second.y - first.y) * (third.x - second.x)
            guard cross.isFinite, abs(cross) > 1e-12 else { return false }
            crossProducts.append(cross)
        }
        let isClockwise = crossProducts[0] < 0
        return crossProducts.allSatisfy { ($0 < 0) == isClockwise }
    }

    private static func stickerGridMatch(
        _ candidates: [CubeNormalizedGuideQuadrilateral],
        in guide: Bounds
    ) -> CubeSingleFaceGuideMatch? {
        let candidateBounds = candidates.map(Bounds.init)
        let cellWidth = guide.width / 3
        let cellHeight = guide.height / 3
        guard cellWidth > 0, cellHeight > 0 else { return nil }

        struct Match {
            let candidateIndex: Int
            let cellIndex: Int
            let score: Double
        }

        var matches: [Match] = []
        for (candidateIndex, candidate) in candidateBounds.enumerated() {
            guard candidate.width > 0, candidate.height > 0 else { continue }
            for row in 0..<3 {
                for column in 0..<3 {
                    let cellIndex = row * 3 + column
                    let expectedCenterX = guide.minX + (Double(column) + 0.5) * cellWidth
                    let expectedCenterY = guide.minY + (Double(row) + 0.5) * cellHeight
                    let offsetX = abs(candidate.centerX - expectedCenterX) / cellWidth
                    let offsetY = abs(candidate.centerY - expectedCenterY) / cellHeight
                    let centerScore = max(0, 1 - hypot(offsetX, offsetY) / 0.75)
                    let widthScore = min(candidate.width, cellWidth) / max(candidate.width, cellWidth)
                    let heightScore = min(candidate.height, cellHeight) / max(candidate.height, cellHeight)
                    let score = centerScore * (widthScore + heightScore) / 2
                    if score > 0 {
                        matches.append(Match(
                            candidateIndex: candidateIndex,
                            cellIndex: cellIndex,
                            score: score
                        ))
                    }
                }
            }
        }

        var usedCandidates = Set<Int>()
        var usedCells = Set<Int>()
        var selectedMatches: [Match] = []
        var total = 0.0
        for match in matches.sorted(by: { $0.score > $1.score }) {
            guard !usedCandidates.contains(match.candidateIndex),
                  !usedCells.contains(match.cellIndex) else { continue }
            usedCandidates.insert(match.candidateIndex)
            usedCells.insert(match.cellIndex)
            selectedMatches.append(match)
            total += match.score
        }
        guard usedCells.count >= 7 else { return nil }

        let requiredCornerCells = Set([0, 2, 6, 8])
        guard requiredCornerCells.isSubset(of: usedCells) else { return nil }

        let candidateIndexByCell = Dictionary(
            uniqueKeysWithValues: selectedMatches.map { ($0.cellIndex, $0.candidateIndex) }
        )
        guard let topLeftCandidate = candidateIndexByCell[0],
              let topRightCandidate = candidateIndexByCell[2],
              let bottomLeftCandidate = candidateIndexByCell[6],
              let bottomRightCandidate = candidateIndexByCell[8] else {
            return nil
        }
        let samplingQuadrilateral = CubeNormalizedGuideQuadrilateral(
            topLeft: candidates[topLeftCandidate].topLeft,
            topRight: candidates[topRightCandidate].topRight,
            bottomRight: candidates[bottomRightCandidate].bottomRight,
            bottomLeft: candidates[bottomLeftCandidate].bottomLeft
        )
        guard isValid(samplingQuadrilateral) else { return nil }
        return CubeSingleFaceGuideMatch(
            alignmentConfidence: min(1, max(0, total / 9)),
            samplingQuadrilateral: samplingQuadrilateral,
            source: .stickerGrid
        )
    }

    private struct Bounds {
        let minX: Double
        let minY: Double
        let maxX: Double
        let maxY: Double

        init(_ quadrilateral: CubeNormalizedGuideQuadrilateral) {
            let points = [
                quadrilateral.topLeft,
                quadrilateral.topRight,
                quadrilateral.bottomRight,
                quadrilateral.bottomLeft,
            ]
            minX = points.map(\.x).min() ?? 0
            minY = points.map(\.y).min() ?? 0
            maxX = points.map(\.x).max() ?? 0
            maxY = points.map(\.y).max() ?? 0
        }

        var width: Double { max(0, maxX - minX) }
        var height: Double { max(0, maxY - minY) }
        var centerX: Double { (minX + maxX) / 2 }
        var centerY: Double { (minY + maxY) / 2 }

        func intersectionOverUnion(with other: Bounds) -> Double {
            let intersectionWidth = max(0, min(maxX, other.maxX) - max(minX, other.minX))
            let intersectionHeight = max(0, min(maxY, other.maxY) - max(minY, other.minY))
            let intersectionArea = intersectionWidth * intersectionHeight
            let unionArea = width * height + other.width * other.height - intersectionArea
            return unionArea > 0 ? intersectionArea / unionArea : 0
        }
    }
}

public struct CubeGuidedFaceLayout: Equatable, Codable, Sendable {
    public let quadrilaterals: [CubePoseFaceSlot: CubeNormalizedGuideQuadrilateral]

    public init(quadrilaterals: [CubePoseFaceSlot: CubeNormalizedGuideQuadrilateral]) {
        self.quadrilaterals = quadrilaterals
    }

    /// Three diamond-like regions meeting at the guided visible corner.
    public static let portraitThreeFace = CubeGuidedFaceLayout(quadrilaterals: [
        .top: .init(
            topLeft: .init(x: 0.25, y: 0.31),
            topRight: .init(x: 0.50, y: 0.20),
            bottomRight: .init(x: 0.75, y: 0.31),
            bottomLeft: .init(x: 0.50, y: 0.43)
        ),
        .left: .init(
            topLeft: .init(x: 0.25, y: 0.31),
            topRight: .init(x: 0.50, y: 0.43),
            bottomRight: .init(x: 0.50, y: 0.72),
            bottomLeft: .init(x: 0.25, y: 0.58)
        ),
        .right: .init(
            topLeft: .init(x: 0.50, y: 0.43),
            topRight: .init(x: 0.75, y: 0.31),
            bottomRight: .init(x: 0.75, y: 0.58),
            bottomLeft: .init(x: 0.50, y: 0.72)
        ),
    ])
}

/// The supported two-photo protocol. The second pose is the geometrically
/// opposite corner of the first, so the pair covers all six centers exactly once.
public enum CubeCapturePose: String, CaseIterable, Codable, Hashable, Sendable {
    case upperFrontRight
    case downBackLeft

    public var opposite: CubeCapturePose {
        switch self {
        case .upperFrontRight: .downBackLeft
        case .downBackLeft: .upperFrontRight
        }
    }

    public func face(for slot: CubePoseFaceSlot) -> CubeFace {
        switch (self, slot) {
        case (.upperFrontRight, .top): .up
        case (.upperFrontRight, .left): .front
        case (.upperFrontRight, .right): .right
        case (.downBackLeft, .top): .down
        case (.downBackLeft, .left): .left
        case (.downBackLeft, .right): .back
        }
    }

    /// Converts each guide-facing grid into the standard Singmaster face
    /// diagram. These transforms describe the physical proper rotation between
    /// UFR and DBL; swapping DBL left/right would instead introduce a reflection.
    public func standardFaceletTransform(for slot: CubePoseFaceSlot) -> CubeFaceGridTransform {
        switch (self, slot) {
        case (.upperFrontRight, .top):
            CubeFaceGridTransform(clockwiseQuarterTurns: 3)
        case (.upperFrontRight, .left), (.upperFrontRight, .right):
            .identity
        case (.downBackLeft, .top):
            .identity
        case (.downBackLeft, .left), (.downBackLeft, .right):
            CubeFaceGridTransform(clockwiseQuarterTurns: 2)
        }
    }
}

/// sRGB sampled from a sticker region. Values are clamped to `0...1` by
/// the classifier, allowing fixtures to use either measured or synthetic data.
public struct CubeRGBSample: Equatable, Codable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Produces the representative color for one detected sticker cell from
    /// its pixels. Image code should omit border/highlight pixels before calling
    /// this method; an empty region intentionally returns black.
    public static func average<S: Sequence>(_ pixels: S) -> CubeRGBSample
    where S.Element == CubeRGBSample {
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var count = 0
        for pixel in pixels {
            red += pixel.red
            green += pixel.green
            blue += pixel.blue
            count += 1
        }
        guard count > 0 else {
            return CubeRGBSample(red: 0, green: 0, blue: 0)
        }
        let divisor = Double(count)
        return CubeRGBSample(red: red / divisor, green: green / divisor, blue: blue / divisor)
    }

    /// Coordinate-wise median rejects isolated white glare and dark border
    /// leakage without requiring a camera-specific brightness threshold.
    public static func robustRepresentative<S: Sequence>(_ pixels: S) -> CubeRGBSample
    where S.Element == CubeRGBSample {
        let values = Array(pixels)
        guard !values.isEmpty else {
            return CubeRGBSample(red: 0, green: 0, blue: 0)
        }
        func median(_ channel: (CubeRGBSample) -> Double) -> Double {
            let sorted = values.map(channel).sorted()
            let middle = sorted.count / 2
            if sorted.count.isMultiple(of: 2) {
                return (sorted[middle - 1] + sorted[middle]) / 2
            }
            return sorted[middle]
        }
        return CubeRGBSample(
            red: median(\.red),
            green: median(\.green),
            blue: median(\.blue)
        )
    }
}

/// Pixel data after Vision (or another detector) has perspective-rectified one
/// visible cube face. Keeping this type platform-neutral makes sampling fixtures
/// independent of Core Image and AVFoundation.
public struct CubeRectifiedFaceImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [CubeRGBSample]

    public init(width: Int, height: Int, pixels: [CubeRGBSample]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }
}

public struct CubeLiveFrameQuality: Equatable, Sendable {
    /// Mean Rec. 709 luminance in `0...1`.
    public let exposure: Double
    /// Resolution-stable focus score based on the strongest Sobel gradients.
    public let sharpness: Double
    /// Row-major robust representative colors for the nine guide cells.
    public let signature: [CubeRGBSample]

    public init(exposure: Double, sharpness: Double, signature: [CubeRGBSample]) {
        self.exposure = exposure
        self.sharpness = sharpness
        self.signature = signature
    }
}

public enum CubeLiveFrameQualityAnalysisError: Error, Equatable, Sendable {
    case invalidPixel(index: Int)
}

/// Computes deterministic live-frame quality metrics without platform image
/// frameworks. Invalid RGB input fails closed rather than being silently
/// clamped into a plausible exposure or focus score.
public enum CubeLiveFrameQualityAnalyzer {
    public static func analyze(_ image: CubeRectifiedFaceImage) throws -> CubeLiveFrameQuality {
        if let invalidIndex = image.pixels.firstIndex(where: { pixel in
            !pixel.red.isFinite || !pixel.green.isFinite || !pixel.blue.isFinite ||
                !(0...1).contains(pixel.red) ||
                !(0...1).contains(pixel.green) ||
                !(0...1).contains(pixel.blue)
        }) {
            throw CubeLiveFrameQualityAnalysisError.invalidPixel(index: invalidIndex)
        }
        let signature = try CubeFaceGridSampler.samples(from: image)
        let luminances = image.pixels.map(luminance)
        let exposure = luminances.reduce(0, +) / Double(luminances.count)

        let sharpness = focusScore(
            pixels: image.pixels,
            width: image.width,
            height: image.height
        )
        return CubeLiveFrameQuality(
            exposure: exposure,
            sharpness: sharpness,
            signature: signature
        )
    }

    /// A global mean gradient is diluted as resolution grows because sticker
    /// seams occupy a smaller fraction of the image. Averaging the strongest
    /// decile of actual Sobel responses instead measures edge definition, so
    /// the same physical face has a comparable score at different resolutions.
    private static func focusScore(
        pixels: [CubeRGBSample],
        width: Int,
        height: Int
    ) -> Double {
        guard width >= 3, height >= 3 else { return 0 }

        let channels = [
            pixels.map(\.red),
            pixels.map(\.green),
            pixels.map(\.blue),
        ]
        var gradients: [Double] = []
        gradients.reserveCapacity((width - 2) * (height - 2))
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                // Using the strongest color-channel edge avoids rating a
                // sharply focused saturated red or blue sticker as soft merely
                // because its Rec. 709 luminance is close to the dark seam.
                var normalizedMagnitude = 0.0
                for channel in channels {
                    let topLeft = channel[(y - 1) * width + x - 1]
                    let top = channel[(y - 1) * width + x]
                    let topRight = channel[(y - 1) * width + x + 1]
                    let left = channel[y * width + x - 1]
                    let right = channel[y * width + x + 1]
                    let bottomLeft = channel[(y + 1) * width + x - 1]
                    let bottom = channel[(y + 1) * width + x]
                    let bottomRight = channel[(y + 1) * width + x + 1]
                    let gradientX = -topLeft + topRight - 2 * left + 2 * right
                        - bottomLeft + bottomRight
                    let gradientY = -topLeft - 2 * top - topRight
                        + bottomLeft + 2 * bottom + bottomRight
                    normalizedMagnitude = max(
                        normalizedMagnitude,
                        min(1, hypot(gradientX, gradientY) / 4)
                    )
                }
                if normalizedMagnitude > 1e-9 {
                    gradients.append(normalizedMagnitude)
                }
            }
        }
        guard !gradients.isEmpty else { return 0 }

        gradients.sort(by: >)
        let strongestCount = max(1, Int(ceil(Double(gradients.count) * 0.1)))
        let score = gradients.prefix(strongestCount).reduce(0, +) / Double(strongestCount)
        return min(1, max(0, score))
    }

    private static func luminance(_ pixel: CubeRGBSample) -> Double {
        0.2126 * pixel.red + 0.7152 * pixel.green + 0.0722 * pixel.blue
    }
}

public enum CubeFaceGridSamplingError: Error, Equatable, Sendable {
    case invalidDimensions(width: Int, height: Int, pixelCount: Int)
    case faceTooSmall(width: Int, height: Int)
}

public struct CubeStickerColorMeasurement: Equatable, Sendable {
    public let sample: CubeRGBSample
    /// 75th-percentile normalized RGB distance from the representative color.
    public let dispersion: Double

    public init(sample: CubeRGBSample, dispersion: Double) {
        self.sample = sample
        self.dispersion = min(1, max(0, dispersion))
    }
}

/// Splits a rectified face into row-major 3×3 cells and takes a robust
/// representative of each inset interior region.
public enum CubeFaceGridSampler {
    public static func samples(
        from image: CubeRectifiedFaceImage,
        cellInsetFraction: Double = 0.30
    ) throws -> [CubeRGBSample] {
        try measurements(
            from: image,
            cellInsetFraction: cellInsetFraction
        ).map(\.sample)
    }

    public static func measurements(
        from image: CubeRectifiedFaceImage,
        cellInsetFraction: Double = 0.30
    ) throws -> [CubeStickerColorMeasurement] {
        guard image.width > 0,
              image.height > 0,
              image.pixels.count == image.width * image.height else {
            throw CubeFaceGridSamplingError.invalidDimensions(
                width: image.width,
                height: image.height,
                pixelCount: image.pixels.count
            )
        }
        guard image.width >= 6, image.height >= 6 else {
            throw CubeFaceGridSamplingError.faceTooSmall(width: image.width, height: image.height)
        }

        let insetFraction = min(0.45, max(0, cellInsetFraction))
        var result: [CubeStickerColorMeasurement] = []
        result.reserveCapacity(9)
        for row in 0..<3 {
            let outerY0 = row * image.height / 3
            let outerY1 = (row + 1) * image.height / 3
            for column in 0..<3 {
                let cellIndex = row * 3 + column
                let outerX0 = column * image.width / 3
                let outerX1 = (column + 1) * image.width / 3
                let insetX = Int((Double(outerX1 - outerX0) * insetFraction).rounded(.down))
                let insetY = Int((Double(outerY1 - outerY0) * insetFraction).rounded(.down))
                let x0 = min(outerX1 - 1, outerX0 + insetX)
                let x1 = max(x0 + 1, outerX1 - insetX)
                let y0 = min(outerY1 - 1, outerY0 + insetY)
                let y1 = max(y0 + 1, outerY1 - insetY)
                var pixels: [CubeRGBSample] = []
                if cellIndex == 4 {
                    // Center stickers commonly carry a logo. Four compact,
                    // off-center interior patches avoid it while remaining
                    // safely clear of sticker seams.
                    let cellWidth = outerX1 - outerX0
                    let cellHeight = outerY1 - outerY0
                    let horizontalBands = [
                        normalizedRange(0.15, 0.35, origin: outerX0, length: cellWidth),
                        normalizedRange(0.65, 0.85, origin: outerX0, length: cellWidth),
                    ]
                    let verticalBands = [
                        normalizedRange(0.15, 0.35, origin: outerY0, length: cellHeight),
                        normalizedRange(0.65, 0.85, origin: outerY0, length: cellHeight),
                    ]
                    pixels.reserveCapacity(
                        horizontalBands.reduce(0) { $0 + $1.count } *
                            verticalBands.reduce(0) { $0 + $1.count }
                    )
                    for verticalBand in verticalBands {
                        for horizontalBand in horizontalBands {
                            for y in verticalBand {
                                for x in horizontalBand {
                                    pixels.append(image.pixels[y * image.width + x])
                                }
                            }
                        }
                    }
                } else {
                    pixels.reserveCapacity((x1 - x0) * (y1 - y0))
                    for y in y0..<y1 {
                        for x in x0..<x1 {
                            pixels.append(image.pixels[y * image.width + x])
                        }
                    }
                }
                result.append(measurement(of: pixels))
            }
        }
        return result
    }

    private static func normalizedRange(
        _ lowerFraction: Double,
        _ upperFraction: Double,
        origin: Int,
        length: Int
    ) -> Range<Int> {
        let lower = origin + min(
            length - 1,
            Int((Double(length) * lowerFraction).rounded(.down))
        )
        let upper = origin + min(
            length,
            max(lower - origin + 1, Int((Double(length) * upperFraction).rounded(.up)))
        )
        return lower..<upper
    }

    private static func measurement(
        of pixels: [CubeRGBSample]
    ) -> CubeStickerColorMeasurement {
        let representative = CubeRGBSample.robustRepresentative(pixels)
        let distances = pixels.map { pixel in
            let red = pixel.red - representative.red
            let green = pixel.green - representative.green
            let blue = pixel.blue - representative.blue
            return sqrt(red * red + green * green + blue * blue) / sqrt(3)
        }.sorted()
        let percentileIndex = min(
            distances.count - 1,
            Int((Double(distances.count - 1) * 0.75).rounded(.up))
        )
        return CubeStickerColorMeasurement(
            sample: representative,
            dispersion: distances[percentileIndex]
        )
    }
}

/// Orientation of a rectified 3×3 grid relative to the standard face diagram.
/// Mirroring is applied first, followed by clockwise quarter turns.
public struct CubeFaceGridTransform: Equatable, Codable, Sendable {
    public let clockwiseQuarterTurns: Int
    public let isMirrored: Bool

    public init(clockwiseQuarterTurns: Int = 0, isMirrored: Bool = false) {
        self.clockwiseQuarterTurns = ((clockwiseQuarterTurns % 4) + 4) % 4
        self.isMirrored = isMirrored
    }

    public static let identity = CubeFaceGridTransform()

    public func standardIndex(forSourceIndex sourceIndex: Int) -> Int {
        precondition((0..<9).contains(sourceIndex))
        var row = sourceIndex / 3
        var column = sourceIndex % 3
        if isMirrored { column = 2 - column }
        for _ in 0..<clockwiseQuarterTurns {
            (row, column) = (column, 2 - row)
        }
        return row * 3 + column
    }
}

public struct CubeFaceGridSamples: Equatable, Codable, Sendable {
    public let slot: CubePoseFaceSlot
    public let samples: [CubeRGBSample]
    public let transform: CubeFaceGridTransform

    public init(
        slot: CubePoseFaceSlot,
        samples: [CubeRGBSample],
        transform: CubeFaceGridTransform = .identity
    ) {
        self.slot = slot
        self.samples = samples
        self.transform = transform
    }
}

public struct CubePoseObservation: Equatable, Codable, Sendable {
    public let pose: CubeCapturePose
    public let faces: [CubeFaceGridSamples]

    public init(pose: CubeCapturePose, faces: [CubeFaceGridSamples]) {
        self.pose = pose
        self.faces = faces
    }
}

public struct CubeClassifiedFacelet: Equatable, Codable, Sendable {
    /// The center face whose measured color is the nearest match.
    public let colorFace: CubeFace
    /// `0...1`; relative distance margin between the best and second center.
    public let confidence: Double
    public let sample: CubeRGBSample

    public init(colorFace: CubeFace, confidence: Double, sample: CubeRGBSample) {
        self.colorFace = colorFace
        self.confidence = confidence
        self.sample = sample
    }
}

public struct CubeFaceletScan: Equatable, Sendable {
    public let faceletsByFace: [CubeFace: [CubeClassifiedFacelet]]

    public init(faceletsByFace: [CubeFace: [CubeClassifiedFacelet]]) {
        self.faceletsByFace = faceletsByFace
    }

    public var faceletCount: Int {
        faceletsByFace.values.reduce(0) { $0 + $1.count }
    }

    /// Interface for the Core cubie/parity validator. Each character identifies
    /// the center-face color occupying that position, in URFDLB order.
    public var faceletStringURFDLB: String {
        CubeFace.faceletOrder.flatMap { face in
            faceletsByFace[face, default: []].map(\.colorFace.rawValue)
        }.joined()
    }

    public var minimumConfidence: Double {
        faceletsByFace.values.flatMap { $0 }.map(\.confidence).min() ?? 0
    }
}

public enum CubeFaceletReconstructionError: Error, Equatable, Sendable {
    case missingPose(CubeCapturePose)
    case duplicatePose(CubeCapturePose)
    case missingSlot(pose: CubeCapturePose, slot: CubePoseFaceSlot)
    case duplicateSlot(pose: CubeCapturePose, slot: CubePoseFaceSlot)
    case invalidSampleCount(pose: CubeCapturePose, slot: CubePoseFaceSlot, actual: Int)
    case missingFace(CubeFace)
    case duplicateFace(CubeFace)
    case invalidSingleFaceSampleCount(face: CubeFace, actual: Int)
    case mismatchedSingleFaceOrientation(observation: CubeFace, orientation: CubeFace)
}

/// Reconstructs 54 standardized facelets from the two opposite-corner captures.
/// This layer is independent of AVFoundation/Vision and can be tested with RGB
/// fixtures. Cubie legality is intentionally delegated through `faceletStringURFDLB`.
public enum CubeFaceletReconstructor {
    public static func reconstruct(observations: [CubePoseObservation]) throws -> CubeFaceletScan {
        let observationsByPose = try validatedObservations(observations)
        let gridsByFace = try standardizedGrids(observationsByPose)
        let centers = Dictionary(uniqueKeysWithValues: try CubeFace.allCases.map { face in
            guard let center = gridsByFace[face]?[4] else {
                throw CubeFaceletReconstructionError.missingFace(face)
            }
            return (face, center)
        })
        return CubeFaceletScan(faceletsByFace: try CubeBalancedFaceletClassifier.classify(
            gridsByFace: gridsByFace,
            centers: centers
        ))
    }

    /// Reconstructs from six frontal captures. Repeated captures of a face are
    /// accepted and fused deterministically with a per-channel median.
    public static func reconstruct(
        observations: [CubeSingleFaceObservation]
    ) throws -> CubeFaceletScan {
        var gridsByFace: [CubeFace: [[CubeRGBSample]]] = [:]
        for observation in observations {
            guard observation.orientation.face == observation.face else {
                throw CubeFaceletReconstructionError.mismatchedSingleFaceOrientation(
                    observation: observation.face,
                    orientation: observation.orientation.face
                )
            }
            guard observation.samples.count == 9 else {
                throw CubeFaceletReconstructionError.invalidSingleFaceSampleCount(
                    face: observation.face,
                    actual: observation.samples.count
                )
            }
            var standardized = Array(
                repeating: CubeRGBSample(red: 0, green: 0, blue: 0),
                count: 9
            )
            for (sourceIndex, sample) in observation.samples.enumerated() {
                standardized[
                    observation.orientation.transform.standardIndex(forSourceIndex: sourceIndex)
                ] = sample
            }
            gridsByFace[observation.face, default: []].append(standardized)
        }

        var fusedByFace: [CubeFace: [CubeRGBSample]] = [:]
        for face in CubeFace.allCases {
            guard let grids = gridsByFace[face], !grids.isEmpty else {
                throw CubeFaceletReconstructionError.missingFace(face)
            }
            fusedByFace[face] = (0..<9).map { index in
                CubeRGBSample.robustRepresentative(grids.map { $0[index] })
            }
        }
        return try classify(gridsByFace: fusedByFace)
    }

    private static func classify(
        gridsByFace: [CubeFace: [CubeRGBSample]]
    ) throws -> CubeFaceletScan {
        let centers = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.compactMap { face in
            gridsByFace[face].map { (face, $0[4]) }
        })
        return CubeFaceletScan(faceletsByFace: try CubeBalancedFaceletClassifier.classify(
            gridsByFace: gridsByFace,
            centers: centers
        ))
    }

    private static func validatedObservations(
        _ observations: [CubePoseObservation]
    ) throws -> [CubeCapturePose: CubePoseObservation] {
        var result: [CubeCapturePose: CubePoseObservation] = [:]
        for observation in observations {
            guard result[observation.pose] == nil else {
                throw CubeFaceletReconstructionError.duplicatePose(observation.pose)
            }
            result[observation.pose] = observation
        }
        for pose in CubeCapturePose.allCases where result[pose] == nil {
            throw CubeFaceletReconstructionError.missingPose(pose)
        }
        return result
    }

    private static func standardizedGrids(
        _ observations: [CubeCapturePose: CubePoseObservation]
    ) throws -> [CubeFace: [CubeRGBSample]] {
        var result: [CubeFace: [CubeRGBSample]] = [:]
        for pose in CubeCapturePose.allCases {
            guard let observation = observations[pose] else {
                throw CubeFaceletReconstructionError.missingPose(pose)
            }
            var slots: Set<CubePoseFaceSlot> = []
            for grid in observation.faces {
                guard slots.insert(grid.slot).inserted else {
                    throw CubeFaceletReconstructionError.duplicateSlot(pose: pose, slot: grid.slot)
                }
                guard grid.samples.count == 9 else {
                    throw CubeFaceletReconstructionError.invalidSampleCount(
                        pose: pose,
                        slot: grid.slot,
                        actual: grid.samples.count
                    )
                }
                let face = pose.face(for: grid.slot)
                guard result[face] == nil else {
                    throw CubeFaceletReconstructionError.duplicateFace(face)
                }
                var standardized = Array(repeating: CubeRGBSample(red: 0, green: 0, blue: 0), count: 9)
                for (sourceIndex, sample) in grid.samples.enumerated() {
                    standardized[grid.transform.standardIndex(forSourceIndex: sourceIndex)] = sample
                }
                result[face] = standardized
            }
            for slot in CubePoseFaceSlot.allCases where !slots.contains(slot) {
                throw CubeFaceletReconstructionError.missingSlot(pose: pose, slot: slot)
            }
        }
        for face in CubeFace.allCases where result[face] == nil {
            throw CubeFaceletReconstructionError.missingFace(face)
        }
        return result
    }
}

/// Explicit entry point for the guided six-frontal-face protocol.
public enum CubeSingleFaceletReconstructor {
    public static func reconstruct(
        observations: [CubeSingleFaceObservation]
    ) throws -> CubeFaceletScan {
        try CubeFaceletReconstructor.reconstruct(observations: observations)
    }
}

/// Nearest-center classifier with grey-world channel normalization followed by
/// perceptual CIE Lab distance. Using all six centers from the same scan makes
/// the comparison resilient to uniform color casts without assuming a fixed
/// white/yellow or red/orange camera profile.
public struct CubeCenterColorClassifier: Sendable {
    private struct Prototype: Sendable {
        let face: CubeFace
        let lab: Lab
    }

    private struct Lab: Sendable {
        let l: Double
        let a: Double
        let b: Double
    }

    private let channelGains: CubeRGBSample
    private let prototypes: [Prototype]

    public init(centers: [CubeFace: CubeRGBSample]) {
        let available = CubeFace.faceletOrder.compactMap { centers[$0] }
        let mean = CubeRGBSample(
            red: available.map(\.red).reduce(0, +) / Double(max(1, available.count)),
            green: available.map(\.green).reduce(0, +) / Double(max(1, available.count)),
            blue: available.map(\.blue).reduce(0, +) / Double(max(1, available.count))
        )
        let gray = max(0.000_001, (mean.red + mean.green + mean.blue) / 3)
        let gains = CubeRGBSample(
            red: gray / max(mean.red, 0.000_001),
            green: gray / max(mean.green, 0.000_001),
            blue: gray / max(mean.blue, 0.000_001)
        )
        channelGains = gains
        prototypes = CubeFace.faceletOrder.compactMap { face in
            centers[face].map { Prototype(face: face, lab: Self.lab(for: $0, gains: gains)) }
        }
    }

    public func classify(_ sample: CubeRGBSample) -> CubeClassifiedFacelet {
        let target = Self.lab(for: sample, gains: channelGains)
        let ranked = prototypes.map { prototype in
            (prototype.face, Self.distance(target, prototype.lab))
        }.sorted { $0.1 < $1.1 }
        guard let best = ranked.first else {
            return CubeClassifiedFacelet(colorFace: .up, confidence: 0, sample: sample)
        }
        let secondDistance = ranked.dropFirst().first?.1 ?? best.1
        let confidence: Double
        if secondDistance <= 0.000_001 {
            confidence = 0
        } else {
            confidence = min(1, max(0, 1 - best.1 / secondDistance))
        }
        return CubeClassifiedFacelet(colorFace: best.0, confidence: confidence, sample: sample)
    }

    private static func lab(for sample: CubeRGBSample, gains: CubeRGBSample) -> Lab {
        func linear(_ value: Double) -> Double {
            let value = min(1, max(0, value))
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

    private static func distance(_ lhs: Lab, _ rhs: Lab) -> Double {
        let dl = lhs.l - rhs.l
        let da = lhs.a - rhs.a
        let db = lhs.b - rhs.b
        return (dl * dl + da * da + db * db).squareRoot()
    }
}
