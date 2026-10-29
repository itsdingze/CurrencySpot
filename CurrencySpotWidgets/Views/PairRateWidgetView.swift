import SwiftUI
import WidgetKit

struct PairRateWidgetView: View {
    let entry: RateSeriesEntry

    @Environment(\.widgetFamily) private var family

    private let textDescentInset: CGFloat = 3
    private let summaryMinWidth: CGFloat = 112

    private var series: RateSeries? { entry.rows.first }

    var body: some View {
        Group {
            if family == .systemMedium {
                mediumLayout
            } else {
                smallLayout
            }
        }
        .accessibilityElement(children: .combine)
        .widgetURL(series.map { HistoryLink(base: entry.request.base, target: $0.currency).url })
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                header
                rateSummary
            }
            .layoutPriority(1)

            if let series, let direction = series.direction {
                RateSparkline(
                    rates: series.rates,
                    direction: direction,
                    showsEndpoint: true,
                    floorRoom: 0,
                    ceilingRoom: 0
                )
                .frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }
        }
        .widgetContentPadding()
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            header

            HStack(alignment: .top, spacing: Spacing.section) {
                ViewThatFits(in: .vertical) {
                    summaryColumn(showsRange: true)
                    summaryColumn(showsRange: false)
                }

                if let series, let direction = series.direction {
                    RateSparkline(
                        rates: series.rates,
                        direction: direction,
                        showsEndpoint: true,
                        referenceRate: series.averageRate,
                        floorRoom: 0,
                        ceilingRoom: 0.12
                    )
                    .padding(.bottom, textDescentInset)
                } else {
                    Spacer(minLength: 0)
                }
            }
        }
        .widgetContentPadding()
    }

    private func summaryColumn(showsRange: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            rateSummary
            Spacer(minLength: Spacing.tight)
            if showsRange, let series {
                PairRangeSummary(series: series)
            }
        }
        .frame(minWidth: summaryMinWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var header: some View {
        WidgetHeader(base: entry.request.base, target: series?.currency)
    }

    private var rateSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            Text(series?.rateText ?? String(localized: .widgetRateUnavailable))
                .font(.appTitle2)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let series, let changeText = series.changeText, let direction = series.direction {
                TrendChange(value: changeText, direction: direction)
                    .widgetAccentable()
            }
        }
    }
}

#Preview(as: .systemSmall) {
    PairRateWidget()
} timeline: {
    SampleRateSeries.entry(for: RateSeriesRequest(base: .usd, currencies: [.eur], period: .oneMonth))
    SampleRateSeries.entry(for: RateSeriesRequest(base: .usd, currencies: [.jpy], period: .oneYear))
    RateSeriesEntry(date: .now, request: RateSeriesRequest(base: .usd, currencies: [.eur], period: .oneMonth), snapshot: nil)
}

#Preview(as: .systemMedium) {
    PairRateWidget()
} timeline: {
    SampleRateSeries.entry(for: RateSeriesRequest(base: .usd, currencies: [.eur], period: .threeMonths))
}
