import SwiftUI

private nonisolated struct AdaptiveGlassBackground<S: Shape, Fallback: View>: ViewModifier {
    let shape: S
    let isInteractive: Bool
    let tint: Color?
    let fallback: Fallback

    init(
        shape: S,
        isInteractive: Bool,
        tint: Color?,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.shape = shape
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
        var base: Glass = .regular
        if let tint { base = base.tint(tint) }
        if isInteractive { base = base.interactive() }
        return base
    }
}

extension View {
    nonisolated func adaptiveGlassBackground(
        in shape: some Shape,
        isInteractive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        adaptiveGlassBackground(in: shape, isInteractive: isInteractive, tint: tint) {
            shape.fill(.regularMaterial)
        }
    }

    nonisolated func adaptiveGlassBackground(
        in shape: some Shape,
        isInteractive: Bool = false,
        tintedFallback tint: Color
    ) -> some View {
        adaptiveGlassBackground(in: shape, isInteractive: isInteractive, tint: tint) {
            shape.fill(tint)
        }
    }

    nonisolated func adaptiveGlassBackground<Fallback: View>(
        in shape: some Shape,
        isInteractive: Bool = false,
        tint: Color? = nil,
        @ViewBuilder fallback: () -> Fallback
    ) -> some View {
        modifier(AdaptiveGlassBackground(shape: shape, isInteractive: isInteractive, tint: tint, fallback: fallback))
    }
}
