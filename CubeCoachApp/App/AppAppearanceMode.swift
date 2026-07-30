import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    static let storageKey = "appAppearanceMode"

    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "시스템"
        case .light: "라이트"
        case .dark: "다크"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
