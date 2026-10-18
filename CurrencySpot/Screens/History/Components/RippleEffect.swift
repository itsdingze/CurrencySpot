import SwiftUI

struct RippleEffect<Style: ShapeStyle>: View {
    let isActive: Bool
    let color: Style

    @State private var rippleCount = 0

    private struct Ripple {
        var scale: CGFloat = 1
        var opacity: Double = 0
    }

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.5)
            .frame(width: 8, height: 8)
            .keyframeAnimator(initialValue: Ripple(), trigger: rippleCount) { content, ripple in
                content
                    .scaleEffect(ripple.scale)
                    .opacity(ripple.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(1)
                    SpringKeyframe(3, duration: 0.5, spring: .snappy)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0)
                    SpringKeyframe(1, duration: 0.2, spring: .snappy)
                    LinearKeyframe(0, duration: 0.6, timingCurve: .easeOut)
                }
            }
            .accessibilityHidden(true)
            .onChange(of: isActive) { _, active in
                if active {
                    rippleCount += 1
                }
            }
    }
}

#Preview {
    @Previewable @State var isActive = false

    RippleEffect(isActive: isActive, color: .tint)
        .frame(width: 60, height: 60)
        .task { isActive = true }
}
