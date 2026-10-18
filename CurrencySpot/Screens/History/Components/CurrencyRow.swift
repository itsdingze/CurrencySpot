import SwiftUI

struct CurrencyRow: View {
    let entry: CurrencyListEntry

    var showsTrendChart = true

    var metricsHidden = false

    @Environment(CurrencyListViewModel.self) private var viewModel

    var body: some View {
        let trend = viewModel.trend(for: entry.code)

        HStack(spacing: Spacing.element) {
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                Text(entry.code.rawValue)
                    .font(.appTitle2)

                Text(entry.name)
                    .lineLimit(1)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            ZStack(alignment: .trailing) {
                metrics(trend, drawsChart: false)
                    .frame(width: 0)
                    .clipped()
                    .hidden()
                    .accessibilityHidden(true)

                if !metricsHidden {
                    metrics(trend)
                        .transition(.opacity)
                }
            }
        }
        .animation(.appQuickFade, value: metricsHidden)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(trend: trend))
    }

    @ViewBuilder
    private func metrics(_ trend: Trend?, drawsChart: Bool = true) -> some View {
        HStack(spacing: Spacing.element) {
            if showsTrendChart, let trend {
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

                if let trend {
                    TrendIndicator(
                        value: viewModel.trendDisplayValue(rate: entry.rate, weeklyChange: trend.weeklyChange),
                        direction: trend.direction
                    )
                }
            }
            .frame(minWidth: 108, alignment: .trailing)
        }
    }

    private func accessibilityLabel(trend: Trend?) -> LocalizedStringResource {
        let code = entry.code.rawValue
        guard !metricsHidden else {
            return .historyRowAccessibilityLabel(code: code, name: entry.name)
        }

        let base = viewModel.baseCurrency.rawValue
        let rate = entry.rate.toStringMax4Decimals
        guard let trend else {
            return .historyRowAccessibilityLabelRate(code: code, name: entry.name, base: base, rate: rate, target: code)
        }

        let change = viewModel.trendDisplayValue(rate: entry.rate, weeklyChange: trend.weeklyChange)
        switch trend.direction {
        case .up:
            return .historyRowAccessibilityLabelUp(code: code, name: entry.name, base: base, rate: rate, target: code, change: change)
        case .down:
            return .historyRowAccessibilityLabelDown(code: code, name: entry.name, base: base, rate: rate, target: code, change: change)
        case .stable:
            return .historyRowAccessibilityLabelStable(code: code, name: entry.name, base: base, rate: rate, target: code, change: change)
        }
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
