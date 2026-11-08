import SwiftUI

struct TorchButton: View {
    let isOn: Bool
    let toggle: () -> Void

    @State private var press = HoldToToggle()
    @State private var holdTimer: Task<Void, Never>?
    @State private var buzzes = 0
    @State private var size = CGSize.zero

    private static let heldScale: CGFloat = 1.15

    var body: some View {
        ControlButtonChrome(glass: true, isInteractive: false, isPressed: press.isHeld, growth: press.isHeld ? Self.heldScale : 1) {
            Image(systemName: symbol)
                .scaleEffect(press.isHeld ? Self.heldScale : 1)
        }
        .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary))
        .animation(press.isHeld ? .linear(duration: HoldToToggle.holdDuration) : .appQuickFade, value: press.isHeld)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .overlay {
            ImmediatePressArea(
                largeContentTitle: String(localized: .cameraFlashlight),
                largeContentSymbol: symbol,
                onChange: touch,
                onEnd: release,
                onCancel: abandonUnfinishedPress
            )
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: buzzes)
        .accessibilityRepresentation {
            Toggle(isOn: isOnBinding) {
                Text(.cameraFlashlight)
            }
        }
    }

    private var heldBounds: CGRect {
        let growth = Self.heldScale - 1
        return CGRect(origin: .zero, size: size).insetBy(dx: -size.width * growth / 2, dy: -size.height * growth / 2)
    }

    private var symbol: String {
        isOn ? "flashlight.on.fill" : "flashlight.off.fill"
    }

    private func touch(at location: CGPoint) {
        let isNewPress = press.phase == .idle
        press.touch(at: location, in: heldBounds)
        if isNewPress { startHoldTimer() }
    }

    private func release() {
        holdTimer?.cancel()
        if press.release() { toggle() }
    }

    private func startHoldTimer() {
        holdTimer?.cancel()
        holdTimer = Task {
            try? await Task.sleep(for: .seconds(HoldToToggle.holdDuration))
            guard !Task.isCancelled, press.holdElapsed() else { return }
            buzzes += 1
        }
    }

    private func abandonUnfinishedPress() {
        guard press.phase != .idle else { return }
        holdTimer?.cancel()
        press = HoldToToggle()
    }

    private var isOnBinding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { newValue in
                if newValue != isOn { toggle() }
            }
        )
    }
}

#if DEBUG
#Preview {
    @Previewable @State var isOn = false

    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        TorchButton(isOn: isOn) { isOn.toggle() }
    }
}
#endif
