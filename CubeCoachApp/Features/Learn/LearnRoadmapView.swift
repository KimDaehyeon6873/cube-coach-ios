import SwiftUI

struct LearnRoadmapView: View {
    @EnvironmentObject private var store: LearningProgressStore

    var body: some View {
        List {
            Section {
                Label("그림을 보고 실물 큐브로 따라 돌려요.", systemImage: "cube")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("익숙해지면 공식 없이 복습해요.", systemImage: "eye.slash")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("보기만 하면 복습 기록에 남지 않아요.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.coachAccent)
            }

            Section {
                DisclosureGroup {
                    NotationPrimerView(presentation: .detailed, showsTitle: false)
                        .padding(.vertical, 8)
                } label: {
                    Label("기호 읽는 법", systemImage: "textformat")
                        .font(.headline)
                }
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
                            Label("공식 \(stage.caseIDs.count)개 · 복습 \(completed)개", systemImage: completed == stage.caseIDs.count ? "checkmark.circle.fill" : "circle.dashed")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(completed == stage.caseIDs.count ? Color.coachSuccess : Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
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
                    Text("시작 상태와 동작 전후를 확인해요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(stage.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
