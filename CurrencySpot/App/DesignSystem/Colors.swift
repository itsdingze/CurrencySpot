//
//  Colors.swift
//  CurrencySpot
//

import SwiftUI

/// Color tokens. Asset-catalog colors (background, secondaryBackground,
/// tertiaryBackground, secondaryAccent, accentColor) come from generated
/// symbols; everything else lives here.
nonisolated extension Color {
    // MARK: Text

    /// Primary text color that adapts to light/dark mode.
    static let textPrimary = Color(.label)
    /// Secondary text color that adapts to light/dark mode.
    static let textSecondary = Color(.secondaryLabel)

    // MARK: Semantic outcomes

    /// Rising trends, chart highs, success toasts.
    static let success = Color.green
    /// Falling trends, chart lows, destructive/error states.
    static let failure = Color.red
    /// Stable-but-noteworthy states: offline banner, moderate-high volatility.
    static let warning = Color.orange

    // MARK: Surfaces and fills

    /// Tinted fill behind the selected segment, chip, or chart annotation.
    static let selectionFill = Color.accentColor.opacity(0.2)
    /// Neutral surface behind loading/empty chart placeholders.
    static let chartPlaceholder = Color(.systemGray6)
    /// Background dot that knocks chart point markers out of the line.
    static let markerKnockout = Color(.systemBackground)
    /// Secondary circle behind `xmark.circle.fill` close buttons.
    static let closeButtonBackdrop = Color.primary.opacity(0.1)
}
