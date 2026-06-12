//
//  CurrencyPairControl.swift
//  CurrencySpot
//

import SwiftUI

/// Base → target pair control floating over the camera feed.
/// Base is the currency the price tags are in; target is what badges show.
struct CurrencyPairControl: View {
    @Environment(CameraViewModel.self) private var viewModel
    @State private var isFlipped = false

    var body: some View {
        HStack(spacing: .sectionGap) {
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
        .padding(.horizontal, .cardPadding)
        .padding(.vertical, .chipPadding)
        .adaptiveGlassBackground(in: .capsule, isInteractive: true)
    }

    private func currencyButton(
        code: String,
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
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .buttonStyle(CurrencyCodeButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(code)
        .accessibilityHint("Opens the currency picker")
    }

    private var swapButton: some View {
        Button {
            withAnimation(.appFlip) {
                isFlipped.toggle()
                viewModel.swapCurrencies()
            }
        } label: {
            Image(systemName: "arrow.trianglehead.swap")
                .font(.appHeadline)
                .foregroundStyle(Color.accentColor)
                .rotationEffect(.degrees(90))
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .accessibilityLabel("Swap currencies")
        .accessibilityHint("Swaps the price tag and converted currencies")
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
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
