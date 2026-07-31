import Testing
@testable import CubeCoachAppLogic

@Test func initialReconstructionAppliesAllFacesWithoutChangeMarkers() throws {
    let replacements = solvedReplacements()

    let result = try CubeScanReconstructionMerger.merge(
        current: CubeScanReviewModel(),
        replacements: replacements
    )

    #expect(result.model.faceletStringURFDLB != nil)
    #expect(result.changedIndices.isEmpty)
    #expect(result.remainingUserEditedIndices.isEmpty)
}

@Test func retakeAppliesTargetAndCompensatingFaceWhileKeepingBalancedCounts() throws {
    let current = try solvedReviewModel()
    var replacements = solvedReplacements()
    replacements[.up] = replacingSticker(
        at: 0,
        with: .right,
        in: replacements[.up]!
    )
    replacements[.right] = replacingSticker(
        at: 0,
        with: .up,
        in: replacements[.right]!
    )

    let result = try CubeScanReconstructionMerger.merge(
        current: current,
        replacements: replacements,
        retakenFace: .up
    )

    #expect(result.model.stickers[0] == .face(.right))
    #expect(result.model.stickers[9] == .face(.up))
    for face in CubeScanReviewModel.faceletOrder {
        #expect(result.model.stickers.count { $0 == .face(face) } == 9)
    }
    #expect(result.changedIndices == [0, 9])
}

@Test func retakePreservesUnrelatedUserEditAndDiscardsTargetFaceEdit() throws {
    var current = try solvedReviewModel()
    let targetEdit = CubeScanReviewModel.indices(for: .up).lowerBound
    let unrelatedEdit = CubeScanReviewModel.indices(for: .front).lowerBound
    current.setSticker(.face(.back), confidence: 1, at: targetEdit)
    current.setSticker(.face(.left), confidence: 1, at: unrelatedEdit)

    let result = try CubeScanReconstructionMerger.merge(
        current: current,
        replacements: solvedReplacements(),
        retakenFace: .up,
        userEditedIndices: [targetEdit, unrelatedEdit]
    )

    #expect(result.model.stickers[targetEdit] == .face(.up))
    #expect(result.model.stickers[unrelatedEdit] == .face(.left))
    #expect(result.remainingUserEditedIndices == [unrelatedEdit])
    for face in CubeScanReviewModel.faceletOrder {
        #expect(result.model.stickers.count { $0 == .face(face) } == 9)
    }
    #expect(
        result.changedIndices == [
            targetEdit,
            unrelatedEdit,
            CubeScanReviewModel.indices(for: .left).lowerBound,
        ]
    )
}

@Test func retakeBalancesMultiplePreservedEditsDeterministically() throws {
    var current = try solvedReviewModel()
    let firstFront = CubeScanReviewModel.indices(for: .front).lowerBound
    let secondFront = firstFront + 1
    current.setSticker(.face(.left), confidence: 1, at: firstFront)
    current.setSticker(.face(.left), confidence: 1, at: secondFront)

    let result = try CubeScanReconstructionMerger.merge(
        current: current,
        replacements: solvedReplacements(),
        retakenFace: .up,
        userEditedIndices: [firstFront, secondFront]
    )

    #expect(result.model.stickers[firstFront] == .face(.left))
    #expect(result.model.stickers[secondFront] == .face(.left))
    #expect(
        result.model.stickers[
            CubeScanReviewModel.indices(for: .left).lowerBound
        ] == .face(.front)
    )
    #expect(
        result.model.stickers[
            CubeScanReviewModel.indices(for: .left).lowerBound + 1
        ] == .face(.front)
    )
    for face in CubeScanReviewModel.faceletOrder {
        #expect(result.model.stickers.count { $0 == .face(face) } == 9)
    }
}

@Test func impossibleUserEditConstraintsAreRejected() throws {
    var current = try solvedReviewModel()
    let editedIndices = Array(
        current.stickers.indices.filter {
            !current.isCenter(index: $0) &&
                !CubeScanReviewModel.indices(for: .up).contains($0)
        }.prefix(9)
    )
    for index in editedIndices {
        current.setSticker(.face(.up), confidence: 1, at: index)
    }

    #expect(
        throws: CubeScanReconstructionMergerError
            .impossibleUserEditConstraint(face: .up, fixedCount: 10)
    ) {
        try CubeScanReconstructionMerger.merge(
            current: current,
            replacements: solvedReplacements(),
            retakenFace: .up,
            userEditedIndices: Set(editedIndices)
        )
    }
}

@Test func invalidReplacementShapeDoesNotProduceAMergedDraft() throws {
    let current = try solvedReviewModel()
    let expected = try solvedReviewModel()
    var replacements = solvedReplacements()
    replacements[.back] = CubeScanFaceReplacement(
        stickers: Array(repeating: .face(.back), count: 8),
        confidences: Array(repeating: 1, count: 9)
    )

    #expect(throws: CubeScanReviewModelError.invalidStickerCount(actual: 8)) {
        try CubeScanReconstructionMerger.merge(
            current: current,
            replacements: replacements,
            retakenFace: .back
        )
    }
    #expect(current == expected)
}

@Test func initialReconstructionRejectsMalformedReplacementContents() throws {
    try assertMalformedReplacementsAreRejected(
        current: CubeScanReviewModel(),
        retakenFace: nil
    )
}

@Test func retakeRejectsMalformedReplacementContentsBeforeRebalancing() throws {
    try assertMalformedReplacementsAreRejected(
        current: solvedReviewModel(),
        retakenFace: .up
    )
}

private func solvedReviewModel() throws -> CubeScanReviewModel {
    try CubeScanReconstructionMerger.merge(
        current: CubeScanReviewModel(),
        replacements: solvedReplacements()
    ).model
}

private func solvedReplacements() -> [CubeFace: CubeScanFaceReplacement] {
    Dictionary(uniqueKeysWithValues: CubeScanReviewModel.faceletOrder.map { face in
        (
            face,
            CubeScanFaceReplacement(
                stickers: Array(repeating: .face(face), count: 9),
                confidences: Array(repeating: 0.9, count: 9)
            )
        )
    })
}

private func replacingSticker(
    at index: Int,
    with face: CubeFace,
    in replacement: CubeScanFaceReplacement
) -> CubeScanFaceReplacement {
    var stickers = replacement.stickers
    stickers[index] = .face(face)
    return CubeScanFaceReplacement(
        stickers: stickers,
        confidences: replacement.confidences
    )
}

private func assertMalformedReplacementsAreRejected(
    current: CubeScanReviewModel,
    retakenFace: CubeFace?
) throws {
    let invalidReplacements: [
        (
            replacements: [CubeFace: CubeScanFaceReplacement],
            error: CubeScanReconstructionMergerError
        )
    ] = [
        (
            replacements: replacementsWithUnfilledSticker(),
            error: .unfilledReplacement(index: 0)
        ),
        (
            replacements: replacementsWithUnfilledSticker(at: 4),
            error: .unfilledReplacement(index: 4)
        ),
        (
            replacements: unbalancedReplacements(),
            error: .invalidReplacementColorCount(face: .up, actual: 8)
        ),
        (
            replacements: replacementsWithConfidence(.nan),
            error: .invalidReplacementConfidence(index: 0)
        ),
        (
            replacements: replacementsWithConfidence(.infinity),
            error: .invalidReplacementConfidence(index: 0)
        ),
        (
            replacements: replacementsWithConfidence(-.infinity),
            error: .invalidReplacementConfidence(index: 0)
        ),
        (
            replacements: replacementsWithConfidence(-0.01),
            error: .invalidReplacementConfidence(index: 0)
        ),
        (
            replacements: replacementsWithConfidence(1.01),
            error: .invalidReplacementConfidence(index: 0)
        ),
    ]

    for invalid in invalidReplacements {
        #expect(throws: invalid.error) {
            try CubeScanReconstructionMerger.merge(
                current: current,
                replacements: invalid.replacements,
                retakenFace: retakenFace,
                userEditedIndices: [18]
            )
        }
    }
}

private func replacementsWithUnfilledSticker(
    at index: Int = 0
)
    -> [CubeFace: CubeScanFaceReplacement]
{
    var replacements = solvedReplacements()
    var stickers = replacements[.up]!.stickers
    stickers[index] = .unfilled
    replacements[.up] = CubeScanFaceReplacement(
        stickers: stickers,
        confidences: replacements[.up]!.confidences
    )
    return replacements
}

private func unbalancedReplacements()
    -> [CubeFace: CubeScanFaceReplacement]
{
    var replacements = solvedReplacements()
    replacements[.up] = replacingSticker(
        at: 0,
        with: .right,
        in: replacements[.up]!
    )
    return replacements
}

private func replacementsWithConfidence(
    _ confidence: Double
) -> [CubeFace: CubeScanFaceReplacement] {
    var replacements = solvedReplacements()
    var confidences = replacements[.up]!.confidences
    confidences[0] = confidence
    replacements[.up] = CubeScanFaceReplacement(
        stickers: replacements[.up]!.stickers,
        confidences: confidences
    )
    return replacements
}
