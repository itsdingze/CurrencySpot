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
    /// Mirrors the swap button's glass circle (icon frame + padding on each side,
    /// Dynamic Type aware) so the divider can be cut to exactly its footprint.
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = .controlIconSize
    private var buttonDiameter: CGFloat { iconSize + 2 * .controlIconPadding }

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
                .controlIconStyle()
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 1, y: 0, z: 0)
                )
                .adaptiveGlassBackground(in: .circle, isInteractive: true)
        }
        .accessibilityIdentifier("SwapButtonDivider")
        .accessibilityLabel("Swap currencies")
        .accessibilityHint("Swaps the source and target currencies")
        .accessibilityInputLabels(["Swap", "Switch", "Exchange", "Flip currencies"])
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Private Methods

    private func performSwap() {
        withAnimation(.appFlip) {
            isFlipped.toggle()
            viewModel.swapCurrencies()
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
