import SwiftUI

struct HeaderSection: View {
    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel
    @Binding var isChartSelectionActive: Bool

    var body: some View {
        VStack(spacing: Spacing.section) {
            currentRateView

            TimeRangePicker(
                selectedTimeRange: historyViewModel.selectedTimeRange,
                onSelect: historyViewModel.selectTimeRange
            )
            .opacity(isChartSelectionActive ? 0 : 1)
        }
    }

    // MARK: - Private Views

    private var currentRateView: some View {
        VStack(spacing: Spacing.hairline) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                Text(historyViewModel.targetCurrency.rawValue)
                    .font(.appTitle)
                    .accessibilityLabel("\(historyViewModel.targetCurrency.rawValue), \(CurrencyNameLookup.name(for: historyViewModel.targetCurrency))")

                Text(CurrencyNameLookup.name(for: historyViewModel.targetCurrency))
                    .font(.appHeadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                    Text(historyViewModel.formattedCurrentRate)
                        .font(.appTitle3)
                        .accessibilityLabel("Current rate: \(historyViewModel.formattedCurrentRate)")
                        .accessibilityAddTraits(.updatesFrequently)

                    if let percentChange = historyViewModel.percentChange,
                       let priceChange = historyViewModel.priceChange
                    {
                        percentChangeIndicator(priceChange: priceChange, percentChange: percentChange)
                    }

                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading, spacing: Spacing.hairline) {
                        Text(historyViewModel.formattedCurrentRate)
                            .font(.appTitle3)
                            .accessibilityLabel("Current rate: \(historyViewModel.formattedCurrentRate)")
                            .accessibilityAddTraits(.updatesFrequently)

                        if let percentChange = historyViewModel.percentChange,
                           let priceChange = historyViewModel.priceChange
                        {
                            percentChangeIndicator(priceChange: priceChange, percentChange: percentChange)
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func percentChangeIndicator(priceChange: Double, percentChange: Double) -> some View {
        HStack(spacing: Spacing.hairline) {
            Image(systemName: historyViewModel.trendDirection.systemImage)
                .accessibilityHidden(true)

            Text("\(priceChange.formatted(.number.precision(.fractionLength(0 ... 4)).sign(strategy: .never))) (\(abs(percentChange).toStringMax2Decimals)%)")
        }
        .font(.appSubheadline.weight(.medium))
        .foregroundStyle(historyViewModel.trendDirection.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityChangeLabel(priceChange: priceChange, percentChange: percentChange))
        .accessibilityValue("\(historyViewModel.trendDirection.description) \(abs(percentChange).toStringMax2Decimals) percent")
    }

    private func accessibilityChangeLabel(priceChange: Double, percentChange: Double) -> String {
        let direction = historyViewModel.trendDirection.description
        let changeText = "\(abs(priceChange).formatted(.number.precision(.fractionLength(0 ... 4))))"
        return "Price change: \(direction) \(changeText), \(abs(percentChange).toStringMax2Decimals) percent"
    }
}

#if DEBUG
#Preview {
    HeaderSection(isChartSelectionActive: .constant(false))
        .withDependencyContainer(.preview())
        .padding()
}
#endif
