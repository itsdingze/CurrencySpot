//
//  CurrencyDisplayView.swift
//  CurrencySpot
//

import SwiftUI

struct CurrencyDisplayView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel: CalculatorViewModel

    var body: some View {
        VStack(spacing: .tightGap) {
            sourceCurrencyView
            SwapButtonDivider()
            targetCurrencyView
        }
        .padding(.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: .containerRadius)
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
        calculatorViewModel.destination = .basePicker
    }

    private func selectTargetCurrency() {
        calculatorViewModel.destination = .targetPicker
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    CurrencyDisplayView()
        .withDependencyContainer(DependencyContainer.preview())
        .padding()
}
#endif
