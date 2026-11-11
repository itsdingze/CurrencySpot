import SwiftUI

struct RateInfoView: View {
    @Environment(CalculatorViewModel.self) private var viewModel: CalculatorViewModel

    var body: some View {
        DelayedUpdatingBanner(banner: viewModel.rateBanner) { banner in
            if banner == .hidden {
                rateAndLastUpdated
            } else {
                rateAndStatus(banner)
            }
        }
    }

    @ViewBuilder
    private var rateAndLastUpdated: some View {
        if isRateUnavailable {
            VStack(spacing: Spacing.hairline) {
                conversionRateText
                lastUpdatedText
            }
            .accessibilityElement(children: .contain)
        } else {
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
    }

    private func rateAndStatus(_ banner: RateBanner) -> some View {
        VStack(spacing: Spacing.hairline) {
            if shouldShowConversionRate {
                conversionRateText
                    .accessibilityAddTraits(.updatesFrequently)
            }
            RateStatusLine(
                status: banner,
                savedRatesTime: viewModel.savedRatesTime,
                showsRetry: viewModel.canRetryRates,
                retryAction: viewModel.retryFetch
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var accessibilityContainerLabel: LocalizedStringResource {
        let shownRate = shouldShowConversionRate ? viewModel.conversionRate : nil
        switch (shownRate.map { String(localized: conversionRate($0)) }, viewModel.lastUpdated) {
        case let (rate?, lastUpdated?):
            return .calculatorRateInfoAccessibilityLabelRateUpdated(rate: rate, date: lastUpdated.lastUpdatedDisplay)
        case let (rate?, nil):
            return .calculatorRateInfoAccessibilityLabelRateNotUpdated(rate: rate)
        case let (nil, lastUpdated?):
            return .calculatorRateInfoAccessibilityLabelUpdated(date: lastUpdated.lastUpdatedDisplay)
        case (nil, nil):
            return .calculatorRateInfoAccessibilityLabelNotUpdated
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var conversionRateText: some View {
        Group {
            if let rate = viewModel.conversionRate {
                Text(conversionRate(rate))
            } else {
                Text(.cameraRatesNoticeMissingPair)
            }
        }
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

    private var isRateUnavailable: Bool {
        shouldShowConversionRate && viewModel.conversionRate == nil
    }

    private func conversionRate(_ rate: Double) -> LocalizedStringResource {
        .calculatorRateInfoConversionRate(
            base: viewModel.baseCurrency.rawValue,
            rate: rate.rateText,
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
