import SwiftUI

extension Color {
    static let coachAccent = Color(red: 0.29, green: 0.23, blue: 0.84)
    static let coachSuccess = Color(red: 0.08, green: 0.55, blue: 0.38)
    static let coachWarning = Color(red: 0.86, green: 0.48, blue: 0.08)
    static let coachPage = Color(uiColor: .systemGroupedBackground)
    static let coachSurface = Color(uiColor: .secondarySystemGroupedBackground)
}

struct CoachCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.coachSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.primary.opacity(0.055), lineWidth: 1)
            }
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold())
            Spacer()
            if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ProgressLabel: View {
    let completed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("학습 진도", systemImage: "chart.bar.fill")
                Spacer()
                Text("\(completed) / \(total)").monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(completed), total: Double(max(total, 1)))
                .tint(.coachAccent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("학습 진도, 전체 \(total)개 중 \(completed)개 완료")
    }
}
