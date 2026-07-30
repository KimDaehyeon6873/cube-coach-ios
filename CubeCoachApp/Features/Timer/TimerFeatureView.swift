import CubeCoachCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct TimerFeatureView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model: TimerFeatureModel
    @State private var lastInspectionAnnouncement = 0
    @State private var isTouchingTimer = false

    public init(model: TimerFeatureModel? = nil) {
        _model = StateObject(wrappedValue: model ?? TimerFeatureModel())
    }

    public var body: some View {
        ZStack {
            GeometryReader { geometry in
                let usesCompactLayout = geometry.size.height < 600
                    || dynamicTypeSize.isAccessibilitySize

                VStack(spacing: usesCompactLayout ? 7 : 11) {
                    modePicker
                    scramblePanel(isCompact: usesCompactLayout)
                    Divider()
                    timerPanel(isCompact: usesCompactLayout)
                }
                .padding(.horizontal, usesCompactLayout ? 14 : 18)
                .padding(.top, usesCompactLayout ? 7 : 10)
                .padding(.bottom, usesCompactLayout ? 5 : 8)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .top
                )
            }

            fullScreenStopSurface
        }
        .background(Color(uiColorOrFallback: "systemGroupedBackground"))
        // The timer is a fixed, glanceable instrument rather than a reading
        // surface. Cap its descendants at the first accessibility size so the
        // required scramble, verification net, time, and primary control stay
        // visible together without introducing scrolling.
        .dynamicTypeSize(.xSmall ... .accessibility1)
        .navigationTitle("연습")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(model.phase == .running ? .hidden : .automatic, for: .navigationBar)
        .toolbar(model.phase == .running ? .hidden : .automatic, for: .tabBar)
        .statusBarHidden(model.phase == .running)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            isTouchingTimer = false
            model.handleAppDeactivation()
        }
        .alert(
            "타이머가 중단되었어요",
            isPresented: Binding(
                get: { model.interruptionMessage != nil },
                set: { if !$0 { model.clearInterruptionMessage() } }
            )
        ) {
            Button("확인", role: .cancel) {
                model.clearInterruptionMessage()
            }
        } message: {
            Text(model.interruptionMessage ?? "")
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("연습 방식", selection: $model.mode) {
                ForEach(TimerPracticeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!canChangeMode)

            Text(
                model.mode == .wcaPractice
                    ? "WCA 방식 · 15초 이후 +2, 17초 이후 DNF"
                    : "준비되면 바로 측정"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .accessibilityHint("15초 인스펙션 모드는 연습용 플러스 2와 DNF 판정을 적용합니다")
    }

    private func scramblePanel(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 5 : 7) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Label("3×3 스크램블", systemImage: "shuffle")
                        .font(.headline)
                    Text("TNoodle 1.2.3 생성 · 대회용 아님")
                        .font(.system(size: isCompact ? 11 : 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    model.makeNewScramble()
                } label: {
                    Label("새로 만들기", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .disabled(!canChangeMode)
                .accessibilityLabel("새 스크램블 만들기")
            }

            switch model.scrambleCatalogState {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("스크램블과 전개도를 준비하는 중…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case .failed:
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "스크램블을 확인하지 못해 타이머를 잠갔어요.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.red)
                    Button("다시 불러오기") {
                        model.retryScrambleCatalogLoad()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case .ready:
                Text(model.scramble)
                    .font(
                        .system(
                            size: isCompact ? 15 : 18,
                            weight: .semibold,
                            design: .monospaced
                        )
                    )
                    .lineSpacing(isCompact ? 1 : 3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(2)
                    .textSelection(.enabled)
                    .accessibilityLabel("스크램블, \(model.scramble)")

                if let scrambledCubeState = model.scrambledCubeState {
                    HStack(alignment: .center, spacing: isCompact ? 9 : 14) {
                        CubeNetView(
                            facelets: scrambledCubeState.facelets,
                            presentation: .compact
                        )
                        .frame(width: isCompact ? 132 : 176)

                        VStack(alignment: .leading, spacing: isCompact ? 3 : 5) {
                            Text("섞은 상태 확인")
                                .font(
                                    .system(
                                        size: isCompact ? 14 : 15,
                                        weight: .bold
                                    )
                                )
                            Text("U · 흰색 위")
                            Text("F · 초록색 앞")
                            Text("전개도와 맞는지 확인")
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: isCompact ? 12 : 13))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .contain)
                } else {
                    Label(
                        "전개도를 만들지 못해 타이머를 시작할 수 없어요.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.red)
                }
            }
        }
        .padding(isCompact ? 10 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.coachSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func timerPanel(isCompact: Bool) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !needsTimeline)) { _ in
            VStack(spacing: isCompact ? 5 : 8) {
                HStack {
                    Label(timerSectionTitle, systemImage: timerSectionIcon)
                        .font(.headline)
                    Spacer()
                    if isInspection {
                        Text(inspectionStatusText)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if model.phase == .stopped,
                              let record = model.records.first {
                        penaltyMenu(for: record)
                    }
                }

                Text(primaryTime)
                    .font(
                        .system(
                            size: isCompact ? 52 : 68,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(timerColor)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Text(instructionText)
                    .font(isCompact ? .subheadline.bold() : .headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                timerPrimaryControl(isCompact: isCompact)
            }
            .padding(.horizontal, isCompact ? 2 : 4)
            .frame(maxWidth: .infinity)
            .onChange(of: inspectionMilestone) { _, milestone in
                announceInspection(milestone)
            }
        }
    }

    @ViewBuilder
    private func timerPrimaryControl(isCompact: Bool) -> some View {
        if model.mode == .wcaPractice,
           model.phase == .idle || model.phase == .stopped {
            Button {
                lastInspectionAnnouncement = 0
                model.startInspection()
            } label: {
                timerControlSurface(
                    text: "인스펙션 시작",
                    icon: "eye.fill",
                    color: model.isScrambleReady ? .coachAccent : .gray,
                    isCompact: isCompact
                )
            }
            .buttonStyle(.plain)
            .disabled(!model.isScrambleReady)
            .accessibilityHint("15초 인스펙션을 시작합니다")
        } else {
            timerTouchSurface(isCompact: isCompact)
        }
    }

    private func timerTouchSurface(isCompact: Bool) -> some View {
        timerControlSurface(
            text: touchSurfaceText,
            icon: touchSurfaceIcon,
            color: touchSurfaceColor,
            isCompact: isCompact
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isTouchingTimer else { return }
                    isTouchingTimer = true
                    model.pressBegan()
                }
                .onEnded { _ in
                    isTouchingTimer = false
                    model.pressEnded()
                }
        )
        .allowsHitTesting(model.isScrambleReady && model.phase != .running)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(touchSurfaceText)
        .accessibilityAddTraits(model.isScrambleReady ? .isButton : .isStaticText)
        .accessibilityRespondsToUserInteraction(model.isScrambleReady)
        .accessibilityHint(accessibleTimerHint)
        .accessibilityAction {
            model.activateAccessibleTimerControl()
        }
    }

    private func timerControlSurface(
        text: String,
        icon: String,
        color: Color,
        isCompact: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(color)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 68 : 92)
            .overlay {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: isCompact ? 22 : 28, weight: .semibold))
                    Text(text)
                        .font(isCompact ? .headline : .title3.bold())
                }
                .foregroundStyle(.white)
            }
    }

    private func penaltyMenu(for record: TimerSolveRecord) -> some View {
        Menu {
            ForEach(TimerSolvePenalty.allCases) { penalty in
                Button {
                    model.setPenalty(penalty, for: record.id)
                } label: {
                    Label(
                        penalty.title,
                        systemImage: record.penalty == penalty ? "checkmark" : "circle"
                    )
                }
            }
        } label: {
            Label(record.penalty.title, systemImage: "ellipsis.circle")
                .font(.subheadline)
        }
        .accessibilityLabel("페널티, \(record.penalty.title)")
        .accessibilityHint("방금 기록의 페널티를 수정합니다")
    }

    private var fullScreenStopSurface: some View {
        TimerTouchDownStopSurface(isActive: model.phase == .running) {
            model.stopRunningSolve()
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .accessibilityHidden(model.phase != .running)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("타이머 정지")
            .accessibilityHint("화면 어디든 두 번 탭하여 기록을 정지합니다")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                model.stopRunningSolve()
            }
    }

    private var needsTimeline: Bool {
        model.phase == .running || isInspection
    }

    private var timerSectionTitle: String {
        if model.phase == .stopped { return "방금 기록" }
        if isInspection { return "인스펙션" }
        return "타이머"
    }

    private var timerSectionIcon: String {
        if model.phase == .stopped { return "checkmark.circle" }
        if isInspection { return "eye" }
        return "timer"
    }

    private var canChangeMode: Bool {
        model.isScrambleReady && (model.phase == .idle || model.phase == .stopped)
    }

    private var isInspection: Bool {
        [.inspection, .inspectionHolding, .inspectionArmed].contains(model.phase)
    }

    private var primaryTime: String {
        if isInspection {
            let elapsed = model.inspectionElapsed()
            if elapsed >= 17 { return "DNF" }
            if elapsed >= 15 { return "+2" }
            return TimerTextFormatter.inspection(15 - elapsed)
        }
        if model.phase == .stopped {
            return model.records.first?.displayText ?? "0.00"
        }
        if model.phase == .running {
            return TimerTextFormatter.solveTime(model.elapsed())
        }
        return "0.00"
    }

    private var timerColor: Color {
        switch model.phase {
        case .armed, .inspectionArmed: return .green
        case .holding, .inspectionHolding: return .orange
        default: break
        }
        guard isInspection else { return .primary }
        let elapsed = model.inspectionElapsed()
        if elapsed >= 15 { return .red }
        if elapsed >= 12 { return .orange }
        if elapsed >= 8 { return .yellow }
        return .primary
    }

    private var instructionText: String {
        if model.scrambleCatalogState == .loading {
            return "스크램블 확인이 끝나면 시작할 수 있어요."
        }
        if model.scrambleCatalogState == .failed {
            return "스크램블을 다시 불러와 주세요."
        }
        return switch model.phase {
        case .idle:
            model.mode == .free ? "길게 누르세요. ‘손을 떼어 시작’이 보이면 놓으세요." : "큐브를 섞었다면 인스펙션을 시작하세요."
        case .holding, .inspectionHolding: "‘손을 떼어 시작’이 보일 때까지 누르세요."
        case .armed, .inspectionArmed: "손을 떼면 시작해요."
        case .inspection: "큐브를 확인한 뒤 길게 눌러 준비하세요."
        case .running: "화면 어디든 눌러 정지"
        case .stopped:
            model.mode == .free
                ? "다음 스크램블대로 섞고 다시 누르세요."
                : "다음 스크램블대로 섞고 인스펙션을 시작하세요."
        }
    }

    private var touchSurfaceText: String {
        if model.scrambleCatalogState == .loading { return "스크램블 불러오는 중" }
        if model.scrambleCatalogState == .failed { return "스크램블을 불러올 수 없음" }
        return switch model.phase {
        case .running: "탭하여 정지"
        case .armed, .inspectionArmed: "손을 떼어 시작"
        case .holding, .inspectionHolding: "계속 누르세요"
        case .inspection: "누르고 준비"
        default: "누르고 준비"
        }
    }

    private var touchSurfaceIcon: String {
        model.phase == .running ? "stop.fill" : "hand.tap.fill"
    }

    private var accessibleTimerHint: String {
        if model.scrambleCatalogState == .loading {
            return "스크램블 검증이 끝난 뒤 사용할 수 있습니다"
        }
        if model.scrambleCatalogState == .failed {
            return "스크램블 자료를 다시 불러온 뒤 사용할 수 있습니다"
        }
        return switch model.phase {
        case .running: "두 번 탭하여 기록을 정지합니다"
        case .inspection, .inspectionHolding, .inspectionArmed:
            "두 번 탭하여 현재 인스펙션 페널티로 기록을 시작합니다"
        case .idle where model.mode == .free,
             .stopped where model.mode == .free:
            "두 번 탭하여 접근성 방식으로 바로 기록을 시작합니다"
        default:
            "15초 인스펙션 모드에서는 먼저 인스펙션 시작 버튼을 사용합니다"
        }
    }

    private var touchSurfaceColor: Color {
        guard model.isScrambleReady else { return .gray }
        return switch model.phase {
        case .armed, .inspectionArmed: .green
        case .holding, .inspectionHolding: .orange
        case .running: .red
        case .idle where model.mode == .wcaPractice: .gray
        default: .coachAccent
        }
    }

    private var inspectionStatusText: String {
        let elapsed = model.inspectionElapsed()
        if elapsed >= 17 { return "DNF 구간 · 비공식 연습용" }
        if elapsed >= 15 { return "+2 구간 · 비공식 연습용" }
        if elapsed >= 12 { return "12초 경과 · 비공식 연습용" }
        if elapsed >= 8 { return "8초 경과 · 비공식 연습용" }
        return "비공식 연습용"
    }

    private var inspectionMilestone: Int {
        let elapsed = model.inspectionElapsed()
        if elapsed >= 17 { return 17 }
        if elapsed >= 15 { return 15 }
        if elapsed >= 12 { return 12 }
        if elapsed >= 8 { return 8 }
        return 0
    }

    private func announceInspection(_ milestone: Int) {
        guard milestone > lastInspectionAnnouncement else { return }
        lastInspectionAnnouncement = milestone
        let message: String
        switch milestone {
        case 8: message = "인스펙션 8초"
        case 12: message = "인스펙션 12초"
        case 15: message = "15초, 플러스 2"
        case 17: message = "17초, 디엔에프"
        default: return
        }
#if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
#endif
    }
}

#if canImport(UIKit)
@MainActor
private struct TimerTouchDownStopSurface: UIViewRepresentable {
    let isActive: Bool
    let onTouchDown: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTouchDown: onTouchDown)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = TouchSequenceGatedButton(type: .custom)
        button.backgroundColor = .clear
        button.acceptsNewTouchSequence = false
        button.isAccessibilityElement = false
        button.accessibilityLabel = "타이머 정지"
        button.accessibilityHint = "화면 어디든 두 번 탭하여 기록을 정지합니다"
        button.accessibilityTraits = .button
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleTouchDown(_:)),
            for: .touchDown
        )
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleTouchDown(_:)),
            for: .primaryActionTriggered
        )
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.onTouchDown = onTouchDown
        button.isAccessibilityElement = isActive
        context.coordinator.setActive(isActive, for: button)
    }

    private final class TouchSequenceGatedButton: UIButton {
        var acceptsNewTouchSequence = false

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            acceptsNewTouchSequence && super.point(inside: point, with: event)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onTouchDown: @MainActor () -> Void
        private var isActive = false

        init(onTouchDown: @escaping @MainActor () -> Void) {
            self.onTouchDown = onTouchDown
        }

        func setActive(_ newValue: Bool, for button: UIButton) {
            isActive = newValue
            (button as? TouchSequenceGatedButton)?.acceptsNewTouchSequence = newValue
        }

        @objc func handleTouchDown(_ sender: UIButton) {
            guard isActive else { return }
            isActive = false
            (sender as? TouchSequenceGatedButton)?.acceptsNewTouchSequence = false
            sender.isAccessibilityElement = false
            onTouchDown()
        }
    }
}
#else
private struct TimerTouchDownStopSurface: View {
    let isActive: Bool
    let onTouchDown: () -> Void

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isActive else { return }
                        onTouchDown()
                    }
            )
    }
}
#endif

private extension Color {
    init(uiColorOrFallback name: String) {
#if canImport(UIKit)
        self.init(uiColor: name == "systemGroupedBackground" ? .systemGroupedBackground : .systemBackground)
#else
        self = Color(nsColor: .windowBackgroundColor)
#endif
    }
}
