//
//  ControlIconStyle.swift
//  CurrencySpot
//

import SwiftUI

/// Styles an SF Symbol as a uniform control-button icon: a fixed headline-relative
/// frame gives the glyph a deterministic, Dynamic-Type-scaled size, and the padding
/// sets the inset. Sizing a symbol by font alone leaves each glyph at its own
/// intrinsic size; pinning the frame is what makes a row of controls match. Color
/// stays the caller's concern.
private struct ControlIconStyle: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let padding: CGFloat

    /// nonisolated so it can be built inside PhotosPicker's @Sendable label
    /// closure, matching AdaptiveGlassBackground.
    nonisolated init(size: CGFloat, padding: CGFloat) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: .headline)
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .padding(padding)
    }
}

extension Image {
    /// Renders the symbol as a uniform control-button icon; apply
    /// `.foregroundStyle` yourself. `size` and `padding` default to the standard
    /// control tokens; pass smaller values (e.g. a compact close button) and the
    /// glyph still scales with Dynamic Type. nonisolated, matching SwiftUI's own
    /// modifiers, so it works in nonisolated @Sendable view-builder closures
    /// (e.g. PhotosPicker).
    nonisolated func controlIconStyle(
        size: CGFloat = .controlIconSize,
        padding: CGFloat = .controlIconPadding
    ) -> some View {
        resizable()
            .scaledToFit()
            .modifier(ControlIconStyle(size: size, padding: padding))
    }
}
