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

    var body: some View {
        TimerFeatureView(model: model)
            .onChange(of: model.records) { _, records in
                store.replaceRecords(Self.solveRecords(from: records))
            }
            .onChange(of: store.records, initial: true) { _, records in
                model.replaceRecords(Self.timerRecords(from: records))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ScanPracticeContainer()
                    } label: {
                        Label("내 큐브 확인", systemImage: "viewfinder")
                    }
                    .accessibilityHint("카메라로 여러 면을 촬영해 내 큐브 상태를 확인합니다")
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

/// A successful scan starts executable recall or a cube-native concept task,
/// never a generated full solution.
private struct ScanPracticeContainer: View {
    @EnvironmentObject private var store: LearningProgressStore
    @State private var showsTrainer = false
    @State private var showsConceptPractice = false
    @State private var recommendedCases: [StudyCaseUI] = []
    @State private var conceptDiagnosis: CubePracticeDiagnosis?

    var body: some View {
        CubeScanFeatureView { diagnosis in
            let cases = practiceCases(for: diagnosis)
            if cases.isEmpty {
                conceptDiagnosis = diagnosis
                showsConceptPractice = true
            } else {
                recommendedCases = cases
                showsTrainer = true
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
}
