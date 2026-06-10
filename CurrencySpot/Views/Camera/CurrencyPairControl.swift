//
//  CurrencyPairControl.swift
//  CurrencySpot
//

import SwiftUI

/// Base → target pair control floating over the camera feed.
/// Base is the currency the price tags are in; target is what badges show.
struct CurrencyPairControl: View {
    @Environment(CameraViewModel.self) private var viewModel

    var body: some View {
        HStack(spacing: 12) {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
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
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                Text(code)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(minWidth: 56)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(code)
        .accessibilityHint("Opens the currency picker")
    }

    private var swapButton: some View {
        Button {
            withAnimation(.snappy) {
                viewModel.swapCurrencies()
            }
        } label: {
            Image(systemName: "arrow.trianglehead.swap")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color.accentColor)
        }
        .accessibilityLabel("Swap currencies")
        .accessibilityHint("Swaps the price tag and converted currencies")
    }
}

#Preview {
    let container = DependencyContainer.preview()

    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        CurrencyPairControl()
    }
    .withDependencyContainer(container)
}
