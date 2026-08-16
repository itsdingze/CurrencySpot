import SwiftUI

extension View {
    func blurSlide(_ show: Bool) -> some View {
        modifier(BlurSlideReveal(show: show))
    }
}

private struct BlurSlideReveal: ViewModifier {
    let show: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .blur(radius: show || reduceMotion ? 0 : 10)
            .opacity(show ? 1 : 0)
            .offset(y: show || reduceMotion ? 0 : 100)
    }
}
