//
//  ControlIconStyle.swift
//  CurrencySpot
//

import SwiftUI

/// Styles an SF Symbol as a uniform control-button icon: the app's headline font
/// sets a consistent weight and rounded design, a fixed headline-relative frame
/// makes every glyph the same size, and the padding sets the inset. `.font(...)`
/// alone leaves each glyph at its own intrinsic size; pinning the frame is what
/// makes a row of controls match. Color stays the caller's concern.
private struct ControlIconStyle: ViewModifier {
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = .controlIconSize
    private let padding: CGFloat

    /// nonisolated so it can be built inside PhotosPicker's @Sendable label
    /// closure, matching AdaptiveGlassBackground.
    nonisolated init(padding: CGFloat) {
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .font(.appHeadline)
            .frame(width: size, height: size)
            .padding(padding)
    }
}

extension Image {
    /// Renders the symbol as a uniform control-button icon; apply
    /// `.foregroundStyle` yourself. nonisolated, matching SwiftUI's own
    /// modifiers, so it works in nonisolated @Sendable view-builder closures
    /// (e.g. PhotosPicker).
    nonisolated func controlIconStyle(padding: CGFloat = .controlIconPadding) -> some View {
        resizable()
            .scaledToFit()
            .modifier(ControlIconStyle(padding: padding))
    }
}
