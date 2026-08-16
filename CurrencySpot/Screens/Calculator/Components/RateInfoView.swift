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

    private var accessibilityContainerLabel: String {
        var label = "Exchange rate information. "
        if shouldShowConversionRate {
            label += "Current rate: \(formattedConversionRate). "
        }
        label += "Last updated: \(viewModel.formattedLastUpdated)"
        return label
    }

    // MARK: - Private Views

    @ViewBuilder
    private var conversionRateText: some View {
        Text(formattedConversionRate)
            .font(.appCaption)
            .foregroundStyle(Color.textSecondary)
    }

    @ViewBuilder
    private var lastUpdatedText: some View {
        Text(viewModel.formattedLastUpdated)
            .font(.appCaption)
            .foregroundStyle(Color.textSecondary)
    }

    // MARK: - Private Properties

    private var shouldShowConversionRate: Bool {
        viewModel.baseCurrency != viewModel.targetCurrency
    }

    private var formattedConversionRate: String {
        "1 \(viewModel.baseCurrency.rawValue) = \(viewModel.conversionRate.toStringMax4Decimals) \(viewModel.targetCurrency.rawValue)"
    }
}

#if DEBUG
#Preview {
    RateInfoView()
        .withDependencyContainer(.preview())
        .padding()
}
#endif
