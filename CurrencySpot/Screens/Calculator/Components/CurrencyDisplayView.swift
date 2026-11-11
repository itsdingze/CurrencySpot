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
            amount: sourceAmount,
            compactAmount: sourceCompactAmount,
            currencyCode: calculatorViewModel.baseCurrency,
            caption: calculatorViewModel.calculationSteps,
            unavailableReason: sourceUnavailableReason,
            onPress: selectSourceCurrency
        )
    }

    @ViewBuilder
    private var targetCurrencyView: some View {
        UnifiedCurrencyView(
            type: .converted,
            amount: convertedAmount ?? Self.noAmountPlaceholder,
            compactAmount: compactConvertedAmount ?? Self.noAmountPlaceholder,
            currencyCode: calculatorViewModel.targetCurrency,
            unavailableReason: targetUnavailableReason,
            onPress: selectTargetCurrency
        )
    }

    private static let noAmountPlaceholder = "—"

    private var isUndefined: Bool {
        calculatorViewModel.isCalculationUndefined
    }

    private var convertedAmount: String? {
        isUndefined ? nil : calculatorViewModel.convertedAmount
    }

    private var compactConvertedAmount: String? {
        isUndefined ? nil : calculatorViewModel.compactConvertedAmount
    }

    private var sourceUnavailableReason: LocalizedStringResource? {
        isUndefined ? .calculatorCalculationDivideByZero : nil
    }

    private var targetUnavailableReason: LocalizedStringResource? {
        if isUndefined { return .calculatorCalculationDivideByZero }
        return calculatorViewModel.convertedAmount == nil ? .cameraRatesNoticeMissingPair : nil
    }

    private var sourceAmount: String {
        isUndefined ? String(localized: .calculatorCalculationDivideByZero) : calculatorViewModel.formattedInputAmount
    }

    private var sourceCompactAmount: String {
        isUndefined ? String(localized: .calculatorCalculationDivideByZeroShort) : calculatorViewModel.compactInputAmount
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
