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
    private let buttonSize: CGFloat = 40
    private let flipDuration: TimeInterval = 0.6

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
    }

    @ViewBuilder
    private var swapButton: some View {
        Button(action: performSwap) {
            ZStack {
                buttonBackground
                swapIcon
            }
        }
        .background(Color.secondaryBackground)
        .accessibilityIdentifier("SwapButtonDivider")
        .accessibilityLabel("Swap currencies")
        .accessibilityHint("Swaps the source and target currencies")
        .accessibilityInputLabels(["Swap", "Switch", "Exchange", "Flip currencies"])
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        Circle()
            .fill(Color.background)
            .frame(width: buttonSize, height: buttonSize)
    }

    @ViewBuilder
    private var swapIcon: some View {
        Image(systemName: "arrow.trianglehead.swap")
            .font(.system(.headline, design: .rounded))
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 1, y: 0, z: 0)
            )
    }

    // MARK: - Private Methods

    private func performSwap() {
        withAnimation(.bouncy(duration: flipDuration)) {
            isFlipped.toggle()
            swap(&viewModel.baseCurrency, &viewModel.targetCurrency)
        }
    }
}
