import CubeCoachCore
import SwiftUI

/// Scan review net. The net is an overview and face selector; sticker editing
/// happens in a larger 3×3 editor so every control remains usable on iPhone mini.
struct ScanCubeNetView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let facelets: [CubeCoachCore.CubeFace?]
    let confidences: [Double]
    let selectedFace: CubeCoachCore.CubeFace
    let highlightedIndices: Set<Int>
    let candidateIndices: Set<Int>
    let changedIndices: Set<Int>
    let onSelectFace: (CubeCoachCore.CubeFace) -> Void

    private let middleFaces: [CubeCoachCore.CubeFace] = [.left, .front, .right, .back]

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                emptySlot
                faceButton(.up)
                emptySlot
                emptySlot
            }
            GridRow {
                ForEach(middleFaces, id: \.self) { face in
                    faceButton(face)
                }
            }
            GridRow {
                emptySlot
                faceButton(.down)
                emptySlot
                emptySlot
            }
        }
        .frame(maxWidth: 430)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("큐브 전개도")
    }

    private var emptySlot: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }

    private func faceButton(_ face: CubeCoachCore.CubeFace) -> some View {
        Button {
            onSelectFace(face)
        } label: {
            VStack(spacing: 2) {
                Text(face.scanNotation)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(selectedFace == face ? Color.accentColor : .secondary)

                Grid(horizontalSpacing: 1.5, verticalSpacing: 1.5) {
                    ForEach(0..<3, id: \.self) { row in
                        GridRow {
                            ForEach(0..<3, id: \.self) { column in
                                let index = globalIndex(face: face, localIndex: row * 3 + column)
                                sticker(at: index)
                            }
                        }
                    }
                }
            }
            .padding(3)
            .background(
                selectedFace == face ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        selectedFace == face ? Color.accentColor : Color.primary.opacity(0.18),
                        lineWidth: selectedFace == face ? 2 : 0.75
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(face.scanKoreanFaceName) 선택")
        .accessibilityHint("큰 편집기에서 이 면을 확인합니다")
    }

    private func sticker(at index: Int) -> some View {
        let facelet = facelets.indices.contains(index) ? facelets[index] : nil
        let confidence = confidences.indices.contains(index) ? confidences[index] : 0
        let isHighlighted = highlightedIndices.contains(index)
        let isCandidate = candidateIndices.contains(index)
        let didChange = changedIndices.contains(index)

        return ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(facelet?.scanStickerColor ?? Color.secondary.opacity(0.16))

            RoundedRectangle(cornerRadius: 1.5)
                .stroke(
                    isHighlighted ? Color.red :
                        isCandidate ? Color.orange :
                        didChange ? Color.blue :
                        Color.black.opacity(0.38),
                    style: StrokeStyle(
                        lineWidth: isHighlighted || isCandidate || didChange ? 2 : 0.5,
                        dash: isCandidate ? [2, 1] : []
                    )
                )

            if !dynamicTypeSize.isAccessibilitySize {
                Text(facelet.map { String($0.rawValue) } ?? "·")
                    .font(.system(size: 7, weight: .heavy, design: .rounded))
                    .foregroundStyle(facelet?.scanStickerForegroundColor ?? .secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if facelet != nil, confidence < 0.55 {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 4, height: 4)
                    .padding(1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func globalIndex(face: CubeCoachCore.CubeFace, localIndex: Int) -> Int {
        let order: [CubeCoachCore.CubeFace] = [.up, .right, .front, .down, .left, .back]
        return (order.firstIndex(of: face) ?? 0) * 9 + localIndex
    }
}

extension CubeCoachCore.CubeFace {
    var scanNotation: String { String(rawValue) }

    var scanKoreanFaceName: String {
        switch self {
        case .up: "윗면"
        case .right: "오른쪽 면"
        case .front: "앞면"
        case .down: "아랫면"
        case .left: "왼쪽 면"
        case .back: "뒷면"
        }
    }

    var scanKoreanColorName: String {
        switch self {
        case .up: "흰색"
        case .right: "빨간색"
        case .front: "초록색"
        case .down: "노란색"
        case .left: "주황색"
        case .back: "파란색"
        }
    }

    var scanShortColorName: String {
        switch self {
        case .up: "흰"
        case .right: "빨"
        case .front: "초"
        case .down: "노"
        case .left: "주"
        case .back: "파"
        }
    }

    var scanStickerColor: Color {
        switch self {
        case .up: Color(red: 0.97, green: 0.97, blue: 0.94)
        case .right: Color(red: 0.80, green: 0.09, blue: 0.13)
        case .front: Color(red: 0.02, green: 0.53, blue: 0.27)
        case .down: Color(red: 0.98, green: 0.79, blue: 0.03)
        case .left: Color(red: 0.95, green: 0.40, blue: 0.06)
        case .back: Color(red: 0.04, green: 0.30, blue: 0.80)
        }
    }

    var scanStickerForegroundColor: Color {
        switch self {
        case .up, .down, .left: .black
        case .right, .front, .back: .white
        }
    }
}
