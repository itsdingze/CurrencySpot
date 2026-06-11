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

    private let flipDuration: TimeInterval = 0.6

    var body: some View {
        HStack(spacing: 16) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                
                // This applies the same width to all buttons because font is not monospaced.
                ZStack(alignment: .center) {
                    Text("WWI")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.clear)
                    
                    Text(code)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.horizontal, 8)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(code)
        .accessibilityHint("Opens the currency picker")
    }

    private var swapButton: some View {
        Button {
            withAnimation(.bouncy(duration: flipDuration)) {
                isFlipped.toggle()
                viewModel.swapCurrencies()
            }
        } label: {
            Image(systemName: "arrow.trianglehead.swap")
                .font(.system(.headline, design: .rounded))
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

#Preview {
    let container = DependencyContainer.preview()

    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        CurrencyPairControl()
    }
    .withDependencyContainer(container)
}
