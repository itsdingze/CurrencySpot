import SwiftUI

enum AccentColorOption: String, CaseIterable, Identifiable {
    case pink = "Pink"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case mint = "Mint"
    case cyan = "Cyan"
    case blue = "Blue"
    case indigo = "Indigo"

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .pink: .settingsAccentColorPink
        case .orange: .settingsAccentColorOrange
        case .yellow: .settingsAccentColorYellow
        case .green: .settingsAccentColorGreen
        case .mint: .settingsAccentColorMint
        case .cyan: .settingsAccentColorCyan
        case .blue: .settingsAccentColorBlue
        case .indigo: .settingsAccentColorIndigo
        }
    }

    var color: Color {
        switch self {
        case .pink: .pink.mix(with: .purple, by: 0.22)
        case .orange: .orange
        case .yellow: .yellow.mix(with: .orange, by: 0.2)
        case .green: .green
        case .mint: .mint
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        }
    }
}
