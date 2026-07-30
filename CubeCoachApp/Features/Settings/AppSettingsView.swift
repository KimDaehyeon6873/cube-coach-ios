import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject private var store: LearningProgressStore
    @AppStorage(AppAppearanceMode.storageKey)
    private var appearanceMode: AppAppearanceMode = .system
    @State private var showsDeletionConfirmation = false
    @State private var showsDeletionResult = false

    private let privacyPolicyURL = URL(
        string: "https://kimdaehyeon6873.github.io/cube-coach-ios/privacy.html"
    )

    var body: some View {
        Form {
            Section {
                Picker("화면 모드", selection: $appearanceMode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("화면 모드")
                .accessibilityHint("앱의 밝은 화면과 어두운 화면 사용 방식을 선택합니다")
            } header: {
                Text("화면 모드")
            } footer: {
                Text("시스템을 선택하면 iPhone의 화면 모드 설정을 따라요.")
            }

            Section("개인정보 처리") {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("카메라 이미지")
                            .font(.headline)
                        Text("촬영 이미지는 기기 안에서만 처리하고 저장하거나 전송하지 않아요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(Color.coachAccent)
                        .accessibilityHidden(true)
                }

                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("학습 및 솔브 기록")
                            .font(.headline)
                        Text("학습 진행과 타이머 기록은 이 기기에만 저장해요. 계정, 광고, 분석 SDK, 클라우드 동기화는 사용하지 않아요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "iphone")
                        .foregroundStyle(Color.coachAccent)
                        .accessibilityHidden(true)
                }
            }

            Section("정책") {
                if let privacyPolicyURL {
                    Link(destination: privacyPolicyURL) {
                        Label("개인정보 처리방침 열기", systemImage: "safari")
                    }
                    .accessibilityHint("웹 브라우저에서 공개 개인정보 처리방침을 엽니다")
                }
            }

            Section {
                Button("모든 로컬 데이터 삭제", role: .destructive) {
                    showsDeletionConfirmation = true
                }
                .accessibilityHint("학습 진행과 솔브 기록을 이 기기에서 영구 삭제합니다")
            } footer: {
                Text("학습 진행, 솔브 기록, 복습 횟수, 일일 목표, 화면 모드 설정과 손상 데이터 복구용 사본을 모두 삭제합니다. 이 작업은 되돌릴 수 없습니다.")
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .alert("모든 로컬 데이터를 삭제할까요?", isPresented: $showsDeletionConfirmation) {
            Button("취소", role: .cancel) {}
            Button("모두 삭제", role: .destructive) {
                store.deleteAllLocalData()
                appearanceMode = .system
                showsDeletionResult = true
            }
        } message: {
            Text("학습 진행, 기록, 목표, 화면 모드 설정과 복구용 사본이 이 기기에서 영구 삭제됩니다.")
        }
        .alert("삭제 완료", isPresented: $showsDeletionResult) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("모든 로컬 학습 및 솔브 데이터가 삭제되었습니다.")
        }
    }
}
