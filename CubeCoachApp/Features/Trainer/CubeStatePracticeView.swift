import CubeCoachCore
import SwiftUI

/// Runs a physical practice attempt from one reviewed scan without generating
/// a scramble or revealing a solution sequence.
struct CubeStatePracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var store: LearningProgressStore

    @ObservedObject var model: CubeStatePracticeSessionModel
    private let onFinish: (() -> Void)?

    @State private var resultScanRequestID: UUID?
    @State private var showsResultScanner = false
    @State private var showsTrainer = false
    @State private var showsConceptPractice = false
    @State private var recommendedCases: [StudyCaseUI] = []
    @State private var conceptDiagnosis: CubePracticeDiagnosis?
    @State private var abandonsSessionOnDisappear = false

    init(
        model: CubeStatePracticeSessionModel,
        onFinish: (() -> Void)? = nil
    ) {
        self.model = model
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            if model.phase == .running {
                runningView
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        phaseContent(
                            usesMiniLayout: geometry.size.width < 390
                                || geometry.size.height < 700
                                || dynamicTypeSize.isAccessibilitySize
                        )
                        .padding(geometry.size.width < 390 ? 14 : 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .background(model.phase == .running ? Color.black : Color.coachPage)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(model.phase == .running ? .hidden : .automatic, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(model.phase == .running)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active, model.phase == .running else { return }
            model.stop(reason: .interrupted)
        }
        .onDisappear {
            guard abandonsSessionOnDisappear else { return }
            model.abandon()
        }
        .fullScreenCover(
            isPresented: $showsResultScanner,
            onDismiss: cancelPendingResultScan
        ) {
            NavigationStack {
                CubeScanFeatureView(purpose: .practiceResult) { scan in
                    acceptResultScan(scan)
                }
            }
        }
        .navigationDestination(isPresented: $showsTrainer) {
            TrainerView(initialCases: recommendedCases, mode: .scanRecommendation)
        }
        .navigationDestination(isPresented: $showsConceptPractice) {
            if let conceptDiagnosis {
                ScanConceptPracticeView(diagnosis: conceptDiagnosis)
            }
        }
        .toolbar {
            if model.phase != .running {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("끝내기") {
                        finishPractice()
                    }
                    .accessibilityHint("현재 상태 연습을 종료합니다")
                }
            }
        }
    }

    @ViewBuilder
    private func phaseContent(usesMiniLayout: Bool) -> some View {
        switch model.phase {
        case .briefing:
            briefingView
        case .awaitingResultScan(let reason):
            pausedView(reason: reason)
        case .scanningResult:
            ProgressView("결과 촬영을 준비하고 있어요")
                .frame(maxWidth: .infinity, minHeight: 320)
        case .result(let comparison):
            resultView(comparison: comparison, usesMiniLayout: usesMiniLayout)
        case .abandoned:
            EmptyView()
        case .running:
            EmptyView()
        }
    }

    private var briefingView: some View {
        VStack(alignment: .leading, spacing: 18) {
            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("촬영한 시작 상태", systemImage: "viewfinder")
                        .font(.headline)
                        .foregroundStyle(Color.coachAccent)

                    CubeNetView(
                        facelets: model.initialScan.state.facelets,
                        presentation: .full
                    )
                    .frame(maxWidth: 350)
                    .frame(maxWidth: .infinity)

                    Label("흰색 U 위 · 초록색 F 앞", systemImage: "cube.transparent")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            goalCard

            Text("큐브를 이 방향 그대로 잡고 시작하세요. 별도의 스크램블은 하지 않아요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                model.start()
            } label: {
                Label("타이머 시작", systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("촬영한 상태 그대로 연습을 시작합니다")
        }
    }

    private var runningView: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                VStack(spacing: 20) {
                    Spacer()

                    Text(TimerTextFormatter.solveTime(model.elapsed()))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(.white)
                        .accessibilityLabel("연습 시간 \(TimerTextFormatter.solveTime(model.elapsed()))")

                    Text(model.initialScan.diagnosis.practiceGoal)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)

                    Spacer()

                    Text("화면 어디든 눌러 시도 멈추기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.bottom, 24)
                }
            }

            TimerTouchDownStopSurface(isActive: model.phase == .running) {
                model.stop(reason: .completed)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("시도 멈추기")
            .accessibilityHint("화면 어디든 두 번 탭하여 타이머를 멈춥니다")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                model.stop(reason: .completed)
            }
        }
    }

    private func pausedView(reason: CubeStatePracticeSessionModel.StopReason) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(TimerTextFormatter.solveTime(model.elapsed()))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                Text(pauseMessage(for: reason))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            goalCard

            if let highestHintIndex = model.highestHintIndex {
                hintCard(through: highestHintIndex)
            }

            Button(action: beginResultScan) {
                Label("결과 상태 다시 촬영", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("현재 실물 큐브를 촬영해 시작 상태와 비교합니다")

            Button {
                model.resume()
            } label: {
                Label("이어서 시도", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(model.highestHintIndex == nil ? "막혔어요" : "힌트가 더 필요해요")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    model.markStuck()
                    model.revealNextHint(maximumCount: currentHints.count)
                } label: {
                    Label(
                        nextHintButtonTitle,
                        systemImage: "lightbulb"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!canRevealAnotherHint)
                .accessibilityHint("공식 없이 관찰할 지점을 한 단계씩 보여 줍니다")

                Button(action: openRelatedLearning) {
                    Label("관련 학습 열기", systemImage: "books.vertical.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var goalCard: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("이번 목표", systemImage: "scope")
                    .font(.headline)
                    .foregroundStyle(Color.coachAccent)
                Text(model.initialScan.diagnosis.practiceGoal)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func hintCard(through highestIndex: Int) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("단계별 힌트", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundStyle(Color.coachWarning)

                ForEach(Array(currentHints.prefix(highestIndex + 1).enumerated()), id: \.offset) {
                    index,
                    hint in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.coachWarning, in: Circle())
                            .accessibilityHidden(true)
                        Text(hint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("힌트 \(index + 1), \(hint)")
                }
            }
        }
    }

    private func resultView(
        comparison: CubePracticeComparison,
        usesMiniLayout: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            CoachCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        comparisonTitle(comparison.outcome),
                        systemImage: comparisonIcon(comparison.outcome)
                    )
                    .font(.title3.bold())
                    .foregroundStyle(comparisonColor(comparison.outcome))

                    Text(comparisonDetail(comparison))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("검토한 두 전개도의 \(comparison.changedFaceletIndices.count)칸이 달라요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            comparisonNets(usesMiniLayout: usesMiniLayout)

            CoachCard {
                HStack {
                    resultMetric(
                        title: "연습 시간",
                        value: TimerTextFormatter.solveTime(model.elapsed()),
                        icon: "timer"
                    )
                    Divider()
                    resultMetric(
                        title: "사용한 힌트",
                        value: "\(revealedHintCount)개",
                        icon: "lightbulb"
                    )
                }
                .frame(maxWidth: .infinity)
            }

            if canContinueFromResult {
                Button {
                    model.continueFromResult()
                } label: {
                    Label("현재 상태로 계속 연습", systemImage: "arrow.forward.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("결과로 촬영한 상태와 방향을 새 시작점으로 사용합니다")
            }

            Button(action: openRelatedLearning) {
                Label("관련 학습 열기", systemImage: "books.vertical.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                finishPractice()
            } label: {
                Text("연습 끝내기")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func comparisonNets(usesMiniLayout: Bool) -> some View {
        let layout = usesMiniLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))

        return layout {
            stateNet(
                title: "시작",
                facelets: model.initialScan.state.facelets
            )
            if let resultScan = model.resultScan {
                stateNet(
                    title: "결과",
                    facelets: resultScan.state.facelets
                )
            }
        }
    }

    private func stateNet(
        title: String,
        facelets: [CubeCoachCore.CubeFace]
    ) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                CubeNetView(facelets: facelets, presentation: .compact)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                Text("흰색 U 위 · 초록색 F 앞")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func resultMetric(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var navigationTitle: String {
        switch model.phase {
        case .briefing:
            "이 상태로 연습"
        case .running:
            ""
        case .awaitingResultScan, .scanningResult:
            "시도 확인"
        case .result:
            "전후 상태 비교"
        case .abandoned:
            "연습 종료"
        }
    }

    private var currentHints: [String] {
        guard let goal = model.initialScan.diagnosis.goalID else { return [] }
        return Self.hints(for: goal)
    }

    private var revealedHintCount: Int {
        model.highestHintIndex.map { $0 + 1 } ?? 0
    }

    private var canRevealAnotherHint: Bool {
        revealedHintCount < currentHints.count
    }

    private var nextHintButtonTitle: String {
        if model.highestHintIndex == nil { return "첫 힌트 보기" }
        if canRevealAnotherHint { return "다음 힌트 보기" }
        return "힌트를 모두 확인했어요"
    }

    private var canContinueFromResult: Bool {
        guard let resultScan = model.resultScan else { return false }
        return !resultScan.diagnosis.isSolved && resultScan.diagnosis.goalID != nil
    }

    private func pauseMessage(
        for reason: CubeStatePracticeSessionModel.StopReason
    ) -> String {
        switch reason {
        case .completed:
            "시도를 멈췄어요. 지금 상태를 촬영하면 시작 상태와 비교할 수 있어요."
        case .stuck:
            "막힌 지점에서 멈췄어요. 힌트를 보거나 현재 상태를 촬영해 보세요."
        case .interrupted:
            "앱이 잠시 비활성화되어 타이머를 안전하게 멈췄어요."
        }
    }

    private func beginResultScan() {
        guard let requestID = model.beginResultScan() else { return }
        resultScanRequestID = requestID
        showsResultScanner = true
    }

    private func acceptResultScan(_ scan: ValidatedCubeScan) {
        guard let requestID = resultScanRequestID,
              model.acceptResultScan(scan, requestID: requestID)
        else { return }
        resultScanRequestID = nil
        showsResultScanner = false
    }

    private func cancelPendingResultScan() {
        guard let requestID = resultScanRequestID else { return }
        model.cancelResultScan(requestID: requestID)
        resultScanRequestID = nil
    }

    private func finishPractice() {
        abandonsSessionOnDisappear = true
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }

    private func openRelatedLearning() {
        let diagnosis = model.initialScan.diagnosis
        let cases = practiceCases(for: diagnosis)
        if cases.isEmpty {
            conceptDiagnosis = diagnosis
            showsConceptPractice = true
        } else {
            recommendedCases = cases
            showsTrainer = true
        }
    }

    private func practiceCases(for diagnosis: CubePracticeDiagnosis) -> [StudyCaseUI] {
        guard let curriculum = CurriculumCatalog.builtIn.first(where: {
            $0.track == diagnosis.recommendedCurriculumTrack
        }),
        let lesson = curriculum.lessons.first(where: {
            $0.id == diagnosis.recommendedLessonID
        }) else {
            return []
        }

        let caseIDs = lesson.algorithms.isEmpty
            ? [lesson.id]
            : lesson.algorithms.map(\.id)
        return store.catalog.filter {
            caseIDs.contains($0.id) && $0.exercise != nil
        }
    }

    private func comparisonTitle(_ outcome: CubePracticeComparisonOutcome) -> String {
        switch outcome {
        case .achieved:
            "촬영 결과에서 목표를 확인했어요"
        case .improved:
            "목표에 더 가까워졌어요"
        case .unchanged:
            "측정된 진행도는 같아요"
        case .regressed:
            "보존할 영역을 다시 확인해 보세요"
        }
    }

    private func comparisonDetail(_ comparison: CubePracticeComparison) -> String {
        switch comparison.outcome {
        case .achieved:
            "결과 전개도에서 이번 목표 조건이 충족된 것으로 확인됐어요."
        case .improved:
            "결과 전개도에서 목표 조각이 더 많이 맞았지만 아직 목표 조건 전체는 충족되지 않았어요."
        case .unchanged:
            comparison.changedFaceletIndices.isEmpty
                ? "두 촬영의 전개도가 같아 측정된 진행 변화가 없어요."
                : "상태는 바뀌었지만 이번 목표 기준의 측정된 진행도는 같아요."
        case .regressed:
            "결과 전개도에서 이번 목표의 선행 완성 영역이 시작보다 줄어든 것으로 확인됐어요."
        }
    }

    private func comparisonIcon(_ outcome: CubePracticeComparisonOutcome) -> String {
        switch outcome {
        case .achieved:
            "checkmark.seal.fill"
        case .improved:
            "arrow.up.right.circle.fill"
        case .unchanged:
            "equal.circle.fill"
        case .regressed:
            "arrow.counterclockwise.circle.fill"
        }
    }

    private func comparisonColor(_ outcome: CubePracticeComparisonOutcome) -> Color {
        switch outcome {
        case .achieved:
            .coachSuccess
        case .improved:
            .coachAccent
        case .unchanged:
            .secondary
        case .regressed:
            .coachWarning
        }
    }

    private static func hints(for goal: CubePracticeGoalID) -> [String] {
        switch goal {
        case .cross:
            [
                "D면 색이 있는 엣지 네 개를 먼저 찾고, 각 조각의 다른 색도 함께 확인하세요.",
                "엣지의 옆색이 같은 색 센터와 만나는지 한 조각씩 점검하세요.",
                "맞은 엣지를 보존한 채 아직 맞지 않은 엣지 하나만 목표 위치로 옮겨 보세요.",
            ]
        case .firstLayer:
            [
                "D면 코너 하나의 세 색을 보고 세 센터가 만나는 목표 슬롯을 찾으세요.",
                "완성한 십자가 흐트러지지 않는지 매번 확인하세요.",
                "목표 코너를 슬롯 위쪽 주변으로 가져온 뒤 들어가는 방향을 관찰하세요.",
            ]
        case .f2l:
            [
                "U면 색이 없는 중간층 엣지 하나를 찾고 두 색의 센터를 확인하세요.",
                "엣지의 앞쪽 색을 같은 센터에 맞춘 뒤 들어갈 슬롯이 왼쪽인지 오른쪽인지 보세요.",
                "완성된 첫 층을 보존하면서 목표 슬롯 주변만 움직이는 경로를 찾아보세요.",
            ]
        case .ollEdges:
            [
                "U면 센터와 같은 색을 향한 엣지가 몇 개인지 먼저 세어 보세요.",
                "이미 U면을 향한 엣지들의 배치가 점, 꺾임, 선 중 무엇인지 관찰하세요.",
                "F2L 블록을 보존하면서 U면 엣지 방향만 바뀌어야 한다는 점을 확인하세요.",
            ]
        case .ollCorners:
            [
                "U면 코너 네 개에서 U면 색이 어느 방향을 향하는지 차례로 확인하세요.",
                "U면 십자가와 F2L은 그대로 유지되어야 해요.",
                "같은 방향을 향한 코너들을 기준으로 큐브 앞면을 다시 정해 보세요.",
            ]
        case .pllCorners:
            [
                "코너의 세 색 조합이 주변 세 센터와 일치하는 위치인지 확인하세요.",
                "서로 맞는 코너 한 쌍이 있는지 옆면 색을 비교해 보세요.",
                "U면 색 방향을 유지하면서 코너 위치만 바뀌어야 해요.",
            ]
        case .pllEdges:
            [
                "네 옆면에서 센터와 같은 색을 향한 엣지가 있는지 확인하세요.",
                "이미 맞은 면이 있다면 그 면을 기준으로 나머지 엣지의 이동 방향을 관찰하세요.",
                "맞춰진 코너와 U면 색 방향을 끝까지 보존하세요.",
            ]
        case .auf:
            [
                "U면을 돌리기 전에 네 옆면의 윗줄과 센터 색을 비교하세요.",
                "한 옆면의 윗줄 색을 같은 센터에 맞춘 뒤 다른 세 면도 함께 확인하세요.",
                "옆면 네 곳이 모두 센터 색과 이어지는 U면 위치를 찾으세요.",
            ]
        }
    }
}

#if DEBUG
@MainActor
struct CubeStatePracticePreviewHost: View {
    enum Mode {
        case briefing
        case paused
        case result
    }

    @StateObject private var model: CubeStatePracticeSessionModel
    @State private var showsPractice = true

    init(mode: Mode) {
        let startAlgorithm = try! WCAParser.parse("R U R' U'")
        let startState = try! CubeExecutionState()
            .applying(startAlgorithm)
            .cube
        let startScan = ValidatedCubeScan(
            state: startState
        )
        let session = try! CubeStatePracticeSessionModel(
            initialScan: startScan
        )

        if mode != .briefing {
            _ = session.start()
            _ = session.stop(reason: .completed)
        }
        if mode == .result, let requestID = session.beginResultScan() {
            let resultScan = ValidatedCubeScan(
                state: .solved
            )
            _ = session.acceptResultScan(resultScan, requestID: requestID)
        }

        _model = StateObject(wrappedValue: session)
    }

    var body: some View {
        Text("연습 종료 완료")
            .font(.title2.bold())
            .accessibilityIdentifier("state-practice-finish-confirmation")
            .navigationDestination(isPresented: $showsPractice) {
                CubeStatePracticeView(model: model) {
                    showsPractice = false
                }
            }
    }
}
#endif
