//
//  AccentColorOption.swift
//  CurrencySpot
//

import SwiftUI

/// Color theme options for the app.
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
