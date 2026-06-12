//
//  AdaptiveGlassBackground.swift
//  CurrencySpot
//

import SwiftUI

/// Liquid Glass background on iOS 26+, regular material on earlier systems.
struct AdaptiveGlassBackground<S: Shape>: ViewModifier {
    let shape: S
    let isInteractive: Bool

    /// nonisolated so the modifier can be applied inside nonisolated @Sendable
    /// label closures (e.g. PhotosPicker's); Shape is Sendable, so this is safe.
    nonisolated init(shape: S, isInteractive: Bool) {
        self.shape = shape
        self.isInteractive = isInteractive
    }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(isInteractive ? .regular.interactive() : .regular, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

extension View {
    /// Mark interactive for tappable controls so the glass reacts to touch.
    /// nonisolated, matching SwiftUI's own modifiers, so it works in nonisolated
    /// @Sendable view-builder closures.
    nonisolated func adaptiveGlassBackground(in shape: some Shape, isInteractive: Bool = false) -> some View {
        modifier(AdaptiveGlassBackground(shape: shape, isInteractive: isInteractive))
    }
}
