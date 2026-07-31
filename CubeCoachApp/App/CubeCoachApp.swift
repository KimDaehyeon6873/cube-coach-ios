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
        if ProcessInfo.processInfo.arguments.contains("-scan-preview") {
            NavigationStack {
                CubeScanFeatureView()
            }
        } else {
            CubeCoachRootView()
        }
        #else
        CubeCoachRootView()
        #endif
    }
}
