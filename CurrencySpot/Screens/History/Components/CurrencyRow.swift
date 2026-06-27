//
//  CurrencyRow.swift
//  CurrencySpot
//

import SwiftUI

/// One currency in the History list: code/name, mini trend chart, and rate.
struct CurrencyRow: View {
    let entry: CurrencyListEntry

    /// Search rows drop the 7-day sparkline to stay compact; the watchlist keeps it.
    var showsTrendChart = true

    /// Hides the trailing metrics (edit mode). The row keeps its height via the
    /// zero-width copy below.
    var metricsHidden = false

    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel

    var body: some View {
        let trendData = historyViewModel.getTrendData(for: entry.code)

        HStack(spacing: .elementGap) {
            VStack(alignment: .leading, spacing: .hairlineGap) {
                Text(entry.code)
                    .font(.appTitle2)

                Text(entry.name)
                    .lineLimit(1)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            ZStack(alignment: .trailing) {
                // Zero-width invisible copy: holds the row at full height so removing
                // the real metrics doesn't shrink it — without reserving any width,
                // so the code/name get the freed space instead of being squeezed.
                metrics(trendData)
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
    private func metrics(_ trendData: Trend?) -> some View {
        HStack(spacing: .elementGap) {
            if showsTrendChart, let trend = trendData {
                MiniChart(trend: trend)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .trailing, spacing: .hairlineGap) {
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
        var parts = ["\(entry.code), \(entry.name)"]
        guard !metricsHidden else { return parts.joined(separator: ", ") }

        parts.append("1 \(historyViewModel.baseCurrency) equals \(entry.rate.toStringMax4Decimals) \(entry.code)")
        if let trend {
            let value = historyViewModel.trendDisplayValue(rate: entry.rate, weeklyChange: trend.weeklyChange)
            parts.append("\(trend.direction.description) \(value)")
        }
        return parts.joined(separator: ", ")
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    List {
        CurrencyRow(entry: CurrencyListEntry(code: "EUR", name: "Euro", rate: 0.92))
        CurrencyRow(entry: CurrencyListEntry(code: "JPY", name: "Japanese Yen", rate: 148.31))
    }
    .listStyle(.plain)
    .withDependencyContainer(container)
}
#endif
