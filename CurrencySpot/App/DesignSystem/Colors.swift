import SwiftUI

nonisolated extension ShapeStyle where Self == Color {
    // MARK: - Semantic outcomes

    static var success: Color { .green }
    static var failure: Color { .red }
    static var warning: Color { .orange }

    // MARK: - Surfaces and fills

    static var chartPlaceholder: Color { Color(.systemGray6) }
    static var markerKnockout: Color { Color(.systemBackground) }

    static func selectionFill(on accent: Color) -> Color {
        accent.opacity(0.2)
    }
}
