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

            editorInstruction

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

    private var editorInstruction: some View {
        Group {
            if let selectedIndex {
                let localIndex = selectedIndex - startIndex
                let currentFace = facelets.indices.contains(selectedIndex)
                    ? facelets[selectedIndex]
                    : nil
                Text(
                    "선택됨 · \(scanStickerPositionName(localIndex: localIndex))\n" +
                    "현재 \(currentFace?.scanKoreanColorName ?? "미입력")"
                )
            } else {
                Text("① 바꿀 칸을 누르세요.")
            }
        }
        .font(.caption.weight(selectedIndex == nil ? .regular : .semibold))
        .foregroundStyle(selectedIndex == nil ? Color.secondary : Color.accentColor)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
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
                                    isLowConfidence ? Color.orange :
                                    isUnfilled ? Color.secondary.opacity(0.55) :
                                    Color.black.opacity(0.28),
                                style: StrokeStyle(
                                    lineWidth: isHighlighted || isCandidate ? 3 : isLowConfidence ? 2 : 1,
                                    dash: isUnfilled ? [5, 4] : []
                                )
                            )
                    }
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.accentColor, lineWidth: 4)
                                .padding(2)
                        }
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
        .accessibilityHint(
            isCenter
                ? "센터색은 바꿀 수 없습니다"
                : "두 번 탭하면 이 칸의 색상 선택기가 열립니다"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityLabel(
        facelet: CubeCoachCore.CubeFace?,
        localIndex: Int,
        isCenter: Bool,
        isHighlighted: Bool
    ) -> String {
        var parts = [
            face.scanKoreanFaceName,
            scanStickerPositionName(localIndex: localIndex),
            facelet?.scanKoreanColorName ?? "미입력",
        ]
        if isCenter { parts.append("고정 센터") }
        if isHighlighted { parts.append("확인 필요") }
        return parts.joined(separator: ", ")
    }
}

struct ScanStickerPaletteView: View {
    let face: CubeCoachCore.CubeFace
    let selectedIndex: Int?
    let currentColor: CubeCoachCore.CubeFace?
    let feedback: String?
    let onChoose: (CubeCoachCore.CubeFace) -> Void
    let onClose: () -> Void

    private let colors: [CubeCoachCore.CubeFace] = [.up, .down, .front, .back, .right, .left]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(targetInstruction)
                        .font(.caption.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(feedback ?? currentColorText)
                        .font(.caption2)
                        .foregroundStyle(feedback == nil ? Color.secondary : Color.accentColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("색상 선택기 닫기")
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3),
                spacing: 7
            ) {
                paletteButtons
            }
        }
    }

    private var targetInstruction: String {
        guard let selectedIndex else { return "먼저 바꿀 칸을 선택하세요." }
        return "② \(face.scanKoreanFaceName) · \(scanStickerPositionName(localIndex: selectedIndex % 9)) 칸의 색 선택"
    }

    private var currentColorText: String {
        "현재 \(currentColor?.scanKoreanColorName ?? "미입력") · 선택하면 바로 적용돼요."
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
                    HStack(spacing: 4) {
                        if currentColor == face {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.heavy))
                        }
                        Text(face.scanKoreanColorName)
                            .font(.caption.weight(.heavy))
                    }
                    .foregroundStyle(face.scanStickerForegroundColor)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex == nil)
            .opacity(selectedIndex == nil ? 0.45 : 1)
            .accessibilityLabel(accessibilityLabel(for: face))
            .accessibilityAddTraits(currentColor == face ? .isSelected : [])
        }
    }

    private func accessibilityLabel(for color: CubeCoachCore.CubeFace) -> String {
        guard let selectedIndex else { return "\(color.scanKoreanColorName), 선택할 칸 없음" }
        return "\(color.scanKoreanColorName), \(face.scanKoreanFaceName) \(scanStickerPositionName(localIndex: selectedIndex % 9)) 칸에 적용"
    }
}

private func scanStickerPositionName(localIndex: Int) -> String {
    switch localIndex {
    case 0: "왼쪽 위"
    case 1: "위 가운데"
    case 2: "오른쪽 위"
    case 3: "왼쪽"
    case 4: "가운데"
    case 5: "오른쪽"
    case 6: "왼쪽 아래"
    case 7: "아래 가운데"
    case 8: "오른쪽 아래"
    default: "선택한 칸"
    }
}
