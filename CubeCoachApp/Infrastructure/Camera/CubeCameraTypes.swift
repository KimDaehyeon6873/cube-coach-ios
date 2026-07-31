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
    public let orientation: CubeSingleFaceCaptureOrientation

    public init(
        face: CubeFace,
        samples: [CubeRGBSample],
        orientation: CubeSingleFaceCaptureOrientation? = nil
    ) {
        self.face = face
        self.samples = samples
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

public enum CubeFaceGridSamplingError: Error, Equatable, Sendable {
    case invalidDimensions(width: Int, height: Int, pixelCount: Int)
    case faceTooSmall(width: Int, height: Int)
}

/// Splits a rectified face into row-major 3×3 cells and takes a robust
/// representative of each inset interior region.
public enum CubeFaceGridSampler {
    public static func samples(
        from image: CubeRectifiedFaceImage,
        cellInsetFraction: Double = 0.18
    ) throws -> [CubeRGBSample] {
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
        var result: [CubeRGBSample] = []
        result.reserveCapacity(9)
        for row in 0..<3 {
            let outerY0 = row * image.height / 3
            let outerY1 = (row + 1) * image.height / 3
            for column in 0..<3 {
                let outerX0 = column * image.width / 3
                let outerX1 = (column + 1) * image.width / 3
                let insetX = Int((Double(outerX1 - outerX0) * insetFraction).rounded(.down))
                let insetY = Int((Double(outerY1 - outerY0) * insetFraction).rounded(.down))
                let x0 = min(outerX1 - 1, outerX0 + insetX)
                let x1 = max(x0 + 1, outerX1 - insetX)
                let y0 = min(outerY1 - 1, outerY0 + insetY)
                let y1 = max(y0 + 1, outerY1 - insetY)
                var pixels: [CubeRGBSample] = []
                pixels.reserveCapacity((x1 - x0) * (y1 - y0))
                for y in y0..<y1 {
                    for x in x0..<x1 {
                        pixels.append(image.pixels[y * image.width + x])
                    }
                }
                result.append(CubeRGBSample.robustRepresentative(pixels))
            }
        }
        return result
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
        let classifier = CubeCenterColorClassifier(centers: centers)
        let classified = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.map { face in
            let samples = gridsByFace[face, default: []]
            return (face, samples.map { classifier.classify($0) })
        })
        return CubeFaceletScan(faceletsByFace: classified)
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
        return classify(gridsByFace: fusedByFace)
    }

    private static func classify(
        gridsByFace: [CubeFace: [CubeRGBSample]]
    ) -> CubeFaceletScan {
        let centers = Dictionary(uniqueKeysWithValues: CubeFace.faceletOrder.compactMap { face in
            gridsByFace[face].map { (face, $0[4]) }
        })
        let classifier = CubeCenterColorClassifier(centers: centers)
        return CubeFaceletScan(faceletsByFace: Dictionary(
            uniqueKeysWithValues: CubeFace.faceletOrder.map { face in
                (face, gridsByFace[face, default: []].map { classifier.classify($0) })
            }
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
