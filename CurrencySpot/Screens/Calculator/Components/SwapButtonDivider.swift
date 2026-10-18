import SwiftUI

struct SwapButtonDivider: View {
    @Environment(CalculatorViewModel.self) private var viewModel: CalculatorViewModel
    @State private var isFlipped = false

    private let dividerHeight: CGFloat = 2
    @ScaledMetric(relativeTo: .headline) private var buttonDiameter: CGFloat = ControlMetrics.buttonSize

    var body: some View {
        ZStack {
            dividerLine
            swapButton
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var dividerLine: some View {
        Rectangle()
            .fill(Color.background)
            .frame(height: dividerHeight)
            .mask {
                Rectangle()
                    .overlay {
                        Circle()
                            .frame(width: buttonDiameter, height: buttonDiameter)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
    }

    @ViewBuilder
    private var swapButton: some View {
        Button(action: performSwap) {
            Image(systemName: "arrow.trianglehead.swap")
                .foregroundStyle(.tint)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 1, y: 0, z: 0)
                )
        }
        .buttonStyle(.controlButton)
        .accessibilityIdentifier("SwapButtonDivider")
        .accessibilityLabel(.calculatorSwapAccessibilityLabel)
    }

    // MARK: - Private Methods

    private func performSwap() {
        withAnimation(.appFlip) {
            isFlipped.toggle()
            viewModel.swapCurrencies()
            AccessibilityNotification.Announcement(String(localized: swapAnnouncement)).post()
        }
    }

    private var swapAnnouncement: LocalizedStringResource {
        .calculatorSwapAnnouncement(
            base: viewModel.baseCurrency.rawValue,
            target: viewModel.targetCurrency.rawValue
        )
    }
}

#if DEBUG
#Preview {
    SwapButtonDivider()
        .withDependencyContainer(.preview())
        .padding()
        .background(Color.secondaryBackground)
}
#endif
