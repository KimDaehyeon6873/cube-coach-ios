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
