import Foundation
import Testing
@testable import CubeCoachAppLogic

@Test func validImageWithNoRectanglesIsAZeroCandidateSuccess() throws {
    let whitePNG = try #require(Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAATUlEQVR42u3PQQ0AAAgEILV/5zOFDzdoQCepz6aeExAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQELi3cqoDfaKuZM4AAAAASUVORK5CYII="
    ))

    let count = try CubeCameraSessionEngine.rectangleCount(in: whitePNG)

    #expect(count == 0)
}

@Test func invalidImageDataThrowsInsteadOfMasqueradingAsZeroCandidates() {
    let invalidImage = Data("not-an-image".utf8)

    #expect(throws: (any Error).self) {
        try CubeCameraSessionEngine.rectangleCount(in: invalidImage)
    }
}

@Test func robustRepresentativeRejectsIsolatedGlareAndDarkOutliers() {
    let sticker = CubeRGBSample(red: 0.72, green: 0.18, blue: 0.08)
    let sample = CubeRGBSample.robustRepresentative(
        Array(repeating: sticker, count: 7) + [
            .init(red: 1, green: 1, blue: 1),
            .init(red: 0, green: 0, blue: 0),
        ]
    )

    #expect(sample == sticker)
}

@Test func gridSamplerUsesRobustCellRepresentative() throws {
    let sticker = CubeRGBSample(red: 0.12, green: 0.64, blue: 0.21)
    var pixels = Array(repeating: sticker, count: 81)
    // One white glare pixel in each 3×3 cell must not wash out its sample.
    for row in 0..<3 {
        for column in 0..<3 {
            pixels[(row * 3) * 9 + column * 3] = .init(red: 1, green: 1, blue: 1)
        }
    }

    let samples = try CubeFaceGridSampler.samples(
        from: .init(width: 9, height: 9, pixels: pixels),
        cellInsetFraction: 0
    )

    #expect(samples == Array(repeating: sticker, count: 9))
}

@Test func centerGridSampleAvoidsAStickerLogo() throws {
    let sticker = CubeRGBSample(red: 0.86, green: 0.17, blue: 0.07)
    let logo = CubeRGBSample(red: 0.05, green: 0.16, blue: 0.82)
    var pixels = Array(repeating: sticker, count: 90 * 90)
    // The logo fills the old center-cell sampling crop (39..<51 on each axis).
    for y in 38..<52 {
        for x in 38..<52 {
            pixels[y * 90 + x] = logo
        }
    }

    let measurements = try CubeFaceGridSampler.measurements(
        from: .init(width: 90, height: 90, pixels: pixels)
    )

    #expect(measurements[4].sample == sticker)
    #expect(measurements[4].dispersion < 0.000_001)
}

@Test func exactSingleFaceGuideHasPerfectAlignmentScore() {
    let guide = CubeSingleFaceGuideLayout.portraitCentralSquare.quadrilateral

    let match = CubeSingleFaceGuideAlignmentScorer.match([guide])

    #expect(match?.alignmentConfidence ?? 0 > 0.99)
    let sampled = try? #require(match?.samplingQuadrilateral)
    #expect(abs((sampled?.topLeft.x ?? 0) - guide.topLeft.x) < 0.000_001)
    #expect(abs((sampled?.topLeft.y ?? 0) - guide.topLeft.y) < 0.000_001)
    #expect(abs((sampled?.bottomRight.x ?? 0) - guide.bottomRight.x) < 0.000_001)
    #expect(abs((sampled?.bottomRight.y ?? 0) - guide.bottomRight.y) < 0.000_001)
    #expect(match?.source == .outerBoundary)
}

@Test func sameBoundsDiamondDoesNotMasqueradeAsAlignedOuterGuide() {
    let diamond = CubeNormalizedGuideQuadrilateral(
        topLeft: .init(x: 0.5, y: 0.275),
        topRight: .init(x: 0.8, y: 0.5),
        bottomRight: .init(x: 0.5, y: 0.725),
        bottomLeft: .init(x: 0.2, y: 0.5)
    )

    let score = CubeSingleFaceGuideAlignmentScorer.score([diamond])

    #expect(score < 0.8)
}

@Test func sameBoundsHeavySkewDoesNotPassOuterGuideThreshold() {
    let skewed = CubeNormalizedGuideQuadrilateral(
        topLeft: .init(x: 0.2, y: 0.275),
        topRight: .init(x: 0.8, y: 0.43),
        bottomRight: .init(x: 0.8, y: 0.725),
        bottomLeft: .init(x: 0.2, y: 0.57)
    )

    let score = CubeSingleFaceGuideAlignmentScorer.score([skewed])

    #expect(score < 0.8)
}

@Test func modestPerspectiveStillPassesOuterGuideThreshold() {
    let perspective = CubeNormalizedGuideQuadrilateral(
        topLeft: .init(x: 0.21, y: 0.285),
        topRight: .init(x: 0.79, y: 0.29),
        bottomRight: .init(x: 0.78, y: 0.715),
        bottomLeft: .init(x: 0.22, y: 0.71)
    )

    let score = CubeSingleFaceGuideAlignmentScorer.score([perspective])

    #expect(score >= 0.8)
}

@Test func displacedAndIrrelevantRectanglesHaveLowAlignmentScore() {
    let candidates = [
        rectangle(minX: 0.01, minY: 0.01, maxX: 0.12, maxY: 0.10),
        rectangle(minX: 0.82, minY: 0.80, maxX: 0.97, maxY: 0.96),
        rectangle(minX: 0.02, minY: 0.38, maxX: 0.10, maxY: 0.46),
    ]

    let score = CubeSingleFaceGuideAlignmentScorer.score(candidates)

    #expect(score < 0.1)
}

@Test func threeByThreeStickerCandidatesHaveHighAlignmentScore() {
    let guide = CubeSingleFaceGuideLayout.portraitCentralSquare.quadrilateral
    let width = (guide.topRight.x - guide.topLeft.x) / 3
    let height = (guide.bottomLeft.y - guide.topLeft.y) / 3
    var candidates: [CubeNormalizedGuideQuadrilateral] = []
    for row in 0..<3 {
        for column in 0..<3 {
            let minX = guide.topLeft.x + Double(column) * width
            let minY = guide.topLeft.y + Double(row) * height
            candidates.append(rectangle(
                minX: minX,
                minY: minY,
                maxX: minX + width,
                maxY: minY + height
            ))
        }
    }

    let match = CubeSingleFaceGuideAlignmentScorer.match(candidates)

    #expect(match?.alignmentConfidence ?? 0 > 0.99)
    let sampled = try? #require(match?.samplingQuadrilateral)
    #expect(abs((sampled?.topLeft.x ?? 0) - guide.topLeft.x) < 0.000_001)
    #expect(abs((sampled?.topLeft.y ?? 0) - guide.topLeft.y) < 0.000_001)
    #expect(abs((sampled?.bottomRight.x ?? 0) - guide.bottomRight.x) < 0.000_001)
    #expect(abs((sampled?.bottomRight.y ?? 0) - guide.bottomRight.y) < 0.000_001)
    #expect(match?.source == .stickerGrid)
}

@Test func rotatedTrapezoidStickerGridPreservesItsPerspectiveSamplingQuad() throws {
    let face = CubeNormalizedGuideQuadrilateral(
        topLeft: .init(x: 0.24, y: 0.25),
        topRight: .init(x: 0.79, y: 0.31),
        bottomRight: .init(x: 0.75, y: 0.73),
        bottomLeft: .init(x: 0.18, y: 0.66)
    )
    let candidates = perspectiveGrid(in: face)

    let match = try #require(CubeSingleFaceGuideAlignmentScorer.match(candidates))

    #expect(match.source == .stickerGrid)
    #expect(match.alignmentConfidence > 0.7)
    #expect(match.samplingQuadrilateral == face)
}

@Test func stickerGridRequiresAllFourCornerCells() {
    let guide = CubeSingleFaceGuideLayout.portraitCentralSquare.quadrilateral
    let candidates = perspectiveGrid(in: guide)
        .enumerated()
        .filter { index, _ in index != 8 }
        .map(\.element)

    let match = CubeSingleFaceGuideAlignmentScorer.match(candidates)

    #expect(match?.source != .stickerGrid)
}

@Test func incompleteStickerGridCannotDefineASamplingCrop() {
    let guide = CubeSingleFaceGuideLayout.portraitCentralSquare.quadrilateral
    let width = (guide.topRight.x - guide.topLeft.x) / 3
    let height = (guide.bottomLeft.y - guide.topLeft.y) / 3
    let candidates = (0..<6).map { index in
        let row = index / 3
        let column = index % 3
        let minX = guide.topLeft.x + Double(column) * width
        let minY = guide.topLeft.y + Double(row) * height
        return rectangle(
            minX: minX,
            minY: minY,
            maxX: minX + width,
            maxY: minY + height
        )
    }

    let match = CubeSingleFaceGuideAlignmentScorer.match(candidates)

    #expect(match?.source != .stickerGrid)
    #expect(match?.alignmentConfidence ?? 0 < 0.50)
}

@Test func detectedOuterBoundaryBecomesTheSamplingRegion() {
    let shifted = rectangle(
        minX: 0.17,
        minY: 0.255,
        maxX: 0.77,
        maxY: 0.705
    )

    let match = CubeSingleFaceGuideAlignmentScorer.match([shifted])

    #expect(match?.alignmentConfidence ?? 0 > 0.65)
    #expect(match?.samplingQuadrilateral == shifted)
    #expect(match?.source == .outerBoundary)
}

@Test func outerBoundaryWithVisibleGuideMarginStillPassesCaptureThreshold() {
    let smaller = rectangle(
        minX: 0.245,
        minY: 0.30875,
        maxX: 0.755,
        maxY: 0.69125
    )

    let match = CubeSingleFaceGuideAlignmentScorer.match([smaller])

    #expect(match?.alignmentConfidence ?? 0 >= 0.50)
    #expect(match?.samplingQuadrilateral == smaller)
}

@Test func alignmentRejectsInvalidQuadrilaterals() {
    let nonFinite = CubeNormalizedGuideQuadrilateral(
        topLeft: .init(x: .nan, y: 0.275),
        topRight: .init(x: 0.8, y: 0.275),
        bottomRight: .init(x: 0.8, y: 0.725),
        bottomLeft: .init(x: 0.2, y: 0.725)
    )
    let outOfRange = rectangle(minX: -0.2, minY: 0.275, maxX: 0.8, maxY: 0.725)
    let degenerate = CubeNormalizedGuideQuadrilateral(
        topLeft: .init(x: 0.2, y: 0.4),
        topRight: .init(x: 0.4, y: 0.4),
        bottomRight: .init(x: 0.6, y: 0.4),
        bottomLeft: .init(x: 0.8, y: 0.4)
    )
    let bowTie = CubeNormalizedGuideQuadrilateral(
        topLeft: .init(x: 0.2, y: 0.275),
        topRight: .init(x: 0.8, y: 0.725),
        bottomRight: .init(x: 0.8, y: 0.275),
        bottomLeft: .init(x: 0.2, y: 0.725)
    )
    let nonConvex = CubeNormalizedGuideQuadrilateral(
        topLeft: .init(x: 0.2, y: 0.275),
        topRight: .init(x: 0.8, y: 0.275),
        bottomRight: .init(x: 0.5, y: 0.45),
        bottomLeft: .init(x: 0.2, y: 0.725)
    )

    for candidate in [nonFinite, outOfRange, degenerate, bowTie, nonConvex] {
        #expect(CubeSingleFaceGuideAlignmentScorer.score([candidate]) == 0)
    }
}

@Test func alignmentIgnoresInvalidCandidatesWhenAValidInterpretationExists() {
    let guide = CubeSingleFaceGuideLayout.portraitCentralSquare.quadrilateral
    let invalid = rectangle(minX: -1, minY: -1, maxX: 1, maxY: 1)

    let score = CubeSingleFaceGuideAlignmentScorer.score([invalid, guide])

    #expect(score > 0.99)
}

@Test func uniformFrameHasZeroSharpnessAndExpectedExposure() throws {
    let gray = CubeRGBSample(red: 0.4, green: 0.4, blue: 0.4)
    let image = CubeRectifiedFaceImage(
        width: 9,
        height: 9,
        pixels: Array(repeating: gray, count: 81)
    )

    let quality = try CubeLiveFrameQualityAnalyzer.analyze(image)

    #expect(abs(quality.exposure - 0.4) < 0.000_001)
    #expect(quality.sharpness == 0)
    #expect(quality.signature == Array(repeating: gray, count: 9))
}

@Test func contrastedGridIsSharperThanUniformFrameAndProducesNineCellSignature() throws {
    let black = CubeRGBSample(red: 0, green: 0, blue: 0)
    let white = CubeRGBSample(red: 1, green: 1, blue: 1)
    let uniform = CubeRectifiedFaceImage(
        width: 9,
        height: 9,
        pixels: Array(repeating: black, count: 81)
    )
    let gridPixels = (0..<81).map { index in
        let cellRow = (index / 9) / 3
        let cellColumn = (index % 9) / 3
        return (cellRow + cellColumn).isMultiple(of: 2) ? black : white
    }
    let grid = CubeRectifiedFaceImage(width: 9, height: 9, pixels: gridPixels)

    let uniformQuality = try CubeLiveFrameQualityAnalyzer.analyze(uniform)
    let gridQuality = try CubeLiveFrameQualityAnalyzer.analyze(grid)

    #expect(gridQuality.sharpness > uniformQuality.sharpness)
    #expect(gridQuality.sharpness > 0.2)
    #expect(abs(gridQuality.exposure - 4.0 / 9.0) < 0.000_001)
    #expect(gridQuality.signature.count == 9)
}

@Test func seamFocusScoreIsStableAcrossRealisticFaceResolutions() throws {
    var sharpnessByResolution: [Double] = []
    for size in [90, 240] {
        let sharp = realisticSolvedFace(size: size)
        let blurred = boxBlur(sharp, radius: max(3, size / 30))

        let sharpQuality = try CubeLiveFrameQualityAnalyzer.analyze(sharp)
        let blurredQuality = try CubeLiveFrameQualityAnalyzer.analyze(blurred)
        sharpnessByResolution.append(sharpQuality.sharpness)

        #expect(sharpQuality.sharpness >= 0.6)
        #expect(blurredQuality.sharpness < sharpQuality.sharpness * 0.6)
        #expect(sharpQuality.signature.count == 9)
    }
    #expect(abs(sharpnessByResolution[0] - sharpnessByResolution[1]) < 0.05)
}

@Test func qualityAnalysisRejectsNonfiniteAndOutOfRangeRGB() {
    let valid = CubeRGBSample(red: 0.4, green: 0.4, blue: 0.4)
    for invalid in [
        CubeRGBSample(red: .nan, green: 0.4, blue: 0.4),
        CubeRGBSample(red: 0.4, green: .infinity, blue: 0.4),
        CubeRGBSample(red: 0.4, green: 0.4, blue: -0.01),
        CubeRGBSample(red: 1.01, green: 0.4, blue: 0.4),
    ] {
        var pixels = Array(repeating: valid, count: 81)
        pixels[40] = invalid
        let image = CubeRectifiedFaceImage(width: 9, height: 9, pixels: pixels)

        #expect(throws: CubeLiveFrameQualityAnalysisError.invalidPixel(index: 40)) {
            try CubeLiveFrameQualityAnalyzer.analyze(image)
        }
    }
}

private func realisticSolvedFace(size: Int) -> CubeRectifiedFaceImage {
    let sticker = CubeRGBSample(red: 0.84, green: 0.18, blue: 0.08)
    let seam = CubeRGBSample(red: 0.035, green: 0.035, blue: 0.035)
    let seamHalfWidth = max(1, size / 60)
    let divisions = [size / 3, 2 * size / 3]
    let pixels = (0..<(size * size)).map { index in
        let x = index % size
        let y = index / size
        let isSeam = divisions.contains { division in
            abs(x - division) <= seamHalfWidth || abs(y - division) <= seamHalfWidth
        }
        return isSeam ? seam : sticker
    }
    return CubeRectifiedFaceImage(width: size, height: size, pixels: pixels)
}

private func boxBlur(
    _ image: CubeRectifiedFaceImage,
    radius: Int
) -> CubeRectifiedFaceImage {
    let stride = image.width + 1
    func integral(_ channel: (CubeRGBSample) -> Double) -> [Double] {
        var result = Array(repeating: 0.0, count: stride * (image.height + 1))
        for y in 0..<image.height {
            var rowSum = 0.0
            for x in 0..<image.width {
                rowSum += channel(image.pixels[y * image.width + x])
                result[(y + 1) * stride + x + 1] = result[y * stride + x + 1] + rowSum
            }
        }
        return result
    }
    let red = integral(\.red)
    let green = integral(\.green)
    let blue = integral(\.blue)
    func sum(_ values: [Double], x0: Int, y0: Int, x1: Int, y1: Int) -> Double {
        values[y1 * stride + x1] - values[y0 * stride + x1]
            - values[y1 * stride + x0] + values[y0 * stride + x0]
    }

    var pixels: [CubeRGBSample] = []
    pixels.reserveCapacity(image.pixels.count)
    for y in 0..<image.height {
        for x in 0..<image.width {
            let x0 = max(0, x - radius)
            let y0 = max(0, y - radius)
            let x1 = min(image.width, x + radius + 1)
            let y1 = min(image.height, y + radius + 1)
            let count = Double((x1 - x0) * (y1 - y0))
            pixels.append(.init(
                red: sum(red, x0: x0, y0: y0, x1: x1, y1: y1) / count,
                green: sum(green, x0: x0, y0: y0, x1: x1, y1: y1) / count,
                blue: sum(blue, x0: x0, y0: y0, x1: x1, y1: y1) / count
            ))
        }
    }
    return CubeRectifiedFaceImage(width: image.width, height: image.height, pixels: pixels)
}

private func rectangle(
    minX: Double,
    minY: Double,
    maxX: Double,
    maxY: Double
) -> CubeNormalizedGuideQuadrilateral {
    CubeNormalizedGuideQuadrilateral(
        topLeft: .init(x: minX, y: minY),
        topRight: .init(x: maxX, y: minY),
        bottomRight: .init(x: maxX, y: maxY),
        bottomLeft: .init(x: minX, y: maxY)
    )
}

private func perspectiveGrid(
    in quadrilateral: CubeNormalizedGuideQuadrilateral
) -> [CubeNormalizedGuideQuadrilateral] {
    func point(row: Int, column: Int) -> CubeNormalizedGuidePoint {
        let horizontal = Double(column) / 3
        let vertical = Double(row) / 3
        let topX = quadrilateral.topLeft.x +
            (quadrilateral.topRight.x - quadrilateral.topLeft.x) * horizontal
        let topY = quadrilateral.topLeft.y +
            (quadrilateral.topRight.y - quadrilateral.topLeft.y) * horizontal
        let bottomX = quadrilateral.bottomLeft.x +
            (quadrilateral.bottomRight.x - quadrilateral.bottomLeft.x) * horizontal
        let bottomY = quadrilateral.bottomLeft.y +
            (quadrilateral.bottomRight.y - quadrilateral.bottomLeft.y) * horizontal
        return CubeNormalizedGuidePoint(
            x: topX + (bottomX - topX) * vertical,
            y: topY + (bottomY - topY) * vertical
        )
    }

    return (0..<3).flatMap { row in
        (0..<3).map { column in
            CubeNormalizedGuideQuadrilateral(
                topLeft: point(row: row, column: column),
                topRight: point(row: row, column: column + 1),
                bottomRight: point(row: row + 1, column: column + 1),
                bottomLeft: point(row: row + 1, column: column)
            )
        }
    }
}
