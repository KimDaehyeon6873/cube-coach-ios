import CubeCoachCore
import SwiftUI

/// A two-dimensional Singmaster cube net backed by URFDLB facelets.
///
/// `facelets` uses the standard 54-item order: U, R, F, D, L, then B,
/// with nine row-major stickers per face.
struct CubeNetView: View {
    enum Presentation {
        case compact
        case full
    }

    let facelets: [CubeCoachCore.CubeFace]
    var currentFaceletIndex: Int? = nil
    var presentation: Presentation = .full

    private let rowFaces: [CubeCoachCore.CubeFace] = [.left, .front, .right, .back]

    var body: some View {
        Grid(horizontalSpacing: faceSpacing, verticalSpacing: faceSpacing) {
            GridRow {
                emptyFaceSlot
                faceView(.up)
                emptyFaceSlot
                emptyFaceSlot
            }
            GridRow {
                ForEach(rowFaces, id: \.self) { face in
                    faceView(face)
                }
            }
            GridRow {
                emptyFaceSlot
                faceView(.down)
                emptyFaceSlot
                emptyFaceSlot
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("큐브 전개도")
    }

    private var faceSpacing: CGFloat {
        presentation == .compact ? 2 : 5
    }

    private var stickerSpacing: CGFloat {
        presentation == .compact ? 1 : 2
    }

    private var emptyFaceSlot: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }

    private func faceView(_ face: CubeCoachCore.CubeFace) -> some View {
        let indices = faceletIndices(for: face)

        return Grid(horizontalSpacing: stickerSpacing, verticalSpacing: stickerSpacing) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        let globalIndex = indices[row * 3 + column]
                        CubeNetSticker(
                            face: facelet(at: globalIndex),
                            isCurrent: currentFaceletIndex == globalIndex,
                            presentation: presentation
                        )
                    }
                }
            }
        }
        .padding(presentation == .compact ? 1 : 2)
        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: presentation == .compact ? 3 : 6))
        .overlay {
            RoundedRectangle(cornerRadius: presentation == .compact ? 3 : 6)
                .stroke(.primary.opacity(0.42), lineWidth: presentation == .compact ? 0.75 : 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(faceAccessibilitySummary(face, indices: indices))
    }

    private func faceletIndices(for face: CubeCoachCore.CubeFace) -> [Int] {
        let faceOrder: [CubeCoachCore.CubeFace] = [.up, .right, .front, .down, .left, .back]
        let start = (faceOrder.firstIndex(of: face) ?? 0) * 9
        return Array(start..<(start + 9))
    }

    private func facelet(at index: Int) -> CubeCoachCore.CubeFace? {
        guard facelets.indices.contains(index) else { return nil }
        return facelets[index]
    }

    private func faceAccessibilitySummary(
        _ face: CubeCoachCore.CubeFace,
        indices: [Int]
    ) -> String {
        var parts = ["\(face.koreanFaceName) \(face.letter)"]
        let availableFacelets = indices.compactMap(facelet(at:))

        if availableFacelets.count == 9 {
            let counts = CubeCoachCore.CubeFace.allCases.compactMap { colorFace -> String? in
                let count = availableFacelets.lazy.filter { $0 == colorFace }.count
                return count > 0 ? "\(colorFace.koreanColorName) \(count)개" : nil
            }
            parts.append(counts.joined(separator: ", "))
            parts.append(
                availableFacelets.enumeratedRows()
                    .map { row, facelets in
                        let stickers = facelets
                            .map { "\($0.koreanColorName) \($0.letter)" }
                            .joined(separator: ", ")
                        return "\(row + 1)행 \(stickers)"
                    }
                    .joined(separator: ". ")
            )
        } else {
            parts.append("스티커 정보 \(availableFacelets.count)개")
        }

        let localCurrent = indices.compactMap { index -> Int? in
            currentFaceletIndex == index ? index - indices[0] + 1 : nil
        }
        if let current = localCurrent.first {
            parts.append("현재 위치 \(current)번")
        }

        return parts.joined(separator: ". ")
    }
}

private extension Array where Element == CubeCoachCore.CubeFace {
    func enumeratedRows() -> [(offset: Int, element: ArraySlice<Element>)] {
        stride(from: 0, to: count, by: 3).enumerated().map { row, start in
            (row, self[start..<Swift.min(start + 3, count)])
        }
    }
}

private struct CubeNetSticker: View {
    let face: CubeCoachCore.CubeFace?
    let isCurrent: Bool
    let presentation: CubeNetView.Presentation

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: presentation == .compact ? 1.5 : 3)
                .fill(face?.stickerColor ?? Color.secondary.opacity(0.18))

            RoundedRectangle(cornerRadius: presentation == .compact ? 1.5 : 3)
                .stroke(Color.black.opacity(0.48), lineWidth: presentation == .compact ? 0.5 : 0.8)

            Text(face?.letter ?? "?")
                .font(presentation == .compact ? .system(size: 7, weight: .heavy, design: .rounded) : .caption2.bold())
                .minimumScaleFactor(0.55)
                .foregroundStyle(face?.stickerForegroundColor ?? Color.primary)
                .accessibilityHidden(true)

            if isCurrent {
                RoundedRectangle(cornerRadius: presentation == .compact ? 1.5 : 3)
                    .stroke(Color.cyan, lineWidth: presentation == .compact ? 2 : 3)
                Circle()
                    .stroke(Color.black, lineWidth: 1)
                    .padding(presentation == .compact ? 2 : 4)
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private extension CubeCoachCore.CubeFace {
    var letter: String { String(rawValue) }

    var koreanFaceName: String {
        switch self {
        case .up: "윗면"
        case .right: "오른쪽 면"
        case .front: "앞면"
        case .down: "아랫면"
        case .left: "왼쪽 면"
        case .back: "뒷면"
        }
    }

    var koreanColorName: String {
        switch self {
        case .up: "흰색"
        case .right: "빨간색"
        case .front: "초록색"
        case .down: "노란색"
        case .left: "주황색"
        case .back: "파란색"
        }
    }

    var stickerColor: Color {
        switch self {
        case .up: Color(red: 0.96, green: 0.96, blue: 0.94)
        case .right: Color(red: 0.78, green: 0.10, blue: 0.13)
        case .front: Color(red: 0.03, green: 0.52, blue: 0.27)
        case .down: Color(red: 0.98, green: 0.78, blue: 0.04)
        case .left: Color(red: 0.94, green: 0.39, blue: 0.06)
        case .back: Color(red: 0.05, green: 0.31, blue: 0.78)
        }
    }

    var stickerForegroundColor: Color {
        switch self {
        case .up, .down, .left: .black
        case .right, .front, .back: .white
        }
    }
}
