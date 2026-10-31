import SwiftUI

struct PairRangeSummary: View {
    let series: RateSeries

    var body: some View {
        if let highest = series.rates.max(), let lowest = series.rates.min(), let average = series.averageRate {
            VStack(alignment: .leading, spacing: 2) {
                row(.historyStatisticsHighest, value: highest)
                row(.historyStatisticsLowest, value: lowest)
                row(.historyStatisticsAverage, value: average)
            }
        }
    }

    private func row(_ label: LocalizedStringResource, value: Double) -> some View {
        HStack(spacing: Spacing.hairline) {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer(minLength: Spacing.hairline)

            Text(value.toStringMax4Decimals)
                .monospacedDigit()
        }
        .font(.appCaption)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}
