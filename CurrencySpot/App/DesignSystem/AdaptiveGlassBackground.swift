//
//  AdaptiveGlassBackground.swift
//  CurrencySpot
//

import SwiftUI

/// Which base Liquid Glass to use. Mapped to `Glass` only inside iOS 26 code, so
/// the iOS 26-only `Glass` type never leaks into this API's signature — which
/// has to compile against older deployment targets too.
enum AdaptiveGlassStyle {
    case regular
    case clear
}

/// Liquid Glass background on iOS 26+, a customizable fallback on earlier systems.
///
/// `glass` picks the base variant (`.regular` by default, `.clear` for a more
/// transparent effect). `Fallback` is the view drawn behind `content` before
/// iOS 26, and it is drawn exactly as given — NOT clipped to `shape` — so a
/// custom fallback owns its own shape (pass a `RoundedRectangle`, gradient,
/// image, …). The no-argument overload supplies `shape.fill(.regularMaterial)`,
/// so the default fallback still matches the glass shape. Keeping it a generic
/// `@ViewBuilder` means a complex background keeps its real type instead of
/// being squashed into `AnyView`.
///
/// The type is `nonisolated` so it can be constructed inside nonisolated
/// @Sendable label closures (e.g. PhotosPicker's). A stored non-Sendable
/// `Fallback` view forces this onto the whole type rather than just `init`.
nonisolated struct AdaptiveGlassBackground<S: Shape, Fallback: View>: ViewModifier {
    let shape: S
    let glass: AdaptiveGlassStyle
    let isInteractive: Bool
    let tint: Color?
    let fallback: Fallback

    init(
        shape: S,
        glass: AdaptiveGlassStyle,
        isInteractive: Bool,
        tint: Color?,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.shape = shape
        self.glass = glass
        self.isInteractive = isInteractive
        self.tint = tint
        self.fallback = fallback()
    }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .compositingGroup()
                .glassEffect(resolvedGlass, in: shape)
        } else {
            content.background { fallback }
        }
    }

    @available(iOS 26, *)
    private var resolvedGlass: Glass {
        var base: Glass = switch glass {
        case .regular: .regular
        case .clear: .clear
        }
        if let tint { base = base.tint(tint) }
        if isInteractive { base = base.interactive() }
        return base
    }
}

extension View {
    /// Liquid Glass on iOS 26+, falling back to `.regularMaterial` on earlier systems.
    ///
    /// Pass `glass: .clear` for a more transparent variant. Mark `isInteractive`
    /// for tappable controls so the glass reacts to touch. nonisolated, matching
    /// SwiftUI's own modifiers, so it works in nonisolated @Sendable view-builder
    /// closures.
    nonisolated func adaptiveGlassBackground(
        in shape: some Shape,
        glass: AdaptiveGlassStyle = .regular,
        isInteractive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        adaptiveGlassBackground(in: shape, glass: glass, isInteractive: isInteractive, tint: tint) {
            shape.fill(.regularMaterial)
        }
    }

    /// Solid-tint convenience: Liquid Glass on iOS 26+, with `tint` filling
    /// `shape` as the pre-iOS-26 fallback instead of `.regularMaterial`. For
    /// controls whose active state is a flat accent fill matching the glass tint.
    nonisolated func adaptiveGlassBackground(
        in shape: some Shape,
        isInteractive: Bool = false,
        tintedFallback tint: Color
    ) -> some View {
        adaptiveGlassBackground(in: shape, isInteractive: isInteractive, tint: tint) {
            shape.fill(tint)
        }
    }

    /// Same as above, but supplies a custom pre-iOS-26 background — drawn exactly
    /// as given (NOT clipped to `shape`), so it defines its own shape. Pass a
    /// `RoundedRectangle`, `Capsule`, gradient, image, etc.
    nonisolated func adaptiveGlassBackground<Fallback: View>(
        in shape: some Shape,
        glass: AdaptiveGlassStyle = .regular,
        isInteractive: Bool = false,
        tint: Color? = nil,
        @ViewBuilder fallback: () -> Fallback
    ) -> some View {
        modifier(AdaptiveGlassBackground(shape: shape, glass: glass, isInteractive: isInteractive, tint: tint, fallback: fallback))
    }
}
