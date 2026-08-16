import SwiftUI

nonisolated extension Color {
    // MARK: - Text

    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)

    // MARK: - Semantic outcomes

    static let success = Color.green
    static let failure = Color.red
    static let warning = Color.orange

    // MARK: - Surfaces and fills

    static let selectionFill = Color.accentColor.opacity(0.2)
    static let chartPlaceholder = Color(.systemGray6)
    static let markerKnockout = Color(.systemBackground)
}
