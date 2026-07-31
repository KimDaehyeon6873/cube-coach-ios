import Foundation

public enum CubeScanSticker: Equatable, Sendable {
    case unfilled
    case face(CubeFace)

    public var face: CubeFace? {
        guard case let .face(face) = self else { return nil }
        return face
    }
}

public enum CubeScanReviewModelError: Error, Equatable, Sendable {
    case invalidStickerCount(actual: Int)
    case invalidConfidenceCount(actual: Int)
    case centerMismatch(face: CubeFace, actual: CubeScanSticker)
}

/// Editable 54-sticker scan draft in canonical URFDLB serialization order.
///
/// Non-center stickers begin explicitly unfilled, while centers are anchored
/// to their face identity and cannot be edited.
public struct CubeScanReviewModel: Equatable, Sendable {
    public static let faceletOrder: [CubeFace] = [
        .up, .right, .front, .down, .left, .back,
    ]
    public static let stickerCount = 54
    public static let stickersPerFace = 9
    public static let centerOffset = 4

    public private(set) var stickers: [CubeScanSticker]
    public private(set) var confidences: [Double]
    public var selectedFace: CubeFace
    public private(set) var highlightIndices: Set<Int>

    public init(selectedFace: CubeFace = .up) {
        var stickers = Array(
            repeating: CubeScanSticker.unfilled,
            count: Self.stickerCount
        )
        for face in Self.faceletOrder {
            stickers[Self.centerIndex(for: face)] = .face(face)
        }

        self.stickers = stickers
        confidences = Array(repeating: 0, count: Self.stickerCount)
        for face in Self.faceletOrder {
            confidences[Self.centerIndex(for: face)] = 1
        }
        self.selectedFace = selectedFace
        highlightIndices = []
    }

    public var isComplete: Bool {
        stickers.allSatisfy { $0.face != nil }
    }

    /// A Core-compatible facelet string, available only when all 54 stickers
    /// have been filled.
    public var faceletStringURFDLB: String? {
        guard isComplete else { return nil }
        return stickers.compactMap(\.face).map(\.rawValue).joined()
    }

    public var faceletString: String? {
        faceletStringURFDLB
    }

    public static func indices(for face: CubeFace) -> Range<Int> {
        let faceIndex = faceletOrder.firstIndex(of: face)!
        let start = faceIndex * stickersPerFace
        return start..<(start + stickersPerFace)
    }

    public static func centerIndex(for face: CubeFace) -> Int {
        indices(for: face).lowerBound + centerOffset
    }

    public func isCenter(index: Int) -> Bool {
        Self.faceletOrder.contains { Self.centerIndex(for: $0) == index }
    }

    public func stickers(for face: CubeFace) -> ArraySlice<CubeScanSticker> {
        stickers[Self.indices(for: face)]
    }

    public func confidences(for face: CubeFace) -> ArraySlice<Double> {
        confidences[Self.indices(for: face)]
    }

    /// Updates one non-center sticker. Invalid indices and center edits are
    /// ignored so fixed centers remain an invariant.
    public mutating func setSticker(
        _ sticker: CubeScanSticker,
        confidence: Double,
        at index: Int
    ) {
        guard stickers.indices.contains(index), !isCenter(index: index) else {
            return
        }
        stickers[index] = sticker
        confidences[index] = Self.clampedConfidence(confidence)
    }

    public mutating func selectFace(_ face: CubeFace) {
        selectedFace = face
    }

    public mutating func setHighlightIndices<S: Sequence>(_ indices: S)
    where S.Element == Int {
        highlightIndices = Set(indices.filter(stickers.indices.contains))
    }

    public mutating func clearHighlights() {
        highlightIndices.removeAll()
    }

    /// Atomically replaces one nine-sticker face. Validation is completed
    /// before either sticker or confidence storage is mutated.
    public mutating func replaceFace(
        _ face: CubeFace,
        stickers replacementStickers: [CubeScanSticker],
        confidences replacementConfidences: [Double]
    ) throws {
        guard replacementStickers.count == Self.stickersPerFace else {
            throw CubeScanReviewModelError.invalidStickerCount(
                actual: replacementStickers.count
            )
        }
        guard replacementConfidences.count == Self.stickersPerFace else {
            throw CubeScanReviewModelError.invalidConfidenceCount(
                actual: replacementConfidences.count
            )
        }
        guard replacementStickers[Self.centerOffset] == .face(face) else {
            throw CubeScanReviewModelError.centerMismatch(
                face: face,
                actual: replacementStickers[Self.centerOffset]
            )
        }

        let range = Self.indices(for: face)
        stickers.replaceSubrange(range, with: replacementStickers)
        confidences.replaceSubrange(
            range,
            with: replacementConfidences.map(Self.clampedConfidence)
        )
    }

    public mutating func replaceFace(
        _ face: CubeFace,
        facelets: [CubeFace],
        confidences: [Double]
    ) throws {
        try replaceFace(
            face,
            stickers: facelets.map(CubeScanSticker.face),
            confidences: confidences
        )
    }

    public mutating func reset() {
        self = CubeScanReviewModel()
    }

    private static func clampedConfidence(_ confidence: Double) -> Double {
        min(1, max(0, confidence))
    }
}
