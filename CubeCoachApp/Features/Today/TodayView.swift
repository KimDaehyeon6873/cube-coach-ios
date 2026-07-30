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
                    Text("오늘 할 일")
                        .font(.largeTitle.bold())
                    Text("복습하고 타이머 기록을 이어가세요.")
                        .foregroundStyle(.secondary)
                }

                CoachCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("오늘의 복습", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline)
                        Text("\(store.dueCases.count)개")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(
                            store.dueCases.isEmpty
                                ? "오늘 복습은 끝났어요. 타이머로 이어가세요."
                                : "시작 상태만 보고 실물 큐브로 돌려 보세요."
                        )
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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

                SectionHeading(title: "복습 진도", detail: "기록 기준")
                CoachCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("복습 기록이 있는 공식", systemImage: "checkmark.seal")
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
                        "복습 기록이 있는 공식, 전체 \(store.catalog.count)개 중 \(store.learnedCount)개"
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
                                Text("타이머 연습").font(.headline)
                                Text("스크램블 확인 후 바로 시작해요.")
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
        .background(Color.coachPage)
        .navigationTitle("오늘")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AppSettingsView()
                } label: {
                    Label("설정", systemImage: "gearshape")
                }
                .accessibilityHint("화면 모드, 개인정보 처리 안내와 로컬 데이터 관리 화면을 엽니다")
            }
        }
    }
}
