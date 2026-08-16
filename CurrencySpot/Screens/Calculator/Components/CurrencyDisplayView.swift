import SwiftUI

struct CurrencyDisplayView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel: CalculatorViewModel

    var body: some View {
        VStack(spacing: Spacing.tight) {
            sourceCurrencyView
            SwapButtonDivider()
            targetCurrencyView
        }
        .padding(Spacing.cardPadding)
        .background(Color.secondaryBackground, in: .rect(cornerRadius: Radius.container))
    }

    // MARK: - Private Views

    @ViewBuilder
    private var sourceCurrencyView: some View {
        UnifiedCurrencyView(
            type: .source,
            amount: calculatorViewModel.inputAmount.formatted(.number.precision(.fractionLength(2))),
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

#if DEBUG
#Preview {
    CurrencyDisplayView()
        .withDependencyContainer(.preview())
        .padding()
}
#endif
