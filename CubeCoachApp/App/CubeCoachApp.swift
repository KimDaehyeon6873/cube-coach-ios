import CubeCoachCore
import SwiftUI

@main
struct CubeCoachApp: App {
    @StateObject private var learningStore = LearningProgressStore()
    @AppStorage(AppAppearanceMode.storageKey)
    private var appearanceMode: AppAppearanceMode = .system

    var body: some Scene {
        WindowGroup {
            CubeCoachRootView()
                .environmentObject(learningStore)
                .tint(.coachAccent)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}
