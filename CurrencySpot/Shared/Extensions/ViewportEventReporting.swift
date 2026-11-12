import SwiftUI

extension View {
    func onViewportEvent(_ action: @escaping (ViewportEvent, UUID) -> Void) -> some View {
        modifier(ViewportEventReporting(action: action))
    }
}

private struct ViewportEventReporting: ViewModifier {
    let action: (ViewportEvent, UUID) -> Void
    @State private var viewport = UUID()
    @State private var size = CGSize.zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { newSize in
                size = newSize
                action(.resized(newSize), viewport)
            }
            .onAppear { action(.appeared(size), viewport) }
            .onDisappear { action(.disappeared, viewport) }
    }
}
