import Foundation

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .system: .settingsAppearanceModeSystem
        case .light: .settingsAppearanceModeLight
        case .dark: .settingsAppearanceModeDark
        }
    }
}
