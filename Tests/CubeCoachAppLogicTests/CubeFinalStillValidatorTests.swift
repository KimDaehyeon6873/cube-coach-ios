import Testing
@testable import CubeCoachAppLogic

@Test func finalStillValidationRequiresEnoughRectangleCandidates() {
    let analysis = stillAnalysis(rectangles: 0)

    #expect(validatedObservation(in: analysis) == nil)
}

@Test func finalStillValidationRequiresAlignmentThreshold() {
    let analysis = stillAnalysis(confidence: 0.49)

    #expect(validatedObservation(in: analysis) == nil)
}

@Test func finalStillValidationRejectsNonfiniteAlignment() {
    for confidence in [Double.nan, .infinity, -.infinity] {
        #expect(validatedObservation(in: stillAnalysis(confidence: confidence)) == nil)
    }
}

@Test func finalStillValidationRequiresAnExtractedFace() {
    let analysis = CubePhotoAnalysis(
        rectangleCandidateCount: 1,
        confidence: 0.50
    )

    #expect(validatedObservation(in: analysis) == nil)
}

@Test func finalStillValidationAcceptsExactThresholds() {
    let observation = validatedObservation(in: stillAnalysis(
        rectangles: 1,
        confidence: 0.65
    ))

    #expect(observation?.face == .front)
}

@Test func finalStillValidationAcceptsCandidateCountsAboveMinimum() {
    let observation = validatedObservation(in: stillAnalysis(
        rectangles: 9,
        confidence: 0.9
    ))

    #expect(observation?.samples.count == 9)
}

private func validatedObservation(
    in analysis: CubePhotoAnalysis
) -> CubeSingleFaceObservation? {
    CubeFinalStillValidator.validatedObservation(
        in: analysis,
        configuration: .init(
            minimumAlignmentConfidence: 0.50
        )
    )
}

private func stillAnalysis(
    rectangles: Int = 1,
    confidence: Double = 0.9
) -> CubePhotoAnalysis {
    CubePhotoAnalysis(
        rectangleCandidateCount: rectangles,
        confidence: confidence,
        singleFaceObservation: CubeSingleFaceObservation(
            face: .front,
            samples: Array(
                repeating: CubeRGBSample(red: 0.1, green: 0.7, blue: 0.2),
                count: 9
            )
        )
    )
}
