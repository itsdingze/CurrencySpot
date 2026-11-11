import SwiftUI

struct LiveViewfinder<Overlay: View>: View {
    let overlay: Overlay

    @Environment(LiveCameraController.self) private var liveCamera

    var body: some View {
        ZStack {
            LiveCameraPreviewView(preview: liveCamera.preview)
                .accessibilityElement()
                .accessibilityLabel(.appTabCamera)
                .accessibilityZoomAction(zoom)
            overlay
                .offset(liveCamera.motionOffset)
        }
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { liveCamera.pinch(by: $0.magnification) }
                .onEnded { _ in liveCamera.endPinch() }
        )
    }

    private func zoom(_ action: AccessibilityZoomGestureAction) {
        switch action.direction {
        case .zoomIn: liveCamera.zoomIn()
        case .zoomOut: liveCamera.zoomOut()
        @unknown default: break
        }
    }
}

#if DEBUG
#Preview {
    LiveViewfinder(overlay: Color.clear)
        .withDependencyContainer(.preview())
}
#endif
