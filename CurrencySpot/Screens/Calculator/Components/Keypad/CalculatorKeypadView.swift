import SwiftUI

struct CalculatorKeypadView: View {
    @Environment(CalculatorViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var keyPresses = 0
    @State private var deletePresses = 0
    @State private var rejectedPresses = 0
    @State private var pressOrder: [KeypadKey.ID] = []
    @State private var isSwiping = false
    @State private var suppressesTaps = false
    @GestureState private var isDragging = false

    private let swipeThreshold: CGFloat = 60
    private let topFadeHeight = Spacing.element
    private let shadowOverflow = Spacing.onboarding

    private var progress: CGFloat {
        viewModel.keypadMode == .calculator ? 1 : 0
    }

    private var modeSelection: Binding<CalculatorViewModel.KeypadMode> {
        Binding { viewModel.keypadMode } set: { switchKeypad(to: $0) }
    }

    var body: some View {
        VStack(spacing: Spacing.tight) {
            keypad
            KeypadPageIndicator(mode: modeSelection)
        }
        .sensoryFeedback(.selection, trigger: keyPresses)
        .sensoryFeedback(.decrease, trigger: deletePresses)
        .sensoryFeedback(.warning, trigger: rejectedPresses)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.keypadMode)
        .onChange(of: viewModel.keypadMode) { _, mode in
            AccessibilityNotification.Announcement(String(localized: mode.title)).post()
        }
        .onChange(of: isDragging) { _, isDragging in
            if !isDragging { dragFinished() }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var keypad: some View {
        Group {
            if reduceMotion {
                keys
                    .id(viewModel.keypadMode)
                    .transition(.opacity)
            } else {
                keys
            }
        }
        .mask { KeypadMask(progress: progress, topFadeHeight: topFadeHeight, overflow: shadowOverflow) }
        .contentShape(.rect)
        .simultaneousGesture(swipe)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(.calculatorNumberPadAccessibilityLabel)
    }

    private var keys: some View {
        KeypadMorphLayout(progress: progress, spacing: Spacing.element) {
            ForEach(KeypadKey.all) { key in
                KeypadKeyButton(
                    key: key,
                    progress: progress,
                    mode: viewModel.keypadMode,
                    onPress: { bringToFront(key) },
                    action: tap
                )
                .zIndex(zIndex(of: key))
                .accessibilityHidden(!key.isPresent(in: viewModel.keypadMode))
            }
        }
    }

    // MARK: - Switching

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($isDragging) { _, isDragging, _ in isDragging = true }
            .onChanged { value in
                guard isSwiping || abs(value.translation.width) > abs(value.translation.height) else { return }
                isSwiping = true
                suppressesTaps = true
            }
            .onEnded { value in
                guard isSwiping else { return }
                let travel = value.predictedEndTranslation.width
                if travel < -swipeThreshold {
                    switchKeypad(to: .calculator)
                } else if travel > swipeThreshold {
                    switchKeypad(to: .amount)
                }
            }
    }

    private func dragFinished() {
        Task {
            isSwiping = false
            suppressesTaps = false
        }
    }

    private func switchKeypad(to mode: CalculatorViewModel.KeypadMode) {
        withAnimation(CalculatorViewModel.KeypadMode.switchAnimation(reduceMotion: reduceMotion)) {
            viewModel.showKeypad(mode)
        }
    }

    // MARK: - Keys

    private func tap(_ key: KeypadKey) {
        guard !suppressesTaps else { return }
        switch viewModel.press(key.role(in: viewModel.keypadMode)) {
        case .accepted:
            keyPresses += 1
        case .deleted:
            deletePresses += 1
        case .settled:
            keyPresses += 1
            announceResult()
        case .undefined:
            rejectedPresses += 1
            AccessibilityNotification.Announcement(String(localized: .calculatorCalculationDivideByZero)).post()
        case .rejected:
            rejectedPresses += 1
        }
    }

    private func announceResult() {
        let announcement = String(localized: .calculatorAnnouncementResult(amount: viewModel.formattedInputAmount))
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func zIndex(of key: KeypadKey) -> Double {
        pressOrder.firstIndex(of: key.id).map { Double($0 + 1) } ?? 0
    }

    private func bringToFront(_ key: KeypadKey) {
        pressOrder.removeAll { $0 == key.id }
        pressOrder.append(key.id)
    }
}

#if DEBUG
#Preview {
    CalculatorKeypadView()
        .withDependencyContainer(.preview())
        .frame(height: 460)
        .padding()
}
#endif
