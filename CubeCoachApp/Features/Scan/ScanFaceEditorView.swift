import CubeCoachCore
import SwiftUI

struct ScanFaceEditorView: View {
    let face: CubeCoachCore.CubeFace
    let facelets: [CubeCoachCore.CubeFace?]
    let confidences: [Double]
    let selectedIndex: Int?
    let highlightedIndices: Set<Int>
    let candidateIndices: Set<Int>
    let canRetake: Bool
    let onSelect: (Int) -> Void
    let onRetake: () -> Void

    private var startIndex: Int {
        let order: [CubeCoachCore.CubeFace] = [.up, .right, .front, .down, .left, .back]
        return (order.firstIndex(of: face) ?? 0) * 9
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    faceTitle
                    Spacer()
                    faceAction
                }

                VStack(alignment: .leading, spacing: 8) {
                    faceTitle
                    faceAction
                }
            }

            Text("칸을 선택한 뒤 색을 바꾸세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                spacing: 6
            ) {
                ForEach(0..<9, id: \.self) { localIndex in
                    let globalIndex = startIndex + localIndex
                    stickerButton(globalIndex: globalIndex, localIndex: localIndex)
                }
            }
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)
        }
    }

    private var faceTitle: some View {
        Text("\(face.scanKoreanFaceName) · \(face.scanNotation)")
            .font(.headline)
    }

    @ViewBuilder
    private var faceAction: some View {
        if canRetake {
            Button(action: onRetake) {
                Label("면 재촬영", systemImage: "camera.rotate")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
        } else {
            Label("센터 고정", systemImage: "lock.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func stickerButton(globalIndex: Int, localIndex: Int) -> some View {
        let facelet = facelets.indices.contains(globalIndex) ? facelets[globalIndex] : nil
        let confidence = confidences.indices.contains(globalIndex) ? confidences[globalIndex] : 0
        let isCenter = localIndex == 4
        let isSelected = selectedIndex == globalIndex
        let isHighlighted = highlightedIndices.contains(globalIndex)
        let isCandidate = candidateIndices.contains(globalIndex)
        let isUnfilled = facelet == nil
        let isLowConfidence = !isUnfilled && confidence < 0.55

        return Button {
            guard !isCenter else { return }
            onSelect(globalIndex)
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(facelet?.scanStickerColor ?? Color.secondary.opacity(0.13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(
                                    isHighlighted ? Color.red :
                                    isCandidate ? Color.orange :
                                    isSelected ? Color.accentColor :
                                    isLowConfidence ? Color.orange :
                                    isUnfilled ? Color.secondary.opacity(0.55) :
                                    Color.black.opacity(0.28),
                                style: StrokeStyle(
                                    lineWidth: isHighlighted || isCandidate || isSelected ? 3 : isLowConfidence ? 2 : 1,
                                    dash: isUnfilled ? [5, 4] : []
                                )
                            )
                    }

                Text(facelet.map { String($0.rawValue) } ?? "?")
                    .font(.title3.monospaced().weight(.heavy))
                    .foregroundStyle(facelet?.scanStickerForegroundColor ?? .secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isCenter {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(facelet?.scanStickerForegroundColor.opacity(0.8) ?? .secondary)
                        .padding(7)
                } else if isLowConfidence {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                        .padding(6)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCenter)
        .accessibilityLabel(accessibilityLabel(
            facelet: facelet,
            localIndex: localIndex,
            isCenter: isCenter,
            isHighlighted: isHighlighted
        ))
        .accessibilityHint(isCenter ? "센터색은 바꿀 수 없습니다" : "두 번 탭한 뒤 색상 팔레트에서 선택합니다")
    }

    private func accessibilityLabel(
        facelet: CubeCoachCore.CubeFace?,
        localIndex: Int,
        isCenter: Bool,
        isHighlighted: Bool
    ) -> String {
        let row = localIndex / 3 + 1
        let column = localIndex % 3 + 1
        var parts = [
            face.scanKoreanFaceName,
            "\(row)행 \(column)열",
            facelet?.scanKoreanColorName ?? "미입력",
        ]
        if isCenter { parts.append("고정 센터") }
        if isHighlighted { parts.append("확인 필요") }
        return parts.joined(separator: ", ")
    }
}

struct ScanStickerPaletteView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedIndex: Int?
    let onChoose: (CubeCoachCore.CubeFace) -> Void

    private let colors: [CubeCoachCore.CubeFace] = [.up, .down, .front, .back, .right, .left]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedIndex == nil ? "먼저 바꿀 칸을 선택하세요" : "스티커 색")
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedIndex == nil ? .secondary : .primary)

            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3),
                    spacing: 7
                ) {
                    paletteButtons
                }
            } else {
                HStack(spacing: 7) {
                    paletteButtons
                }
            }
        }
    }

    @ViewBuilder
    private var paletteButtons: some View {
        ForEach(colors, id: \.self) { face in
            Button {
                onChoose(face)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(face.scanStickerColor)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.34), lineWidth: 1)
                        }
                    VStack(spacing: 0) {
                        Text(face.scanShortColorName)
                            .font(.caption.weight(.heavy))
                        Text(face.scanNotation)
                            .font(.caption2.monospaced().weight(.bold))
                    }
                    .foregroundStyle(face.scanStickerForegroundColor)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex == nil)
            .opacity(selectedIndex == nil ? 0.45 : 1)
            .accessibilityLabel("\(face.scanKoreanColorName) 선택")
        }
    }
}
