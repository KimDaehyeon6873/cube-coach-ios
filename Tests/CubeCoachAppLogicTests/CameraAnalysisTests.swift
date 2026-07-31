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
