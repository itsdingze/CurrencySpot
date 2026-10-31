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

    private var currentRateView: some View {
        VStack(spacing: Spacing.hairline) {
            AdaptiveStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                Text(viewModel.targetCurrency.rawValue)
                    .font(.appTitle)
                    .accessibilityLabel(.historyHeaderCurrencyAccessibilityLabel(
                        code: viewModel.targetCurrency.rawValue,
                        name: viewModel.targetCurrency.localizedName
                    ))

                Text(viewModel.targetCurrency.localizedName)
                    .font(.appHeadline.weight(.regular))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                    currentRateText

                    if let statistics = viewModel.chartStatistics,
                       let percentChange = statistics.percentChange,
                       let priceChange = statistics.priceChange
                    {
                        percentChangeIndicator(statistics, priceChange: priceChange, percentChange: percentChange)
                    }

                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading, spacing: Spacing.hairline) {
                        currentRateText

                        if let statistics = viewModel.chartStatistics,
                           let percentChange = statistics.percentChange,
                           let priceChange = statistics.priceChange
                        {
                            percentChangeIndicator(statistics, priceChange: priceChange, percentChange: percentChange)
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    private var currentRateText: some View {
        Text(viewModel.formattedCurrentRate)
            .font(.appTitle3)
            .accessibilityLabel(viewModel.currentRateAccessibilityLabel)
            .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private func percentChangeIndicator(_ statistics: ChartStatistics, priceChange: Double, percentChange: Double) -> some View {
        let trend = statistics.trendDirection
        let change = abs(priceChange).rateText(matching: statistics.currentRate)
        let percent = (abs(percentChange) / 100).formatted(.percent.precision(.fractionLength(0 ... 2)))

        HStack(spacing: Spacing.hairline) {
            Image(systemName: trend.systemImage)
                .accessibilityHidden(true)

            Text(.historyHeaderChange(change: change, percent: percent))
        }
        .font(.appSubheadline.weight(.semibold))
        .foregroundStyle(trend.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityChangeLabel(change: change, percent: percent, trend: trend))
        .accessibilityValue(accessibilityChangeValue(percent: percent, trend: trend))
    }

    private func accessibilityChangeLabel(change: String, percent: String, trend: TrendDirection) -> LocalizedStringResource {
        switch trend {
        case .up: .historyHeaderChangeAccessibilityLabelUp(change: change, percent: percent)
        case .down: .historyHeaderChangeAccessibilityLabelDown(change: change, percent: percent)
        case .stable: .historyHeaderChangeAccessibilityLabelStable(change: change, percent: percent)
        }
    }

    private func accessibilityChangeValue(percent: String, trend: TrendDirection) -> LocalizedStringResource {
        switch trend {
        case .up: .historyHeaderChangeAccessibilityValueUp(percent: percent)
        case .down: .historyHeaderChangeAccessibilityValueDown(percent: percent)
        case .stable: .historyHeaderChangeAccessibilityValueStable(percent: percent)
        }
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
