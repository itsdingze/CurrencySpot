import SwiftUI

extension View {
    func adaptiveBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        modifier(AdaptiveBottomBar(bar: bar()))
    }
}

private struct AdaptiveBottomBar<Bar: View>: ViewModifier {
    let bar: Bar

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .safeAreaBar(edge: .bottom) { bar }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content.safeAreaInset(edge: .bottom) { bar.background(.bar) }
        }
    }
}
