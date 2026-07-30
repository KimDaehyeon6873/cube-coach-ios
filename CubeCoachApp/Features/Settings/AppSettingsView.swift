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
                Text("시스템 모드는 iPhone 설정을 따라요.")
            }

            Section("개인정보 처리") {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("카메라 이미지")
                            .font(.headline)
                        Text("사진은 기기에서만 처리하며 저장·전송하지 않아요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                        Text("학습·타이머 기록은 이 기기에만 저장해요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("계정·광고·분석·동기화 없음")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.coachAccent)
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
                        Label("개인정보 처리방침", systemImage: "safari")
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
                VStack(alignment: .leading, spacing: 3) {
                    Text("학습·솔브 기록과 목표를 삭제해요.")
                    Text("화면 모드와 복구 사본도 초기화해요.")
                    Text("삭제 후에는 되돌릴 수 없어요.")
                }
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
            Text("이 기기의 기록과 설정이 영구 삭제돼요.")
        }
        .alert("삭제 완료", isPresented: $showsDeletionResult) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("이 기기의 기록과 설정을 삭제했어요.")
        }
    }
}
