import SwiftUI

struct LearnRoadmapView: View {
    @EnvironmentObject private var store: LearningProgressStore

    var body: some View {
        List {
            Section {
                Label("시작 패턴을 먼저 구분해요.", systemImage: "eye")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("공식을 짧게 나눠 실물 큐브로 익혀요.", systemImage: "square.split.2x1")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("공식을 가리고 직접 떠올려요.", systemImage: "eye.slash")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("시간을 두고 다른 패턴과 섞어 복습해요.", systemImage: "shuffle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("직접 돌리고 결과를 확인해야 복습 기록에 남아요.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.coachAccent)
                    .fixedSize(horizontal: false, vertical: true)
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
    @State private var query = ""

    private var cases: [StudyCaseUI] { store.catalog.filter { stage.caseIDs.contains($0.id) } }
    private var filteredCases: [StudyCaseUI] {
        guard !query.isEmpty else { return cases }
        return cases.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.family.localizedCaseInsensitiveContains(query)
                || $0.algorithm.localizedCaseInsensitiveContains(query)
        }
    }
    private var families: [String] {
        var seen = Set<String>()
        return filteredCases.compactMap { item in
            seen.insert(item.family).inserted ? item.family : nil
        }
    }

    var body: some View {
        List {
            Section {
                Text("공식 \(cases.count)개 · 이름이나 기호로 검색할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(families, id: \.self) { family in
                let familyCases = filteredCases.filter { $0.family == family }
                Section("\(family) · \(familyCases.count)개") {
                    ForEach(familyCases) { learningCase in
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
                                ScrollView(.horizontal) {
                                    Text(learningCase.algorithm)
                                        .font(.caption.monospaced().weight(.semibold))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .scrollIndicators(.hidden)
                                Text("시작 상태와 동작 전후를 확인해요.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle(stage.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "공식 이름 또는 기호")
    }
}
