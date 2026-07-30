import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: LearningProgressStore
    @Binding private var selectedTab: CubeCoachTab

    init(selectedTab: Binding<CubeCoachTab>) {
        _selectedTab = selectedTab
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘 이어서 할 일")
                        .font(.largeTitle.bold())
                    Text("학습한 공식을 복습하고, 자유 솔빙 기록도 쌓아 보세요.")
                        .foregroundStyle(.secondary)
                }

                CoachCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("오늘의 복습", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline)
                        Text("\(store.dueCases.count)개")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(store.dueCases.isEmpty ? "오늘 복습을 마쳤어요" : "학습에서 본 단서를 가리고, 실제 큐브로 떠올려 보세요.")
                            .foregroundStyle(.secondary)
                        if !store.dueCases.isEmpty {
                            NavigationLink {
                                TrainerView(initialCases: store.dueCases)
                            } label: {
                                Label("복습 시작", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                }

                SectionHeading(title: "복습 현황", detail: "결과까지 확인한 공식")
                CoachCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("확인한 공식", systemImage: "checkmark.seal")
                            Spacer()
                            Text("\(store.learnedCount) / \(store.catalog.count)")
                                .monospacedDigit()
                        }
                        .font(.subheadline.weight(.semibold))
                        ProgressView(
                            value: Double(store.learnedCount),
                            total: Double(max(store.catalog.count, 1))
                        )
                        .tint(.coachAccent)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "복습으로 확인한 공식, 전체 \(store.catalog.count)개 중 \(store.learnedCount)개"
                    )
                }

                Button {
                    selectedTab = .practice
                } label: {
                    CoachCard {
                        HStack(spacing: 14) {
                            Image(systemName: "timer")
                                .font(.title)
                                .foregroundStyle(Color.coachAccent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("연습 시작").font(.headline)
                                Text("TNoodle로 생성한 연습 스크램블로 섞고 기록을 시작하세요.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("스크램블과 타이머가 있는 연습 화면을 엽니다")
            }
            .padding()
        }
        .navigationTitle("오늘")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    Label("개인정보 및 데이터", systemImage: "gearshape")
                }
                .accessibilityHint("개인정보 처리 안내와 로컬 데이터 관리 화면을 엽니다")
            }
        }
    }
}
