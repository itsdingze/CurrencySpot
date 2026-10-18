import SwiftUI

struct HeaderSection: View {
    @Environment(CurrencyHistoryViewModel.self) private var viewModel
    @Binding var isChartSelectionActive: Bool

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: Spacing.section) {
            currentRateView

            TimeRangePicker(selectedTimeRange: $viewModel.selectedTimeRange)
                .opacity(isChartSelectionActive ? 0 : 1)
        }
    }

    // MARK: - Private Views

    private var statistics: ChartStatistics {
        viewModel.chartStatistics
    }

    private var currentRateView: some View {
        VStack(spacing: Spacing.hairline) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                Text(viewModel.targetCurrency.rawValue)
                    .font(.appTitle)
                    .accessibilityLabel("\(viewModel.targetCurrency.rawValue), \(viewModel.targetCurrency.localizedName)")

                Text(viewModel.targetCurrency.localizedName)
                    .font(.appHeadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                    Text(viewModel.formattedCurrentRate)
                        .font(.appTitle3)
                        .accessibilityLabel("Current rate: \(viewModel.formattedCurrentRate)")
                        .accessibilityAddTraits(.updatesFrequently)

                    if let percentChange = statistics.percentChange,
                       let priceChange = statistics.priceChange
                    {
                        percentChangeIndicator(priceChange: priceChange, percentChange: percentChange)
                    }

                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading, spacing: Spacing.hairline) {
                        Text(viewModel.formattedCurrentRate)
                            .font(.appTitle3)
                            .accessibilityLabel("Current rate: \(viewModel.formattedCurrentRate)")
                            .accessibilityAddTraits(.updatesFrequently)

                        if let percentChange = statistics.percentChange,
                           let priceChange = statistics.priceChange
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
            Image(systemName: statistics.trendDirection.systemImage)
                .accessibilityHidden(true)

            Text("\(priceChange.formatted(.number.precision(.fractionLength(0 ... 4)).sign(strategy: .never))) (\(abs(percentChange).toStringMax2Decimals)%)")
        }
        .font(.appSubheadline.weight(.medium))
        .foregroundStyle(statistics.trendDirection.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityChangeLabel(priceChange: priceChange, percentChange: percentChange))
        .accessibilityValue("\(statistics.trendDirection.description) \(abs(percentChange).toStringMax2Decimals) percent")
    }

    private func accessibilityChangeLabel(priceChange: Double, percentChange: Double) -> String {
        let direction = statistics.trendDirection.description
        let changeText = "\(abs(priceChange).formatted(.number.precision(.fractionLength(0 ... 4))))"
        return "Price change: \(direction) \(changeText), \(abs(percentChange).toStringMax2Decimals) percent"
    }
}

#if DEBUG
#Preview {
    @Previewable @State var viewModel = CurrencyHistoryViewModel.preview()

    HeaderSection(isChartSelectionActive: .constant(false))
        .environment(viewModel)
        .task { await viewModel.loadChart() }
        .padding()
}
#endif
