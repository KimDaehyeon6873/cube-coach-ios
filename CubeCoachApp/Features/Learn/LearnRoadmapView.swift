import SwiftUI

struct LearnRoadmapView: View {
    @EnvironmentObject private var store: LearningProgressStore

    var body: some View {
        List {
            Section {
                Text("그림과 동작을 보며 따라 하세요. 익숙해지면 복습에서 공식을 가리고 직접 돌려 보세요.")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("학습 안내. 그림과 동작을 보며 따라 한 뒤, 복습에서 공식을 가리고 직접 돌려 보세요.")
                Text("학습 화면만 본 것은 복습 기록으로 계산하지 않아요.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.coachAccent)
            }

            ForEach(Array(RoadmapStageUI.all.enumerated()), id: \.element.id) { index, stage in
                NavigationLink {
                    StageDetailView(stage: stage)
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(Color.coachAccent.opacity(0.14))
                            Text("\(index + 1)").font(.headline).foregroundStyle(Color.coachAccent)
                        }
                        .frame(width: 42, height: 42)
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(stage.title).font(.headline)
                            Text(stage.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            let completed = stage.caseIDs.filter { store.progressValue(for: $0).repetitions > 0 }.count
                            Label("연습 케이스 \(stage.caseIDs.count)개 · 복습 기록 \(completed)개", systemImage: completed == stage.caseIDs.count ? "checkmark.circle.fill" : "circle.dashed")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(completed == stage.caseIDs.count ? Color.coachSuccess : Color.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

        }
        .navigationTitle("학습")
    }
}

private struct StageDetailView: View {
    @EnvironmentObject private var store: LearningProgressStore
    let stage: RoadmapStageUI

    private var cases: [StudyCaseUI] { store.catalog.filter { stage.caseIDs.contains($0.id) } }

    var body: some View {
        List(cases) { learningCase in
            NavigationLink {
                LearningCaseDetailView(learningCase: learningCase)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(learningCase.title).font(.headline)
                        Spacer()
                        if store.progressValue(for: learningCase.id).repetitions > 0 {
                            Label("복습 기록 있음", systemImage: "checkmark.circle.fill")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(Color.coachSuccess)
                                .accessibilityLabel("복습 기록 있음")
                        }
                    }
                    Text(learningCase.family).font(.subheadline).foregroundStyle(.secondary)
                    Text("시작 상태, 핵심 단서, 동작 전후를 차례로 확인해요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(stage.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
