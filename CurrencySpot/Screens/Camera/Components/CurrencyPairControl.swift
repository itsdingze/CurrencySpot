import SwiftUI

struct CurrencyPairControl: View {
    @Environment(CameraViewModel.self) private var viewModel
    @State private var isFlipped = false

    var body: some View {
        HStack(spacing: Spacing.element) {
            currencyButton(
                code: viewModel.baseCurrency,
                caption: .cameraCurrencyPairFrom,
                destination: .basePicker,
                accessibilityLabel: .cameraCurrencyPairBaseAccessibilityLabel
            )

            swapButton

            currencyButton(
                code: viewModel.targetCurrency,
                caption: .cameraCurrencyPairTo,
                destination: .targetPicker,
                accessibilityLabel: .cameraCurrencyPairTargetAccessibilityLabel
            )
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.chipPadding)
        .adaptiveGlassBackground(in: .capsule, isInteractive: true)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    private func currencyButton(
        code: CurrencyCode,
        caption: LocalizedStringResource,
        destination: CameraViewModel.Destination,
        accessibilityLabel: LocalizedStringResource
    ) -> some View {
        Button {
            viewModel.destination = destination
        } label: {
            VStack(spacing: 0) {
                Text(caption)
                    .font(.appCaption)
                    .foregroundStyle(Color.secondary)

                FixedWidthCurrencyLabel(code: code)
            }
        }
        .buttonStyle(.currencyCode())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(code.rawValue)
        .accessibilityInputLabels([
            Text(caption),
            Text(verbatim: code.rawValue),
            Text(verbatim: code.localizedName),
            Text(accessibilityLabel),
        ])
        .accessibilityShowsLargeContentViewer {
            Text(verbatim: code.rawValue)
        }
    }

    private var swapButton: some View {
        Button {
            withAnimation(.appFlip) {
                isFlipped.toggle()
                viewModel.swapCurrencies()
            }
        } label: {
            Image(systemName: "arrow.trianglehead.swap")
                .foregroundStyle(.tint)
                .rotationEffect(.degrees(90))
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .buttonStyle(.controlButton(glass: false))
        .accessibilityLabel(.cameraCurrencyPairSwapAccessibilityLabel)
        .accessibilityShowsLargeContentViewer {
            Label(.cameraCurrencyPairSwapAccessibilityLabel, systemImage: "arrow.left.arrow.right")
        }
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
