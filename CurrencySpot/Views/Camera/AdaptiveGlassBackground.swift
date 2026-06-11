//
//  AdaptiveGlassBackground.swift
//  CurrencySpot
//

import SwiftUI

/// Liquid Glass background on iOS 26+, regular material on earlier systems.
struct AdaptiveGlassBackground<S: Shape>: ViewModifier {
    let shape: S
    let isInteractive: Bool

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
    func adaptiveGlassBackground(in shape: some Shape, isInteractive: Bool = false) -> some View {
        modifier(AdaptiveGlassBackground(shape: shape, isInteractive: isInteractive))
    }
}
