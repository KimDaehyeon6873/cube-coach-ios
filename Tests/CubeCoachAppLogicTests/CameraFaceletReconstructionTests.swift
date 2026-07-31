import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Testing
@testable import CubeCoachAppLogic

private let centerSamples: [CubeFace: CubeRGBSample] = [
    .up: .init(red: 0.92, green: 0.90, blue: 0.86),
    .right: .init(red: 0.82, green: 0.08, blue: 0.06),
    .front: .init(red: 0.05, green: 0.62, blue: 0.16),
    .down: .init(red: 0.95, green: 0.78, blue: 0.04),
    .left: .init(red: 0.95, green: 0.31, blue: 0.03),
    .back: .init(red: 0.04, green: 0.18, blue: 0.78),
]

private func solidGrid(slot: CubePoseFaceSlot, face: CubeFace) -> CubeFaceGridSamples {
    CubeFaceGridSamples(slot: slot, samples: Array(repeating: centerSamples[face]!, count: 9))
}

private func solvedPose(_ pose: CubeCapturePose) -> CubePoseObservation {
    CubePoseObservation(
        pose: pose,
        faces: CubePoseFaceSlot.allCases.map { slot in
            solidGrid(slot: slot, face: pose.face(for: slot))
        }
    )
}

private func solvedSingleFace(_ face: CubeFace) -> CubeSingleFaceObservation {
    CubeSingleFaceObservation(
        face: face,
        samples: Array(repeating: centerSamples[face]!, count: 9)
    )
}

private let fixtureLayout = CubeGuidedFaceLayout(quadrilaterals: [
    .top: .init(
        topLeft: .init(x: 0.05, y: 0.10),
        topRight: .init(x: 0.30, y: 0.10),
        bottomRight: .init(x: 0.30, y: 0.40),
        bottomLeft: .init(x: 0.05, y: 0.40)
    ),
    .left: .init(
        topLeft: .init(x: 0.375, y: 0.10),
        topRight: .init(x: 0.625, y: 0.10),
        bottomRight: .init(x: 0.625, y: 0.40),
        bottomLeft: .init(x: 0.375, y: 0.40)
    ),
    .right: .init(
        topLeft: .init(x: 0.70, y: 0.10),
        topRight: .init(x: 0.95, y: 0.10),
        bottomRight: .init(x: 0.95, y: 0.40),
        bottomLeft: .init(x: 0.70, y: 0.40)
    ),
])

private let fixtureCellColors: [CubePoseFaceSlot: [CubeRGBSample]] = [
    .top: (0..<9).map { .init(red: 0.15 + Double($0) * 0.07, green: 0.12, blue: 0.18) },
    .left: (0..<9).map { .init(red: 0.10, green: 0.15 + Double($0) * 0.07, blue: 0.16) },
    .right: (0..<9).map { .init(red: 0.12, green: 0.14, blue: 0.15 + Double($0) * 0.07) },
]

private func fixturePortraitImage(width: Int = 240, height: Int = 360) throws -> CGImage {
    var bytes = Array(repeating: UInt8(0), count: width * height * 4)
    for y in 0..<height {
        let normalizedY = (Double(y) + 0.5) / Double(height)
        for x in 0..<width {
            let normalizedX = (Double(x) + 0.5) / Double(width)
            let slotAndBounds: [(CubePoseFaceSlot, Double, Double)] = [
                (.top, 0.05, 0.30),
                (.left, 0.375, 0.625),
                (.right, 0.70, 0.95),
            ]
            guard let (slot, x0, x1) = slotAndBounds.first(where: {
                normalizedX >= $0.1 && normalizedX < $0.2 &&
                normalizedY >= 0.10 && normalizedY < 0.40
            }) else { continue }
            let column = min(2, Int((normalizedX - x0) / (x1 - x0) * 3))
            let row = min(2, Int((normalizedY - 0.10) / 0.30 * 3))
            let sample = fixtureCellColors[slot]![row * 3 + column]
            let offset = (y * width + x) * 4
            bytes[offset] = UInt8((sample.red * 255).rounded())
            bytes[offset + 1] = UInt8((sample.green * 255).rounded())
            bytes[offset + 2] = UInt8((sample.blue * 255).rounded())
            bytes[offset + 3] = 255
        }
    }
    let data = Data(bytes) as CFData
    let provider = try #require(CGDataProvider(data: data))
    return try #require(CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ))
}

private func jpegData(from image: CGImage, orientation: Int? = nil) throws -> Data {
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(
        data,
        "public.jpeg" as CFString,
        1,
        nil
    ))
    var properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: 0.98,
    ]
    if let orientation {
        properties[kCGImagePropertyOrientation] = orientation
    }
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

private func expectFixtureSamples(_ observation: CubePoseObservation) {
    #expect(observation.faces.count == 3)
    for face in observation.faces {
        let expected = fixtureCellColors[face.slot]!
        #expect(face.samples.count == 9)
        for (sample, target) in zip(face.samples, expected) {
            #expect(abs(sample.red - target.red) < 0.08)
            #expect(abs(sample.green - target.green) < 0.08)
            #expect(abs(sample.blue - target.blue) < 0.08)
        }
    }
}

@Test func oppositeCornerUsesAProperRotationWithoutReflection() {
    #expect(CubeCapturePose.upperFrontRight.face(for: .top) == .up)
    #expect(CubeCapturePose.upperFrontRight.face(for: .left) == .front)
    #expect(CubeCapturePose.upperFrontRight.face(for: .right) == .right)
    #expect(CubeCapturePose.downBackLeft.face(for: .top) == .down)
    #expect(CubeCapturePose.downBackLeft.face(for: .left) == .left)
    #expect(CubeCapturePose.downBackLeft.face(for: .right) == .back)
}

@Test func singleFaceProtocolUsesRequestedOrderAndExplicitTopEdgeInstructions() {
    #expect(CubeFace.singleFaceCaptureOrder == [.up, .front, .right, .down, .back, .left])
    let expectedTopEdges: [CubeFace: CubeFace] = [
        .up: .back,
        .front: .up,
        .right: .up,
        .down: .front,
        .back: .up,
        .left: .up,
    ]
    for face in CubeFace.singleFaceCaptureOrder {
        let orientation = CubeSingleFaceCaptureOrientation.standard(for: face)
        #expect(orientation.face == face)
        #expect(orientation.topEdgeFace == expectedTopEdges[face])
        #expect(orientation.transform == .identity)
        #expect(orientation.instruction.contains(face.rawValue))
        #expect(orientation.instruction.contains(orientation.topEdgeFace.rawValue))
    }

    let guide = CubeSingleFaceGuideLayout.portraitCentralSquare.quadrilateral
    #expect(guide.topLeft.x == guide.bottomLeft.x)
    #expect(guide.topRight.x == guide.bottomRight.x)
    #expect(guide.topLeft.y == guide.topRight.y)
    #expect(guide.bottomLeft.y == guide.bottomRight.y)
    // AVCapture portrait photos are 3:4. These normalized spans therefore
    // describe the same pixel length and render as a true square.
    let pixelWidth = (guide.topRight.x - guide.topLeft.x) * 3
    let pixelHeight = (guide.bottomLeft.y - guide.topLeft.y) * 4
    #expect(abs(pixelWidth - pixelHeight) < 0.000_001)
}

@Test func sixSingleFaceObservationsReconstructAll54Facelets() throws {
    let scan = try CubeSingleFaceletReconstructor.reconstruct(
        observations: CubeFace.singleFaceCaptureOrder.map(solvedSingleFace)
    )

    #expect(scan.faceletCount == 54)
    #expect(scan.faceletStringURFDLB ==
        String(repeating: "U", count: 9) +
        String(repeating: "R", count: 9) +
        String(repeating: "F", count: 9) +
        String(repeating: "D", count: 9) +
        String(repeating: "L", count: 9) +
        String(repeating: "B", count: 9))
}

@Test func repeatedSingleFaceCapturesAreMedianFusedDeterministically() throws {
    let target = centerSamples[.front]!
    let darkOutlier = CubeSingleFaceObservation(
        face: .front,
        samples: Array(repeating: .init(red: 0, green: 0, blue: 0), count: 9)
    )
    let observations = CubeFace.allCases.map(solvedSingleFace) + [
        solvedSingleFace(.front),
        darkOutlier,
    ]

    let scan = try CubeSingleFaceletReconstructor.reconstruct(observations: observations)
    let frontSamples = try #require(scan.faceletsByFace[.front]?.map(\.sample))

    #expect(frontSamples == Array(repeating: target, count: 9))
}

@Test func singleFaceOrientationTransformIsAppliedBeforeReconstruction() throws {
    let markers = (0..<9).map {
        CubeRGBSample(red: 0.05, green: 0.45 + Double($0) / 100, blue: 0.12)
    }
    let rotatedFront = CubeSingleFaceObservation(
        face: .front,
        samples: markers,
        orientation: .init(
            face: .front,
            topEdgeFace: .right,
            transform: .init(clockwiseQuarterTurns: 1),
            instruction: "fixture"
        )
    )
    let observations = CubeFace.allCases.filter { $0 != .front }.map(solvedSingleFace) + [rotatedFront]

    let scan = try CubeSingleFaceletReconstructor.reconstruct(observations: observations)
    let green = try #require(scan.faceletsByFace[.front]?.map(\.sample.green))

    let expected = [0.51, 0.48, 0.45, 0.52, 0.49, 0.46, 0.53, 0.50, 0.47]
    for (actual, target) in zip(green, expected) {
        #expect(abs(actual - target) < 0.000_001)
    }
}

@Test func singleFaceReconstructionReportsMissingInvalidAndMismatchedObservations() {
    let missingBack = CubeFace.allCases.filter { $0 != .back }.map(solvedSingleFace)
    #expect(throws: CubeFaceletReconstructionError.missingFace(.back)) {
        try CubeSingleFaceletReconstructor.reconstruct(observations: missingBack)
    }

    let invalid = CubeSingleFaceObservation(
        face: .up,
        samples: Array(repeating: centerSamples[.up]!, count: 8)
    )
    #expect(throws: CubeFaceletReconstructionError.invalidSingleFaceSampleCount(
        face: .up,
        actual: 8
    )) {
        try CubeSingleFaceletReconstructor.reconstruct(
            observations: CubeFace.allCases.filter { $0 != .up }.map(solvedSingleFace) + [invalid]
        )
    }

    let mismatched = CubeSingleFaceObservation(
        face: .up,
        samples: Array(repeating: centerSamples[.up]!, count: 9),
        orientation: .standard(for: .front)
    )
    #expect(throws: CubeFaceletReconstructionError.mismatchedSingleFaceOrientation(
        observation: .up,
        orientation: .front
    )) {
        try CubeSingleFaceletReconstructor.reconstruct(
            observations: CubeFace.allCases.filter { $0 != .up }.map(solvedSingleFace) + [mismatched]
        )
    }
}

@Test func poseTransformsProduceStandardURFDLBMarkerOrientation() throws {
    let observations = CubeCapturePose.allCases.map { pose in
        CubePoseObservation(
            pose: pose,
            faces: CubePoseFaceSlot.allCases.map { slot in
                let face = pose.face(for: slot)
                let offset = CubeFace.faceletOrder.firstIndex(of: face)! * 9
                var markers: [CubeRGBSample] = []
                for index in 0..<9 {
                    let marker = offset + index
                    markers.append(CubeRGBSample(
                        red: Double(marker) / 100,
                        green: Double(marker + 1) / 100,
                        blue: Double(marker + 2) / 100
                    ))
                }
                return CubeFaceGridSamples(
                    slot: slot,
                    samples: markers,
                    transform: pose.standardFaceletTransform(for: slot)
                )
            }
        )
    }

    let scan = try CubeFaceletReconstructor.reconstruct(observations: observations)
    let markerIndicesByFace: [CubeFace: [Int]] = [
        .up: [2, 5, 8, 1, 4, 7, 0, 3, 6],
        .right: [0, 1, 2, 3, 4, 5, 6, 7, 8],
        .front: [0, 1, 2, 3, 4, 5, 6, 7, 8],
        .down: [0, 1, 2, 3, 4, 5, 6, 7, 8],
        .left: [8, 7, 6, 5, 4, 3, 2, 1, 0],
        .back: [8, 7, 6, 5, 4, 3, 2, 1, 0],
    ]

    for (faceOffset, face) in CubeFace.faceletOrder.enumerated() {
        let facelets = scan.faceletsByFace[face] ?? []
        #expect(facelets.count == 9)
        let actual = facelets.map {
            Int(($0.sample.red * 100).rounded())
        }
        let expected = markerIndicesByFace[face]!.map { faceOffset * 9 + $0 }
        #expect(actual == expected)
    }
}

@Test func twoOppositeCornerPosesReconstructAll54FaceletsInStandardOrder() throws {
    let scan = try CubeFaceletReconstructor.reconstruct(observations: [
        solvedPose(.upperFrontRight),
        solvedPose(.downBackLeft),
    ])

    #expect(scan.faceletCount == 54)
    #expect(scan.faceletStringURFDLB ==
        String(repeating: "U", count: 9) +
        String(repeating: "R", count: 9) +
        String(repeating: "F", count: 9) +
        String(repeating: "D", count: 9) +
        String(repeating: "L", count: 9) +
        String(repeating: "B", count: 9))
    #expect(scan.minimumConfidence > 0.5)
}

@Test func guidedJPEGExtractorReturnsThreeFacesAndTwentySevenCells() throws {
    let data = try jpegData(from: fixturePortraitImage())

    let observation = try CubeGuidedFaceExtractor.extract(
        jpegData: data,
        pose: .upperFrontRight,
        layout: fixtureLayout
    )

    #expect(observation.pose == .upperFrontRight)
    #expect(observation.faces.first(where: { $0.slot == .top })?.transform ==
        .init(clockwiseQuarterTurns: 3))
    #expect(observation.faces.first(where: { $0.slot == .left })?.transform == .identity)
    #expect(observation.faces.first(where: { $0.slot == .right })?.transform == .identity)
    expectFixtureSamples(observation)
}

@Test func singleFaceJPEGExtractorReturnsNineCellsAndOrientationMetadata() throws {
    let data = try jpegData(from: fixturePortraitImage())
    let layout = CubeSingleFaceGuideLayout(quadrilateral: .init(
        topLeft: .init(x: 0.375, y: 0.10),
        topRight: .init(x: 0.625, y: 0.10),
        bottomRight: .init(x: 0.625, y: 0.40),
        bottomLeft: .init(x: 0.375, y: 0.40)
    ))

    let observation = try CubeSingleFaceExtractor.extract(
        jpegData: data,
        face: .front,
        layout: layout
    )

    #expect(observation.face == .front)
    #expect(observation.orientation == .standard(for: .front))
    #expect(observation.samples.count == 9)
    for (sample, target) in zip(observation.samples, fixtureCellColors[.left]!) {
        #expect(abs(sample.red - target.red) < 0.08)
        #expect(abs(sample.green - target.green) < 0.08)
        #expect(abs(sample.blue - target.blue) < 0.08)
    }
}

@Test func singleFaceJPEGExtractorAppliesEXIFOrientation() throws {
    let portrait = CIImage(cgImage: try fixturePortraitImage())
    let landscape = portrait.oriented(.left)
    let landscapeImage = try #require(CIContext().createCGImage(landscape, from: landscape.extent))
    let data = try jpegData(from: landscapeImage, orientation: 6)
    let layout = CubeSingleFaceGuideLayout(quadrilateral: .init(
        topLeft: .init(x: 0.375, y: 0.10),
        topRight: .init(x: 0.625, y: 0.10),
        bottomRight: .init(x: 0.625, y: 0.40),
        bottomLeft: .init(x: 0.375, y: 0.40)
    ))

    let observation = try CubeSingleFaceExtractor.extract(
        jpegData: data,
        face: .front,
        layout: layout
    )

    for (sample, target) in zip(observation.samples, fixtureCellColors[.left]!) {
        #expect(abs(sample.red - target.red) < 0.08)
        #expect(abs(sample.green - target.green) < 0.08)
        #expect(abs(sample.blue - target.blue) < 0.08)
    }
}

@Test func guidedJPEGExtractorAppliesImageOrientationMetadata() throws {
    let portrait = CIImage(cgImage: try fixturePortraitImage())
    let landscape = portrait.oriented(.left)
    let context = CIContext()
    let landscapeImage = try #require(context.createCGImage(landscape, from: landscape.extent))
    let orientedJPEG = try jpegData(from: landscapeImage, orientation: 6)

    let observation = try CubeGuidedFaceExtractor.extract(
        jpegData: orientedJPEG,
        pose: .downBackLeft,
        layout: fixtureLayout
    )

    #expect(observation.pose == .downBackLeft)
    #expect(observation.faces.first(where: { $0.slot == .top })?.transform == .identity)
    #expect(observation.faces.first(where: { $0.slot == .left })?.transform ==
        .init(clockwiseQuarterTurns: 2))
    #expect(observation.faces.first(where: { $0.slot == .right })?.transform ==
        .init(clockwiseQuarterTurns: 2))
    expectFixtureSamples(observation)
}

@Test func guidedJPEGExtractorRejectsInvalidAndLandscapeImages() throws {
    #expect(throws: CubeGuidedFaceExtractionError.invalidImageData) {
        try CubeGuidedFaceExtractor.extract(
            jpegData: Data("not-a-jpeg".utf8),
            pose: .upperFrontRight,
            layout: fixtureLayout
        )
    }

    let portrait = CIImage(cgImage: try fixturePortraitImage())
    let landscape = portrait.oriented(.left)
    let landscapeImage = try #require(CIContext().createCGImage(landscape, from: landscape.extent))
    let landscapeJPEG = try jpegData(from: landscapeImage)
    #expect(throws: CubeGuidedFaceExtractionError.invalidPortraitImage(width: 360, height: 240)) {
        try CubeGuidedFaceExtractor.extract(
            jpegData: landscapeJPEG,
            pose: .upperFrontRight,
            layout: fixtureLayout
        )
    }
}

@Test func classifierUsesMeasuredCentersUnderAColorCast() {
    let castCenters = centerSamples.mapValues { sample in
        CubeRGBSample(
            red: sample.red * 0.58,
            green: sample.green * 0.82,
            blue: min(1, sample.blue * 1.25)
        )
    }
    let classifier = CubeCenterColorClassifier(centers: castCenters)

    for face in CubeFace.allCases {
        let result = classifier.classify(castCenters[face]!)
        #expect(result.colorFace == face)
        #expect(result.confidence > 0.9)
    }
}

@Test func stickerCellSampleAveragesItsInteriorPixels() {
    let sample = CubeRGBSample.average([
        CubeRGBSample(red: 0.2, green: 0.4, blue: 0.6),
        CubeRGBSample(red: 0.4, green: 0.6, blue: 0.8),
    ])

    #expect(abs(sample.red - 0.3) < 0.000_001)
    #expect(abs(sample.green - 0.5) < 0.000_001)
    #expect(abs(sample.blue - 0.7) < 0.000_001)
}

@Test func rectifiedFaceIsSplitIntoNineAverageColorSamples() throws {
    let expected = (0..<9).map { index in
        CubeRGBSample(red: Double(index) / 10, green: Double(9 - index) / 10, blue: 0.25)
    }
    var pixels: [CubeRGBSample] = []
    for y in 0..<9 {
        for x in 0..<9 {
            pixels.append(expected[(y / 3) * 3 + x / 3])
        }
    }

    let samples = try CubeFaceGridSampler.samples(
        from: CubeRectifiedFaceImage(width: 9, height: 9, pixels: pixels)
    )

    #expect(samples.count == expected.count)
    for (sample, expectedSample) in zip(samples, expected) {
        #expect(abs(sample.red - expectedSample.red) < 0.000_001)
        #expect(abs(sample.green - expectedSample.green) < 0.000_001)
        #expect(abs(sample.blue - expectedSample.blue) < 0.000_001)
    }
}

@Test func rectifiedFaceRejectsMalformedPixelBuffers() {
    #expect(throws: CubeFaceGridSamplingError.invalidDimensions(
        width: 9,
        height: 9,
        pixelCount: 1
    )) {
        try CubeFaceGridSampler.samples(
            from: CubeRectifiedFaceImage(
                width: 9,
                height: 9,
                pixels: [.init(red: 0, green: 0, blue: 0)]
            )
        )
    }
}

@Test func gridTransformMapsSourceCellsIntoStandardFaceIndices() throws {
    let marker = (0..<9).map { index in
        CubeRGBSample(red: Double(index) / 10, green: 0, blue: 0)
    }
    let transformed = CubeFaceGridSamples(
        slot: .top,
        samples: marker,
        transform: .init(clockwiseQuarterTurns: 1)
    )
    let remainingFirst = [
        solidGrid(slot: .left, face: .front),
        solidGrid(slot: .right, face: .right),
    ]
    let scan = try CubeFaceletReconstructor.reconstruct(observations: [
        .init(pose: .upperFrontRight, faces: [transformed] + remainingFirst),
        solvedPose(.downBackLeft),
    ])

    let upSamples = try #require(scan.faceletsByFace[.up]?.map(\.sample.red))
    #expect(upSamples == [0.6, 0.3, 0.0, 0.7, 0.4, 0.1, 0.8, 0.5, 0.2])
}

@Test func missingOppositePoseIsReported() {
    #expect(throws: CubeFaceletReconstructionError.missingPose(.downBackLeft)) {
        try CubeFaceletReconstructor.reconstruct(observations: [solvedPose(.upperFrontRight)])
    }
}

@Test func duplicatePoseIsReported() {
    #expect(throws: CubeFaceletReconstructionError.duplicatePose(.upperFrontRight)) {
        try CubeFaceletReconstructor.reconstruct(observations: [
            solvedPose(.upperFrontRight),
            solvedPose(.upperFrontRight),
            solvedPose(.downBackLeft),
        ])
    }
}

@Test func missingAndDuplicateSlotsAreReported() {
    let first = solvedPose(.upperFrontRight)
    let missing = CubePoseObservation(pose: first.pose, faces: Array(first.faces.dropLast()))
    #expect(throws: CubeFaceletReconstructionError.missingSlot(pose: .upperFrontRight, slot: .right)) {
        try CubeFaceletReconstructor.reconstruct(observations: [missing, solvedPose(.downBackLeft)])
    }

    let duplicate = CubePoseObservation(pose: first.pose, faces: first.faces + [first.faces[0]])
    #expect(throws: CubeFaceletReconstructionError.duplicateSlot(pose: .upperFrontRight, slot: .top)) {
        try CubeFaceletReconstructor.reconstruct(observations: [duplicate, solvedPose(.downBackLeft)])
    }
}

@Test func nonNineCellGridIsRejected() {
    let invalid = CubeFaceGridSamples(
        slot: .top,
        samples: Array(repeating: centerSamples[.up]!, count: 8)
    )
    let first = CubePoseObservation(
        pose: .upperFrontRight,
        faces: [
            invalid,
            solidGrid(slot: .left, face: .front),
            solidGrid(slot: .right, face: .right),
        ]
    )

    #expect(throws: CubeFaceletReconstructionError.invalidSampleCount(
        pose: .upperFrontRight,
        slot: .top,
        actual: 8
    )) {
        try CubeFaceletReconstructor.reconstruct(observations: [first, solvedPose(.downBackLeft)])
    }
}
