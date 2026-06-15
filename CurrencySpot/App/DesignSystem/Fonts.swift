//
//  Fonts.swift
//  CurrencySpot
//

import SwiftUI

/// The app's type ramp: system text styles in the rounded design with each
/// style's weight folded in. Call sites say `.font(.appHeadline)`; per-site
/// emphasis composes on top (`.weight(.medium)`, `.bold()`, `.monospacedDigit()`).
nonisolated extension Font {
    static let appLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let appTitle = Font.system(.title, design: .rounded, weight: .bold)
    static let appTitle2 = Font.system(.title2, design: .rounded, weight: .semibold)
    static let appTitle3 = Font.system(.title3, design: .rounded, weight: .semibold)
    static let appHeadline = Font.system(.headline, design: .rounded)
    static let appSubheadline = Font.system(.subheadline, design: .rounded)
    static let appFootnote = Font.system(.footnote, design: .rounded)
    static let appCaption = Font.system(.caption, design: .rounded)

    /// Monospaced footnote for verbatim blocks where alignment matters — license
    /// texts, code. The one place the rounded ramp gives way to a fixed pitch.
    static let appMonospaced = Font.system(.footnote, design: .monospaced)

    /// Oversized symbol leading the camera permission screens.
    static let heroIcon = Font.system(size: 56, weight: .medium)
}
