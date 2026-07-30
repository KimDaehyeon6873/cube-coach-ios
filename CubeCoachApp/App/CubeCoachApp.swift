import CubeCoachCore
import SwiftUI

@main
struct CubeCoachApp: App {
    @StateObject private var learningStore = LearningProgressStore()

    var body: some Scene {
        WindowGroup {
            CubeCoachRootView()
                .environmentObject(learningStore)
                .tint(.coachAccent)
        }
    }
}
