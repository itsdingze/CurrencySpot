//
//  SwapButtonDivider.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/4/25.
//

import SwiftUI

struct SwapButtonDivider: View {
    @Environment(CalculatorViewModel.self) private var viewModel: CalculatorViewModel
    @State private var isFlipped = false

    private let dividerHeight: CGFloat = 2
    /// Mirrors `ControlButtonStyle`'s scaled diameter so the divider is cut to
    /// exactly the swap button's footprint.
    @ScaledMetric(relativeTo: .headline) private var buttonDiameter: CGFloat = .controlButtonSize

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
                .foregroundStyle(Color.accentColor)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 1, y: 0, z: 0)
                )
        }
        .buttonStyle(.controlButton)
        .accessibilityIdentifier("SwapButtonDivider")
        .accessibilityLabel("Swap currencies")
    }

    // MARK: - Private Methods

    private func performSwap() {
        withAnimation(.appFlip) {
            isFlipped.toggle()
            viewModel.swapCurrencies()
            AccessibilityNotification.Announcement("Swapped. \(viewModel.baseCurrency) to \(viewModel.targetCurrency)").post()
        }
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    SwapButtonDivider()
        .withDependencyContainer(DependencyContainer.preview())
        .padding()
        .background(Color.secondaryBackground)
}
#endif
