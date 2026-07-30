import CubeCoachCore
import SwiftUI

struct TrainerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: LearningProgressStore
    @State private var queue: [StudyCaseUI]
    @State private var session: TrainerSessionState
    @State private var hasConfiguredSession: Bool
    @State private var attempt: TrainerAttemptState?
    @State private var selectedRecognition: String?
    @State private var needsRecognitionCorrection = false
    @State private var showsSetupSupport = false
    @State private var physicalExecutionFinished = false
    @State private var setupStep = 0
    @State private var hintStep = 0
    @State private var resultStep = 0
    private let loadsDueCasesOnAppear: Bool
    private let mode: PracticeMode

    init(initialCases: [StudyCaseUI]? = nil, mode: PracticeMode = .review) {
        let cases = (initialCases ?? []).filter { $0.exercise != nil }
        _queue = State(initialValue: cases)
        _session = State(initialValue: TrainerSessionState(itemCount: cases.count))
        _hasConfiguredSession = State(initialValue: initialCases != nil)
        loadsDueCasesOnAppear = initialCases == nil
        self.mode = mode
    }

    private var current: (index: Int, learningCase: StudyCaseUI, exercise: CompiledLearningExercise)? {
        guard hasConfiguredSession,
              let index = session.currentIndex,
              queue.indices.contains(index),
              let exercise = queue[index].exercise
        else { return nil }
        return (index, queue[index], exercise)
    }

    var body: some View {
        Group {
            if !hasConfiguredSession {
                ProgressView("\(activityName) 준비 중")
            } else if let current,
                      let attempt,
                      attempt.caseID == current.learningCase.id {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            progressHeader(index: current.index)
                                .id(Self.scrollTopID)
                            phaseContent(current: current, attempt: attempt)
                        }
                        .padding()
                    }
                    .onChange(of: attempt.phase.rawValue) { _, _ in
                        scrollToPhaseStart(using: proxy)
                    }
                }
            } else {
                completionView
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: configureSessionIfNeeded)
        .onChange(of: session.reviewedCount) { _, _ in configureAttemptIfNeeded() }
    }

    private static let scrollTopID = "trainer-phase-start"

    private func scrollToPhaseStart(using proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(Self.scrollTopID, anchor: .top)
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.scrollTopID, anchor: .top)
            }
        }
    }

    private func progressHeader(index: Int) -> some View {
        HStack {
            Label("준비 → 인식 → 실행 → 확인", systemImage: "square.stack.3d.up.fill")
            Spacer()
            Text("\(index + 1) / \(session.itemCount)")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func phaseContent(
        current: (index: Int, learningCase: StudyCaseUI, exercise: CompiledLearningExercise),
        attempt: TrainerAttemptState
    ) -> some View {
        switch attempt.phase {
        case .prepare:
            prepareView(case: current.learningCase, exercise: current.exercise)
        case .recognize:
            recognitionView(case: current.learningCase, exercise: current.exercise)
        case .recall, .playback:
            recallView(case: current.learningCase, exercise: current.exercise, attempt: attempt)
        case .execute:
            executionView(exercise: current.exercise)
        case .compare:
            ProgressView("결과 기록 중")
        case .result:
            resultView(current: current, attempt: attempt)
        }
    }

    private func prepareView(
        case learningCase: StudyCaseUI,
        exercise: CompiledLearningExercise
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if mode == .scanRecommendation {
                CoachCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("스캔 진단 기반 대표 연습", systemImage: "camera.metering.matrix")
                            .font(.headline)
                        Text("촬영 결과를 그대로 그린 화면은 아니에요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("진단 단계에 맞춘 대표 연습이에요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1 · 시작 상태 만들기")
                        .font(.title2.bold())
                    Label("U 위 · F 앞", systemImage: "viewfinder")
                        .font(.subheadline.weight(.semibold))
                    CubeNetView(facelets: exercise.startState.facelets, presentation: .full)
                    Text("전개도와 같은 상태를 만드세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("공식은 아직 숨겨져 있어요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            CoachCard {
                NotationPrimerView(presentation: .compact)
            }

            if showsSetupSupport {
                CoachCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("시작 상태 만드는 법", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline)
                        Text("도움을 사용한 복습으로 기록돼요.")
                            .font(.subheadline.weight(.semibold))
                        playbackComparison(
                            title: "시작 상태 공식",
                            snapshots: exercise.setupPlayback,
                            moves: exercise.setup.moves,
                            selectedStep: $setupStep,
                            allowsAutoplay: true
                        )
                    }
                }

                Button {
                    completePreparation()
                } label: {
                    Label(
                        "시작 상태를 만들었어요",
                        systemImage: "checkmark.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    guard self.attempt?.recordPreparation(.externallyPrepared) == true else {
                        return
                    }
                    _ = self.attempt?.advance(from: .prepare)
                } label: {
                    Label("이미 맞췄어요", systemImage: "cube.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    guard self.attempt?.recordPreparation(.guidedAcquisition) == true else {
                        return
                    }
                    showsSetupSupport = true
                    setupStep = 0
                } label: {
                    Label("시작 상태 만드는 법 보기", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text("상태가 같으면 ‘이미 맞췄어요’를 누르세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("만드는 법을 보면 도움 사용으로 기록돼요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func recognitionView(case learningCase: StudyCaseUI, exercise: CompiledLearningExercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("이 패턴은 어떤 케이스인가요?")
                        .font(.title2.bold())
                    CubeNetView(facelets: exercise.startState.facelets, presentation: .full)
                }
            }

            ForEach(learningCase.recognitionChoices, id: \.self) { choice in
                Button {
                    selectedRecognition = choice
                    if choice == learningCase.title {
                        _ = attempt?.recordRecognition(.correct)
                    } else {
                        needsRecognitionCorrection = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let candidate = candidateExercise(named: choice) {
                            CubeNetView(
                                facelets: candidate.startState.facelets,
                                presentation: .compact
                            )
                            .frame(width: 92, height: 72)
                            .accessibilityHidden(true)
                        }
                        Text(choice).font(.headline)
                        Spacer()
                        if selectedRecognition == choice {
                            Image(systemName: choice == learningCase.title ? "checkmark.circle.fill" : "xmark.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(needsRecognitionCorrection)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(candidateAccessibilityLabel(choice))
            }

            if needsRecognitionCorrection {
                CoachCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("정답 확인", systemImage: "eye.fill").font(.headline)
                        Text("정답은 ‘\(learningCase.title)’예요.")
                        Text(learningCase.recognition)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("방향 확인하고 돌리기") {
                    _ = attempt?.recordRecognition(.corrected)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func recallView(
        case learningCase: StudyCaseUI,
        exercise: CompiledLearningExercise,
        attempt currentAttempt: TrainerAttemptState
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(learningCase.title).font(.title2.bold())
                    CubeNetView(facelets: exercise.startState.facelets, presentation: .full)
            Label("U 위 · F 앞", systemImage: "viewfinder")
                .font(.subheadline.weight(.semibold))
                }
            }

            hintContent(case: learningCase, exercise: exercise, hint: currentAttempt.maxHint)

            if currentAttempt.maxHint < .h5 {
                Button {
                    revealNextHint(after: currentAttempt.maxHint)
                } label: {
                    Label("도움 한 단계 더 보기", systemImage: "lightbulb")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button {
                beginPhysicalExecution()
            } label: {
                Label("공식 없이 돌려보기", systemImage: "hand.raised.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private func hintContent(case learningCase: StudyCaseUI, exercise: CompiledLearningExercise, hint: LearningHintLevel) -> some View {
        if hint >= .h1 {
            Label(learningCase.recognition, systemImage: "eye.circle")
                .font(.subheadline)
        }
        if hint >= .h2 {
            Label("U 위 · F 앞", systemImage: "rotate.3d")
                .font(.subheadline)
            NotationPrimerView(presentation: .compact)
        }
        if hint == .h3, let first = exercise.solution.moves.first {
            playbackComparison(
                title: "첫 동작",
                snapshots: Array(exercise.solutionPlayback.prefix(2)),
                moves: [first],
                selectedStep: $hintStep,
                allowsAutoplay: false,
                onInteraction: recordRecallPlayback
            )
        }
        if hint == .h4, let firstChunk = exercise.chunks.first {
            playbackComparison(
                title: "첫 동작 묶음",
                snapshots: Array(
                    exercise.solutionPlayback.prefix(firstChunk.moves.count + 1)
                ),
                moves: firstChunk.moves,
                selectedStep: $hintStep,
                allowsAutoplay: true,
                onInteraction: recordRecallPlayback
            )
        }
        if hint >= .h5 {
            playbackComparison(
                title: "전체 공식",
                snapshots: exercise.solutionPlayback,
                moves: exercise.solution.moves,
                selectedStep: $hintStep,
                allowsAutoplay: true,
                onInteraction: recordRecallPlayback
            )
        }
    }

    private func executionView(exercise: CompiledLearningExercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !physicalExecutionFinished {
                CoachCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("실물 큐브를 돌리세요").font(.title2.bold())
                        Label("U 위 · F 앞", systemImage: "viewfinder")
                        Text("공식 없이 돌린 뒤 완료를 누르세요.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button("돌리기 완료") { physicalExecutionFinished = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            } else {
                CoachCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("그림과 같은지 확인하세요").font(.title2.bold())
                        CubeNetView(facelets: finalProjectedFacelets(exercise: exercise), presentation: .full)
                        Text("내 큐브를 목표 그림과 비교하세요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                comparisonButtons
            }
        }
    }

    private var comparisonButtons: some View {
        VStack(spacing: 10) {
            comparisonButton("같아요", icon: "checkmark.circle.fill", outcome: .matched)
            comparisonButton("달라요", icon: "xmark.circle.fill", outcome: .didNotMatch)
            comparisonButton("확신이 없어요", icon: "questionmark.circle", outcome: .unsure)
        }
    }

    private func comparisonButton(_ title: String, icon: String, outcome: ExecutionOutcome) -> some View {
        Button {
            finishAttempt(outcome: outcome)
        } label: {
            Label(title, systemImage: icon).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func resultView(
        current: (index: Int, learningCase: StudyCaseUI, exercise: CompiledLearningExercise),
        attempt: TrainerAttemptState
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label(resultTitle(attempt.execution), systemImage: "rectangle.split.2x1")
                        .font(.title2.bold())
                    let frames = current.exercise.solutionPlayback
                    HStack(alignment: .top, spacing: 12) {
                        VStack {
                            Text("시작").font(.caption.bold())
                            CubeNetView(
                                facelets: frames.first?.executionState.projectedFacelets ?? current.exercise.startState.facelets,
                                presentation: .compact
                            )
                        }
                        VStack {
                            Text("목표 상태").font(.caption.bold())
                            CubeNetView(
                                facelets: frames.last?.executionState.projectedFacelets ?? current.exercise.endState.facelets,
                                presentation: .compact
                            )
                        }
                    }
                    if attempt.wasAssisted {
                        Label(assistanceDescription(attempt), systemImage: "person.fill.questionmark")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }

            playbackComparison(
                title: "기대 회전 타임라인",
                snapshots: current.exercise.solutionPlayback,
                moves: current.exercise.solution.moves,
                selectedStep: $resultStep,
                allowsAutoplay: true
            )

            Button {
                guard session.advance(from: current.index) else { return }
                resetCaseUI()
                configureAttemptIfNeeded()
            } label: {
                Label(
                    current.index + 1 == session.itemCount ? "\(activityName) 마치기" : "다음 케이스",
                    systemImage: "arrow.right.circle.fill"
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var completionView: some View {
        ContentUnavailableView {
            Label("\(activityName) 완료", systemImage: "checkmark.circle.fill")
        } description: {
            if session.reviewedCount == 0 {
                Text(emptySessionDescription)
            } else {
                Text("공식 \(session.reviewedCount)개의 결과를 확인했어요.")
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .learning: "공식 학습"
        case .review: "공식 복습"
        case .practice: "공식 연습"
        case .scanRecommendation: "추천 연습"
        }
    }

    private var activityName: String {
        switch mode {
        case .learning: "학습"
        case .review, .scanRecommendation: "복습"
        case .practice: "연습"
        }
    }

    private var emptySessionDescription: String {
        switch mode {
        case .learning: "지금 학습할 공식이 없어요."
        case .review: "지금 복습할 공식이 없어요."
        case .practice: "지금 연습할 공식이 없어요."
        case .scanRecommendation: "지금 복습할 추천 공식이 없어요."
        }
    }

    private func configureSessionIfNeeded() {
        if loadsDueCasesOnAppear, !hasConfiguredSession {
            let dueCases = store.dueCases.filter { $0.exercise != nil }
            queue = dueCases
            session = TrainerSessionState(itemCount: dueCases.count)
            hasConfiguredSession = true
        }
        configureAttemptIfNeeded()
    }

    private func configureAttemptIfNeeded() {
        guard let current else {
            attempt = nil
            return
        }
        guard attempt?.caseID != current.learningCase.id else { return }
        resetCaseUI()
        var nextAttempt = TrainerAttemptState(
            caseID: current.learningCase.id,
            mode: mode,
            contentVersion: current.learningCase.contentVersion
        )
        if mode == .learning {
            _ = nextAttempt.recordPreparation(.guidedAcquisition)
            showsSetupSupport = true
        }
        attempt = nextAttempt
    }

    private func resetCaseUI() {
        selectedRecognition = nil
        needsRecognitionCorrection = false
        showsSetupSupport = false
        physicalExecutionFinished = false
        setupStep = 0
        hintStep = 0
        resultStep = 0
    }

    private func revealNextHint(after hint: LearningHintLevel) {
        guard let next = LearningHintLevel(rawValue: min(hint.rawValue + 1, LearningHintLevel.h5.rawValue)) else { return }
        hintStep = 0
        _ = attempt?.revealHint(next)
    }

    private func completePreparation() {
        guard attempt?.phase == .prepare,
              attempt?.preparation == .guidedAcquisition,
              attempt?.advance(from: .prepare) == true
        else {
            return
        }

        if mode == .learning {
            _ = attempt?.recordRecognition(.notAssessed)
            _ = attempt?.revealHint(.h5)
        }
    }

    private func recordRecallPlayback() {
        _ = attempt?.recordPlaybackUsed(from: .recall)
    }

    private func beginPhysicalExecution() {
        guard attempt?.phase == .recall else { return }
        _ = attempt?.advance(from: .recall)
        _ = attempt?.advance(from: .playback)
        physicalExecutionFinished = false
    }

    private func finishAttempt(outcome: ExecutionOutcome) {
        guard attempt?.recordExecution(outcome) == true,
              let review = attempt?.complete(evidence: .manualComparison)
        else { return }
        _ = store.recordAttempt(review)
        resultStep = 0
    }

    private func candidateExercise(named title: String) -> CompiledLearningExercise? {
        store.catalog.first { $0.title == title }?.exercise
    }

    private func candidateAccessibilityLabel(_ title: String) -> String {
        guard let exercise = candidateExercise(named: title) else { return title }
        let faceNames = ["윗면", "오른쪽 면", "앞면", "아랫면", "왼쪽 면", "뒷면"]
        let facelets = exercise.startState.facelets
        let summaries = faceNames.enumerated().compactMap { index, name -> String? in
            let lower = index * 9
            let upper = lower + 9
            guard facelets.indices.contains(lower), facelets.indices.contains(upper - 1) else {
                return nil
            }
            let rows = stride(from: lower, to: upper, by: 3).map { start in
                facelets[start..<(start + 3)]
                    .map(\.koreanAccessibilityColorName)
                    .joined(separator: ", ")
            }
            return "\(name). \(rows.enumerated().map { "\($0.offset + 1)행 \($0.element)" }.joined(separator: ". "))"
        }
        return "\(title). \(summaries.joined(separator: ". "))"
    }

    private func finalProjectedFacelets(exercise: CompiledLearningExercise) -> [CubeCoachCore.CubeFace] {
        exercise.solutionPlayback.last?.executionState.projectedFacelets ?? exercise.endState.facelets
    }

    @ViewBuilder
    private func playbackComparison(
        title: String,
        snapshots: [CubePlaybackSnapshot],
        moves: [CubeMove],
        selectedStep: Binding<Int>,
        allowsAutoplay: Bool,
        onInteraction: @escaping () -> Void = {}
    ) -> some View {
        if !moves.isEmpty, snapshots.count == moves.count + 1 {
            let moveIndex = min(max(selectedStep.wrappedValue, 0), moves.count - 1)
            let before = snapshots[moveIndex].executionState.projectedFacelets
            let after = snapshots[moveIndex + 1].executionState.projectedFacelets
            let move = moves[moveIndex]

            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label(title, systemImage: "rectangle.split.2x1").font(.headline)

                    ScrollView(.horizontal) {
                        Text(
                            moves
                                .map(\.notation)
                                .joined(separator: " ")
                        )
                        .font(.title3.monospaced().bold())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityLabel(
                        "공식 \(moves.map(\.notation).joined(separator: " "))"
                    )

                    Text("전  →  \(move.notation)  →  후")
                        .font(.subheadline.monospaced().bold())
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "돌리기 전 상태에서 \(moveInstruction(move)) 동작을 하면 돌린 후 상태가 됩니다."
                        )
                    HStack(alignment: .top, spacing: 12) {
                        VStack {
                            Text("전").font(.caption.bold())
                            CubeNetView(
                                facelets: before,
                                presentation: .compact
                            )
                        }
                        VStack {
                            Text("후").font(.caption.bold())
                            CubeNetView(
                                facelets: after,
                                presentation: .compact
                            )
                        }
                    }
                    MoveTimelineView(
                        moves: moves,
                        selectedStep: selectedStep,
                        allowsAutoplay: allowsAutoplay,
                        onInteraction: onInteraction
                    )
                }
            }
        } else {
            CoachCard {
                Label(
                    "동작 그림을 불러오지 못했어요.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .accessibilityLabel("동작 그림을 불러오지 못했습니다.")
            }
        }
    }

    private func moveInstruction(_ move: CubeMove) -> String {
        let target: String
        switch move.symbol {
        case .R: target = "오른쪽 면을 정면에서 보고"
        case .L: target = "왼쪽 면을 정면에서 보고"
        case .U: target = "윗면을 정면에서 보고"
        case .D: target = "아랫면을 정면에서 보고"
        case .F: target = "앞면을 정면에서 보고"
        case .B: target = "뒷면을 정면에서 보고"
        case .x: target = "큐브 전체를 x축으로"
        case .y: target = "큐브 전체를 y축으로"
        case .z: target = "큐브 전체를 z축으로"
        }

        let direction: String
        switch move.amount {
        case .clockwise: direction = "시계 방향 90°"
        case .half: direction = "180°"
        case .counterclockwise: direction = "반시계 방향 90°"
        }

        return "\(move.notation) · \(target) \(direction)"
    }

    private func resultTitle(_ outcome: ExecutionOutcome?) -> String {
        switch outcome {
        case .matched: "기대 상태와 같다고 기록했어요"
        case .didNotMatch: "기대 상태와 다르다고 기록했어요"
        case .unsure: "확인하지 못한 시도로 기록했어요"
        case nil: "결과 비교"
        }
    }

    private func assistanceDescription(_ attempt: TrainerAttemptState) -> String {
        var reasons: [String] = []
        if attempt.preparation == .guidedAcquisition {
            reasons.append("시작 상태 만드는 법 사용")
        }
        if attempt.recognition == .corrected {
            reasons.append("인식 선택 바로잡음")
        }
        if attempt.maxHint > .h0 {
            reasons.append("단계별 도움 사용")
        }
        if attempt.playbackUsed, attempt.preparation != .guidedAcquisition {
            reasons.append("단계 조작·재생 사용")
        }
        reasons.append("도움 없이 완료한 복습으로 계산되지 않아요")
        return reasons.joined(separator: " · ")
    }
}

private extension CubeCoachCore.CubeFace {
    var koreanAccessibilityColorName: String {
        switch self {
        case .up: "흰색"
        case .right: "빨간색"
        case .front: "초록색"
        case .down: "노란색"
        case .left: "주황색"
        case .back: "파란색"
        }
    }
}
