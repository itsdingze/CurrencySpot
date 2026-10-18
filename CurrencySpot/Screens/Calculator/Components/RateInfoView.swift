import SwiftUI

struct RateInfoView: View {
    @Environment(CalculatorViewModel.self) private var viewModel: CalculatorViewModel

    var body: some View {
        VStack(spacing: Spacing.hairline) {
            if shouldShowConversionRate {
                conversionRateText
            }
            lastUpdatedText
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityContainerLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var accessibilityContainerLabel: LocalizedStringResource {
        let rate = String(localized: conversionRate)
        switch (shouldShowConversionRate, viewModel.lastUpdated) {
        case let (true, lastUpdated?):
            return .calculatorRateInfoAccessibilityLabelRateUpdated(rate: rate, date: lastUpdated.lastUpdatedDisplay)
        case (true, nil):
            return .calculatorRateInfoAccessibilityLabelRateNotUpdated(rate: rate)
        case let (false, lastUpdated?):
            return .calculatorRateInfoAccessibilityLabelUpdated(date: lastUpdated.lastUpdatedDisplay)
        case (false, nil):
            return .calculatorRateInfoAccessibilityLabelNotUpdated
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var conversionRateText: some View {
        Text(conversionRate)
            .font(.appCaption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var lastUpdatedText: some View {
        Text(viewModel.formattedLastUpdated)
            .font(.appCaption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Private Properties

    private var shouldShowConversionRate: Bool {
        viewModel.baseCurrency != viewModel.targetCurrency
    }

    private var conversionRate: LocalizedStringResource {
        .calculatorRateInfoConversionRate(
            base: viewModel.baseCurrency.rawValue,
            rate: viewModel.conversionRate.toStringMax4Decimals,
            target: viewModel.targetCurrency.rawValue
        )
    }
}

#if DEBUG
#Preview {
    RateInfoView()
        .withDependencyContainer(.preview())
        .padding()
}
#endif
