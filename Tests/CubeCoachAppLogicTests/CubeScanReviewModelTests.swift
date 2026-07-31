import Testing
@testable import CubeCoachAppLogic

@Test func reviewDraftStartsUnfilledWithLockedURFDLBCenters() {
    let model = CubeScanReviewModel()

    #expect(model.stickers.count == 54)
    #expect(model.confidences.count == 54)
    #expect(model.faceletStringURFDLB == nil)
    #expect(model.selectedFace == .up)

    for face in CubeScanReviewModel.faceletOrder {
        let center = CubeScanReviewModel.centerIndex(for: face)
        #expect(model.stickers[center] == .face(face))
        #expect(model.confidences[center] == 1)
        #expect(model.isCenter(index: center))
    }
}

@Test func centersCannotBeEditedButNonCentersCan() {
    var model = CubeScanReviewModel()
    let center = CubeScanReviewModel.centerIndex(for: .up)

    model.setSticker(.face(.back), confidence: 0.2, at: center)
    #expect(model.stickers[center] == .face(.up))
    #expect(model.confidences[center] == 1)

    model.setSticker(.face(.front), confidence: 1.4, at: 0)
    #expect(model.stickers[0] == .face(.front))
    #expect(model.confidences[0] == 1)
}

@Test func replacingOneFaceIsAtomicAndPreservesOtherFortyFiveCells() throws {
    var model = CubeScanReviewModel()
    let beforeStickers = model.stickers
    let beforeConfidences = model.confidences
    let replacement = Array(repeating: CubeFace.front, count: 9)

    try model.replaceFace(
        .front,
        facelets: replacement,
        confidences: Array(repeating: 0.8, count: 9)
    )

    let replacedIndices = Set(CubeScanReviewModel.indices(for: .front))
    for index in 0..<54 where !replacedIndices.contains(index) {
        #expect(model.stickers[index] == beforeStickers[index])
        #expect(model.confidences[index] == beforeConfidences[index])
    }
    #expect(Array(model.stickers(for: .front)) == replacement.map(CubeScanSticker.face))
}

@Test func invalidFaceReplacementDoesNotPartiallyMutateDraft() {
    var model = CubeScanReviewModel()
    let before = model
    var wrongCenter = Array(repeating: CubeScanSticker.face(.right), count: 9)
    wrongCenter[4] = .face(.up)

    #expect(throws: CubeScanReviewModelError.centerMismatch(
        face: .right,
        actual: .face(.up)
    )) {
        try model.replaceFace(
            .right,
            stickers: wrongCenter,
            confidences: Array(repeating: 0.5, count: 9)
        )
    }
    #expect(model == before)
}

@Test func completeDraftSerializesInCanonicalURFDLBOrder() throws {
    var model = CubeScanReviewModel()

    for face in CubeScanReviewModel.faceletOrder {
        try model.replaceFace(
            face,
            facelets: Array(repeating: face, count: 9),
            confidences: Array(repeating: 0.9, count: 9)
        )
    }

    #expect(model.faceletStringURFDLB ==
        String(repeating: "U", count: 9) +
        String(repeating: "R", count: 9) +
        String(repeating: "F", count: 9) +
        String(repeating: "D", count: 9) +
        String(repeating: "L", count: 9) +
        String(repeating: "B", count: 9))
}

@Test func selectionHighlightsAndResetAreIndependentDraftState() {
    var model = CubeScanReviewModel()
    model.selectFace(.back)
    model.setHighlightIndices([-1, 0, 4, 53, 54])

    #expect(model.selectedFace == .back)
    #expect(model.highlightIndices == [0, 4, 53])

    model.reset()

    #expect(model == CubeScanReviewModel())
}
