import SwiftUI

/// A short orientation legend for learners encountering Singmaster notation.
struct NotationPrimerView: View {
    enum Presentation {
        case compact
        case detailed
    }

    var presentation: Presentation = .detailed
    var showsTitle = true

    private let faces: [(letter: String, koreanName: String)] = [
        ("U", "윗면"),
        ("F", "앞면"),
        ("R", "오른쪽 면"),
        ("D", "아랫면"),
        ("B", "뒷면"),
        ("L", "왼쪽 면"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: presentation == .compact ? 8 : 12) {
            if showsTitle {
                Label("기호 읽는 법", systemImage: "textformat")
                    .font(.headline)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: presentation == .compact ? 76 : 96), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(faces, id: \.letter) { face in
                    HStack(spacing: 7) {
                        Text(face.letter)
                            .font(.body.monospaced().bold())
                            .frame(width: 24, height: 24)
                            .background(.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                        Text(face.koreanName)
                            .font(.subheadline)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(face.letter), \(face.koreanName)")
                }
            }

            Text("돌릴 면을 정면으로 보고 방향을 판단해요.")
                .font(presentation == .compact ? .footnote : .subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 82), spacing: 8)],
                spacing: 8
            ) {
                notationCard(
                    notation: "R",
                    description: "시계 90°",
                    symbol: "arrow.clockwise"
                )
                notationCard(
                    notation: "R'",
                    description: "반시계 90°",
                    symbol: "arrow.counterclockwise"
                )
                notationCard(
                    notation: "R2",
                    description: "180°",
                    symbol: "arrow.triangle.2.circlepath"
                )
            }

            if presentation == .detailed {
                Text("반시계 회전은 글자 뒤에 ' 기호를 붙여요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("고급 공식 기호")
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 112), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    advancedNotation("Rw", "오른쪽 두 겹")
                    advancedNotation("M", "가운데 세로층")
                    advancedNotation("E", "가운데 가로층")
                    advancedNotation("S", "가운데 앞뒤층")
                    advancedNotation("x · y · z", "큐브 전체 회전")
                }
            }
        }
    }

    private func advancedNotation(_ notation: String, _ description: String) -> some View {
        HStack(spacing: 8) {
            Text(notation)
                .font(.subheadline.monospaced().bold())
                .foregroundStyle(Color.coachAccent)
                .frame(minWidth: 36, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private func notationCard(
        notation: String,
        description: String,
        symbol: String
    ) -> some View {
        VStack(spacing: 5) {
            Text(notation)
                .font(.title3.monospaced().bold())
                .foregroundStyle(Color.coachAccent)
            Image(systemName: symbol)
                .font(.caption.bold())
                .accessibilityHidden(true)
            Text(description)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(notation), \(description)")
    }
}
