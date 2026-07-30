import SwiftUI

/// A short orientation legend for learners encountering Singmaster notation.
struct NotationPrimerView: View {
    enum Presentation {
        case compact
        case detailed
    }

    var presentation: Presentation = .detailed

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
            Label("기호와 보는 방향", systemImage: "viewfinder")
                .font(.headline)

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

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(Color.coachAccent)
                    .accessibilityHidden(true)
                Text("시계 방향은 돌리는 면을 정면으로 바라봤을 때를 기준으로 판단해요.")
                    .font(presentation == .compact ? .footnote : .subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("방향 기준. 시계 방향은 돌리는 면을 정면으로 바라봤을 때를 기준으로 판단합니다.")

            if presentation == .detailed {
                Text("프라임 기호(′)는 반시계 방향 90도, 숫자 2는 180도 회전을 뜻해요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("프라임 기호는 반시계 방향 90도, 숫자 2는 180도 회전을 뜻합니다.")
            }
        }
    }
}
