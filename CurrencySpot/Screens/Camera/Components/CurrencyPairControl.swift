import SwiftUI

struct CurrencyPairControl: View {
    @Environment(CameraViewModel.self) private var viewModel
    @State private var isFlipped = false

    var body: some View {
        HStack(spacing: Spacing.element) {
            currencyButton(
                code: viewModel.baseCurrency,
                caption: "From",
                destination: .basePicker,
                accessibilityLabel: "Price tag currency"
            )

            swapButton

            currencyButton(
                code: viewModel.targetCurrency,
                caption: "To",
                destination: .targetPicker,
                accessibilityLabel: "Converted currency"
            )
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.chipPadding)
        .adaptiveGlassBackground(in: .capsule, isInteractive: true)
    }

    private func currencyButton(
        code: CurrencyCode,
        caption: String,
        destination: CameraViewModel.Destination,
        accessibilityLabel: String
    ) -> some View {
        Button {
            viewModel.destination = destination
        } label: {
            VStack(spacing: 0) {
                Text(caption)
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)

                FixedWidthCurrencyLabel(code: code)
            }
        }
        .buttonStyle(.currencyCode())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(code.rawValue)
    }

    private var swapButton: some View {
        Button {
            withAnimation(.appFlip) {
                isFlipped.toggle()
                viewModel.swapCurrencies()
            }
        } label: {
            Image(systemName: "arrow.trianglehead.swap")
                .foregroundStyle(Color.accentColor)
                .rotationEffect(.degrees(90))
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .buttonStyle(.controlButton(glass: false))
        .accessibilityLabel("Swap currencies")
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        CurrencyPairControl()
    }
    .withDependencyContainer(container)
}
#endif
