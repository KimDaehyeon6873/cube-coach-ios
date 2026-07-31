import CubeCoachCore
import SwiftUI

enum CubeCoachTab: Hashable {
    case today
    case learn
    case practice
    case records
}

struct CubeCoachRootView: View {
    @EnvironmentObject private var store: LearningProgressStore
    @State private var selectedTab: CubeCoachTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { TodayView(selectedTab: $selectedTab) }
                .tabItem { Label("오늘", systemImage: "sun.max.fill") }
                .tag(CubeCoachTab.today)
            NavigationStack { LearnRoadmapView() }
                .tabItem { Label("학습", systemImage: "map.fill") }
                .tag(CubeCoachTab.learn)
            NavigationStack {
                TimerPracticeContainer()
            }
                .tabItem { Label("연습", systemImage: "timer") }
                .tag(CubeCoachTab.practice)
            NavigationStack { RecordsView() }
                .tabItem { Label("기록", systemImage: "chart.xyaxis.line") }
                .tag(CubeCoachTab.records)
        }
        .tint(.coachAccent)
        .alert(
            "학습 기록 복구 알림",
            isPresented: Binding(
                get: { store.persistenceWarning != nil },
                set: { if !$0 { store.dismissPersistenceWarning() } }
            )
        ) {
            Button("확인") {
                store.dismissPersistenceWarning()
            }
        } message: {
            Text(store.persistenceWarning ?? "")
        }
    }
}

/// Timer 기능의 세션 기록을 앱의 장기 기록 저장소로 전달하는 조립 어댑터입니다.
struct TimerPracticeContainer: View {
    @EnvironmentObject private var store: LearningProgressStore
    @StateObject private var model = TimerFeatureModel()
    @State private var showsScanPractice = false

    var body: some View {
        TimerFeatureView(model: model)
            .onChange(of: model.records) { _, records in
                store.replaceRecords(Self.solveRecords(from: records))
            }
            .onChange(of: store.records, initial: true) { _, records in
                model.replaceRecords(Self.timerRecords(from: records))
            }
            .navigationDestination(isPresented: $showsScanPractice) {
                ScanPracticeContainer {
                    showsScanPractice = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsScanPractice = true
                    } label: {
                        Label("내 큐브 확인", systemImage: "camera.viewfinder")
                    }
                    .accessibilityHint("카메라로 촬영하거나 전개도에 직접 입력해 내 큐브 상태를 확인합니다")
                }
            }
    }

    private static func timerPenalty(_ penalty: SolvePenalty) -> TimerSolvePenalty {
        switch penalty {
        case .none: .none
        case .plusTwo: .plusTwo
        case .dnf: .dnf
        }
    }

    private static func corePenalty(_ penalty: TimerSolvePenalty) -> SolvePenalty {
        switch penalty {
        case .none: .none
        case .plusTwo: .plusTwo
        case .dnf: .dnf
        }
    }

    private static func timerRecords(from records: [SolveRecord]) -> [TimerSolveRecord] {
        records.reversed().map {
            TimerSolveRecord(
                id: $0.id,
                date: $0.timestamp,
                rawSeconds: $0.rawDuration,
                penalty: timerPenalty($0.penalty),
                scramble: $0.scramble ?? ""
            )
        }
    }

    private static func solveRecords(from records: [TimerSolveRecord]) -> [SolveRecord] {
        records.map {
            SolveRecord(
                id: $0.id,
                timestamp: $0.date,
                rawDuration: $0.rawSeconds,
                penalty: corePenalty($0.penalty),
                scramble: $0.scramble
            )
        }
    }
}

/// A successful scan starts a goal-based attempt from the reviewed physical
/// state, never a generated scramble or full solution.
private struct ScanPracticeContainer: View {
    @State private var practiceModel: CubeStatePracticeSessionModel?
    @State private var showsStatePractice = false
    @State private var startError: String?

    let onFinish: () -> Void

    var body: some View {
        CubeScanFeatureView { scan in
            if scan.diagnosis.isSolved {
                onFinish()
                return
            }
            do {
                practiceModel = try CubeStatePracticeSessionModel(
                    initialScan: scan
                )
                showsStatePractice = true
            } catch {
                startError = "촬영한 상태로 연습을 준비하지 못했어요."
            }
        }
        .navigationDestination(isPresented: $showsStatePractice) {
            if let practiceModel {
                CubeStatePracticeView(model: practiceModel) {
                    onFinish()
                }
            }
        }
        .alert(
            "상태 연습을 시작하지 못했어요",
            isPresented: Binding(
                get: { startError != nil },
                set: { if !$0 { startError = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(startError ?? "전개도를 다시 확인해 주세요.")
        }
    }
}
