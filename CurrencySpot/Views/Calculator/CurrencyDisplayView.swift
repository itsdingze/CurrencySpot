//
//  CurrencyDisplayView.swift
//  CurrencySpot
//

import SwiftUI

struct CurrencyDisplayView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel: CalculatorViewModel

    private let containerCornerRadius: CGFloat = 16
    private let itemSpacing: CGFloat = 8
    private let containerPadding: CGFloat = 16

    var body: some View {
        VStack(spacing: itemSpacing) {
            sourceCurrencyView
            SwapButtonDivider()
            targetCurrencyView
        }
        .padding(containerPadding)
        .background(
            RoundedRectangle(cornerRadius: containerCornerRadius)
                .fill(Color.secondaryBackground)
        )
    }

    // MARK: - Private Views

    @ViewBuilder
    private var sourceCurrencyView: some View {
        UnifiedCurrencyView(
            type: .source,
            amount: calculatorViewModel.inputAmount.toString2Decimals,
            currencyCode: calculatorViewModel.baseCurrency,
            onPress: selectSourceCurrency
        )
    }

    @ViewBuilder
    private var targetCurrencyView: some View {
        UnifiedCurrencyView(
            type: .converted,
            amount: calculatorViewModel.convertedAmount,
            currencyCode: calculatorViewModel.targetCurrency,
            onPress: selectTargetCurrency
        )
    }

    // MARK: - Private Methods

    private func selectSourceCurrency() {
        calculatorViewModel.isSelectingFromCurrency = true
        calculatorViewModel.showCurrencyPicker = true
    }

    private func selectTargetCurrency() {
        calculatorViewModel.isSelectingFromCurrency = false
        calculatorViewModel.showCurrencyPicker = true
    }
}
