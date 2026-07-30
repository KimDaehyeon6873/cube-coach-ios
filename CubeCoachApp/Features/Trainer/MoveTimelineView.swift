import CubeCoachCore
import SwiftUI

/// A move-only timeline. Selecting a step never mutates or calculates cube state;
/// callers provide any corresponding cube snapshots separately.
struct MoveTimelineView: View {
    let moves: [CubeMove]
    @Binding var selectedStep: Int
    var allowsAutoplay: Bool = false
    var autoplayInterval: TimeInterval = 1.2
    var onInteraction: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAutoplaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            timeline
            transportControls

            if allowsAutoplay && reduceMotion {
                Label("동작 줄이기가 켜져 있어 자동 재생 대신 단계 버튼을 사용합니다.", systemImage: "figure.walk.motion")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("동작 줄이기 사용 중. 자동 재생 없이 정적인 단계 이동을 사용합니다.")
            }
        }
        .onAppear(perform: clampSelection)
        .onChange(of: moves.count) { _, _ in
            clampSelection()
            if moves.isEmpty { isAutoplaying = false }
        }
        .onChange(of: reduceMotion) { _, newValue in
            if newValue { isAutoplaying = false }
        }
        .task(id: isAutoplaying) {
            guard isAutoplaying, allowsAutoplay, !reduceMotion else { return }
            while !Task.isCancelled && isAutoplaying {
                let nanoseconds = UInt64(max(autoplayInterval, 0.4) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                advanceAutoplayIfNeeded()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(moves.enumerated()), id: \.offset) { index, move in
                        Button {
                            select(index)
                        } label: {
                            MoveTile(
                                move: move,
                                position: index + 1,
                                total: moves.count,
                                isSelected: index == selectedStep
                            )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedStep) { _, newValue in
                guard moves.indices.contains(newValue) else { return }
                if reduceMotion {
                    proxy.scrollTo(newValue, anchor: .center)
                } else {
                    withAnimation(.snappy) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .frame(minHeight: 70)
        .accessibilityLabel("회전 공식 단계")
    }

    private var transportControls: some View {
        HStack(spacing: 8) {
            Button {
                select(0)
            } label: {
                Label("처음", systemImage: "backward.end.fill")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("첫 단계로 이동")
            .disabled(moves.isEmpty || selectedStep <= 0)

            Button {
                select(selectedStep - 1)
            } label: {
                Label("이전", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("이전 단계")
            .disabled(moves.isEmpty || selectedStep <= 0)

            Spacer(minLength: 8)

            Text(progressText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .accessibilityLabel(progressAccessibilityLabel)

            Spacer(minLength: 8)

            if allowsAutoplay && !reduceMotion {
                Button {
                    isAutoplaying.toggle()
                    onInteraction()
                } label: {
                    Label(
                        isAutoplaying ? "자동 재생 정지" : "자동 재생",
                        systemImage: isAutoplaying ? "stop.fill" : "play.fill"
                    )
                    .labelStyle(.iconOnly)
                }
                .accessibilityLabel(isAutoplaying ? "자동 재생 정지" : "자동 재생 시작")
                .disabled(moves.isEmpty)
            }

            Button {
                select(selectedStep + 1)
            } label: {
                Label("다음", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("다음 단계")
            .disabled(moves.isEmpty || selectedStep >= moves.count - 1)

            Button {
                select(moves.count - 1)
            } label: {
                Label("끝", systemImage: "forward.end.fill")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("마지막 단계로 이동")
            .disabled(moves.isEmpty || selectedStep >= moves.count - 1)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private var progressText: String {
        moves.isEmpty ? "0 / 0" : "\(selectedStep + 1) / \(moves.count)"
    }

    private var progressAccessibilityLabel: String {
        moves.isEmpty ? "회전 단계 없음" : "전체 \(moves.count)단계 중 \(selectedStep + 1)단계"
    }

    private func select(_ index: Int) {
        guard moves.indices.contains(index) else { return }
        selectedStep = index
        onInteraction()
    }

    private func clampSelection() {
        guard !moves.isEmpty else {
            selectedStep = 0
            return
        }
        selectedStep = min(max(selectedStep, 0), moves.count - 1)
    }

    private func advanceAutoplayIfNeeded() {
        guard isAutoplaying, !reduceMotion, !moves.isEmpty else { return }
        guard selectedStep < moves.count - 1 else {
            isAutoplaying = false
            return
        }
        selectedStep += 1
        onInteraction()
        if selectedStep == moves.count - 1 {
            isAutoplaying = false
        }
    }
}

private struct MoveTile: View {
    let move: CubeMove
    let position: Int
    let total: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(move.notation)
                    .font(.title3.monospaced().bold())
                Text(move.amount.directionSymbol)
                    .font(.caption.bold())
            }
            Text(move.amount.shortKoreanDescription)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(minWidth: 72, minHeight: 62)
        .background(
            isSelected ? Color.coachAccent : Color.secondary.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.primary.opacity(0.75) : Color.primary.opacity(0.28), lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(move.accessibilityDescription(position: position, total: total))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private extension CubeMove {
    func accessibilityDescription(position: Int, total: Int) -> String {
        let layer = isWide ? "두 겹 " : ""
        return "\(notation), \(layer)\(symbol.koreanTargetDescription) \(amount.fullKoreanDescription), \(position)/\(total)"
    }
}

private extension MoveSymbol {
    var koreanTargetDescription: String {
        switch self {
        case .R: "오른쪽 면"
        case .L: "왼쪽 면"
        case .U: "윗면"
        case .D: "아랫면"
        case .F: "앞면"
        case .B: "뒷면"
        case .x: "큐브 x축"
        case .y: "큐브 y축"
        case .z: "큐브 z축"
        }
    }
}

private extension TurnAmount {
    var directionSymbol: String {
        switch self {
        case .clockwise: "↻"
        case .half: "↻²"
        case .counterclockwise: "↺"
        }
    }

    var shortKoreanDescription: String {
        switch self {
        case .clockwise: "시계 90°"
        case .half: "180°"
        case .counterclockwise: "반시계 90°"
        }
    }

    var fullKoreanDescription: String {
        switch self {
        case .clockwise: "시계 방향 90도"
        case .half: "180도"
        case .counterclockwise: "반시계 방향 90도"
        }
    }
}
