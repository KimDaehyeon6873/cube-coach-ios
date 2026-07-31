import CubeCoachCore
import SwiftUI

@main
struct CubeCoachApp: App {
    @StateObject private var learningStore = LearningProgressStore()
    @AppStorage(AppAppearanceMode.storageKey)
    private var appearanceMode: AppAppearanceMode = .system

    var body: some Scene {
        WindowGroup {
            appContent
                .environmentObject(learningStore)
                .tint(.coachAccent)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }

    @ViewBuilder
    private var appContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-state-practice-preview") {
            NavigationStack {
                CubeStatePracticePreviewHost(
                    mode: ProcessInfo.processInfo.arguments.contains(
                        "-state-practice-result-preview"
                    )
                        ? .result
                        : ProcessInfo.processInfo.arguments.contains(
                            "-state-practice-paused-preview"
                        )
                            ? .paused
                            : .briefing
                )
            }
        } else if ProcessInfo.processInfo.arguments.contains("-scan-preview") {
            NavigationStack {
                CubeScanFeatureView(
                    purpose: ProcessInfo.processInfo.arguments.contains(
                        "-scan-result-preview"
                    )
                        ? .practiceResult
                        : .initialPractice
                )
            }
        } else {
            CubeCoachRootView()
        }
        #else
        CubeCoachRootView()
        #endif
    }
}
