import SwiftUI

struct CurrencyRow: View {
    let entry: CurrencyListEntry

    var showsTrendChart = true

    var metricsHidden = false

    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel

    var body: some View {
        let trendData = historyViewModel.getTrendData(for: entry.code)

        HStack(spacing: Spacing.element) {
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                Text(entry.code.rawValue)
                    .font(.appTitle2)

                Text(entry.name)
                    .lineLimit(1)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            ZStack(alignment: .trailing) {
                metrics(trendData, drawsChart: false)
                    .frame(width: 0)
                    .clipped()
                    .hidden()
                    .accessibilityHidden(true)

                if !metricsHidden {
                    // FIXME: the opacity transition only plays on the way OUT — entering
                    // edit mode fades the metrics away correctly, but tapping Done
                    // re-inserts them instantly with no fade. The insertion transition
                    // isn't running on edit-mode exit (likely the toolbar swapping the
                    // Done button back to the menu drops the animation transaction).
                    metrics(trendData)
                        .transition(.opacity)
                }
            }
        }
        .animation(.appQuickFade, value: metricsHidden)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(trend: trendData))
    }

    @ViewBuilder
    private func metrics(_ trendData: Trend?, drawsChart: Bool = true) -> some View {
        HStack(spacing: Spacing.element) {
            if showsTrendChart, let trend = trendData {
                if drawsChart {
                    MiniChart(trend: trend)
                        .accessibilityHidden(true)
                } else {
                    Color.clear
                        .frame(width: MiniChart.size.width, height: MiniChart.size.height)
                }
            }

            VStack(alignment: .trailing, spacing: Spacing.hairline) {
                Text(entry.rate.toStringMax4Decimals)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .font(.appTitle2)
                    .monospacedDigit()

                if let trend = trendData {
                    TrendIndicator(
                        value: historyViewModel.trendDisplayValue(rate: entry.rate, weeklyChange: trend.weeklyChange),
                        direction: trend.direction
                    )
                }
            }
            .frame(minWidth: 108, alignment: .trailing)
        }
    }

    private func accessibilityLabel(trend: Trend?) -> String {
        var parts = ["\(entry.code.rawValue), \(entry.name)"]
        guard !metricsHidden else { return parts.joined(separator: ", ") }

        parts.append("1 \(historyViewModel.baseCurrency.rawValue) equals \(entry.rate.toStringMax4Decimals) \(entry.code.rawValue)")
        if let trend {
            let value = historyViewModel.trendDisplayValue(rate: entry.rate, weeklyChange: trend.weeklyChange)
            parts.append("\(trend.direction.description) \(value)")
        }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    List {
        CurrencyRow(entry: CurrencyListEntry(code: .eur, name: "Euro", rate: 0.92))
        CurrencyRow(entry: CurrencyListEntry(code: .jpy, name: "Japanese Yen", rate: 148.31))
    }
    .listStyle(.plain)
    .withDependencyContainer(container)
}
#endif
