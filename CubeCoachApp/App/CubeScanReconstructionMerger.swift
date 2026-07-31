import Foundation

public struct CubeScanFaceReplacement: Equatable, Sendable {
    public let stickers: [CubeScanSticker]
    public let confidences: [Double]

    public init(
        stickers: [CubeScanSticker],
        confidences: [Double]
    ) {
        self.stickers = stickers
        self.confidences = confidences
    }
}

public enum CubeScanReconstructionMergerError: Error, Equatable, Sendable {
    case missingFace(CubeFace)
    case unfilledReplacement(index: Int)
    case invalidReplacementColorCount(face: CubeFace, actual: Int)
    case invalidReplacementConfidence(index: Int)
    case invalidUserEdit(index: Int)
    case impossibleUserEditConstraint(face: CubeFace, fixedCount: Int)
    case cannotBalanceReconstruction
}

public struct CubeScanReconstructionMergeResult: Equatable, Sendable {
    public let model: CubeScanReviewModel
    public let changedIndices: Set<Int>
    public let remainingUserEditedIndices: Set<Int>

    public init(
        model: CubeScanReviewModel,
        changedIndices: Set<Int>,
        remainingUserEditedIndices: Set<Int>
    ) {
        self.model = model
        self.changedIndices = changedIndices
        self.remainingUserEditedIndices = remainingUserEditedIndices
    }
}

/// Atomically merges a balanced six-face reconstruction into a scan review
/// draft while retaining explicit edits that are unrelated to a retaken face.
public enum CubeScanReconstructionMerger {
    public static func merge(
        current: CubeScanReviewModel,
        replacements: [CubeFace: CubeScanFaceReplacement],
        retakenFace: CubeFace? = nil,
        userEditedIndices: Set<Int> = []
    ) throws -> CubeScanReconstructionMergeResult {
        var reconstructed = current

        // A reconstruction must be complete and balanced before user edits
        // are preserved. Rebalancing is reserved for imbalance introduced by
        // those preserved edits, not malformed classifier output.
        try validate(replacements)

        for face in CubeScanReviewModel.faceletOrder {
            let replacement = replacements[face]!
            try reconstructed.replaceFace(
                face,
                stickers: replacement.stickers,
                confidences: replacement.confidences
            )
        }

        guard let retakenFace else {
            return CubeScanReconstructionMergeResult(
                model: reconstructed,
                changedIndices: [],
                remainingUserEditedIndices: []
            )
        }

        let retakenIndices = Set(CubeScanReviewModel.indices(for: retakenFace))
        let remainingUserEditedIndices = Set(userEditedIndices.filter { index in
            current.stickers.indices.contains(index) &&
                !current.isCenter(index: index) &&
                !retakenIndices.contains(index)
        })

        for index in remainingUserEditedIndices {
            reconstructed.setSticker(
                current.stickers[index],
                confidence: current.confidences[index],
                at: index
            )
        }

        try rebalance(
            &reconstructed,
            preserving: remainingUserEditedIndices
        )

        var changedIndices = remainingUserEditedIndices
        for index in current.stickers.indices
        where reconstructed.stickers[index] != current.stickers[index] {
            changedIndices.insert(index)
        }

        return CubeScanReconstructionMergeResult(
            model: reconstructed,
            changedIndices: changedIndices,
            remainingUserEditedIndices: remainingUserEditedIndices
        )
    }

    private static func validate(
        _ replacements: [CubeFace: CubeScanFaceReplacement]
    ) throws {
        var counts = Dictionary(
            uniqueKeysWithValues: CubeScanReviewModel.faceletOrder.map {
                ($0, 0)
            }
        )

        for face in CubeScanReviewModel.faceletOrder {
            guard let replacement = replacements[face] else {
                throw CubeScanReconstructionMergerError.missingFace(face)
            }
            guard replacement.stickers.count ==
                CubeScanReviewModel.stickersPerFace
            else {
                throw CubeScanReviewModelError.invalidStickerCount(
                    actual: replacement.stickers.count
                )
            }
            guard replacement.confidences.count ==
                CubeScanReviewModel.stickersPerFace
            else {
                throw CubeScanReviewModelError.invalidConfidenceCount(
                    actual: replacement.confidences.count
                )
            }
            for localIndex in replacement.stickers.indices {
                let index =
                    CubeScanReviewModel.indices(for: face).lowerBound +
                    localIndex
                guard let stickerFace =
                    replacement.stickers[localIndex].face
                else {
                    throw CubeScanReconstructionMergerError
                        .unfilledReplacement(index: index)
                }
                counts[stickerFace, default: 0] += 1

                let confidence = replacement.confidences[localIndex]
                guard confidence.isFinite, (0...1).contains(confidence) else {
                    throw CubeScanReconstructionMergerError
                        .invalidReplacementConfidence(index: index)
                }
            }

            guard replacement.stickers[CubeScanReviewModel.centerOffset] ==
                .face(face)
            else {
                throw CubeScanReviewModelError.centerMismatch(
                    face: face,
                    actual: replacement.stickers[
                        CubeScanReviewModel.centerOffset
                    ]
                )
            }
        }

        for face in CubeScanReviewModel.faceletOrder {
            let actual = counts[face, default: 0]
            guard actual == CubeScanReviewModel.stickersPerFace else {
                throw CubeScanReconstructionMergerError
                    .invalidReplacementColorCount(face: face, actual: actual)
            }
        }
    }

    /// Treats explicit user edits as fixed constraints, then makes the
    /// smallest possible number of changes to the remaining reconstruction so
    /// every color has exactly nine stickers. When several minimum solutions
    /// exist, the least-confident reconstructed stickers are changed first,
    /// with canonical facelet index as the deterministic tie-breaker.
    private static func rebalance(
        _ model: inout CubeScanReviewModel,
        preserving userEditedIndices: Set<Int>
    ) throws {
        var fixedCounts = Dictionary(
            uniqueKeysWithValues: CubeScanReviewModel.faceletOrder.map {
                ($0, 1)
            }
        )

        for index in userEditedIndices.sorted() {
            guard let face = model.stickers[index].face else {
                throw CubeScanReconstructionMergerError.invalidUserEdit(
                    index: index
                )
            }
            fixedCounts[face, default: 0] += 1
        }

        for face in CubeScanReviewModel.faceletOrder {
            let fixedCount = fixedCounts[face, default: 0]
            guard fixedCount <= CubeScanReviewModel.stickersPerFace else {
                throw CubeScanReconstructionMergerError
                    .impossibleUserEditConstraint(
                        face: face,
                        fixedCount: fixedCount
                    )
            }
        }

        var counts = Dictionary(
            uniqueKeysWithValues: CubeScanReviewModel.faceletOrder.map {
                ($0, 0)
            }
        )
        for sticker in model.stickers {
            guard let face = sticker.face else {
                throw CubeScanReconstructionMergerError
                    .cannotBalanceReconstruction
            }
            counts[face, default: 0] += 1
        }

        var excessByFace: [CubeFace: Int] = [:]
        var deficitFaces: [CubeFace] = []
        for face in CubeScanReviewModel.faceletOrder {
            let difference =
                counts[face, default: 0] -
                CubeScanReviewModel.stickersPerFace
            if difference > 0 {
                excessByFace[face] = difference
            } else if difference < 0 {
                deficitFaces.append(
                    contentsOf: repeatElement(face, count: -difference)
                )
            }
        }

        let candidates = model.stickers.indices
            .filter { index in
                !model.isCenter(index: index) &&
                    !userEditedIndices.contains(index) &&
                    model.stickers[index].face.map {
                        excessByFace[$0, default: 0] > 0
                    } == true
            }
            .sorted { lhs, rhs in
                let lhsConfidence = sortableConfidence(
                    model.confidences[lhs]
                )
                let rhsConfidence = sortableConfidence(
                    model.confidences[rhs]
                )
                if lhsConfidence != rhsConfidence {
                    return lhsConfidence < rhsConfidence
                }
                return lhs < rhs
            }

        var reassignmentIndices: [Int] = []
        for index in candidates {
            guard
                let face = model.stickers[index].face,
                excessByFace[face, default: 0] > 0
            else {
                continue
            }
            reassignmentIndices.append(index)
            excessByFace[face, default: 0] -= 1
        }

        guard reassignmentIndices.count == deficitFaces.count else {
            throw CubeScanReconstructionMergerError
                .cannotBalanceReconstruction
        }

        for (index, face) in zip(reassignmentIndices, deficitFaces) {
            model.setSticker(.face(face), confidence: 0, at: index)
        }

        for face in CubeScanReviewModel.faceletOrder {
            guard model.stickers.count(where: { $0 == .face(face) }) ==
                CubeScanReviewModel.stickersPerFace
            else {
                throw CubeScanReconstructionMergerError
                    .cannotBalanceReconstruction
            }
        }
    }

    private static func sortableConfidence(_ confidence: Double) -> Double {
        confidence.isFinite ? confidence : 0
    }
}
