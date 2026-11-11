import SwiftUI
import WidgetKit

struct RateListRow: View {
    let series: RateSeries

    @Environment(\.widgetFamily) private var family
    @Environment(\.locale) private var locale

    private let metricsMinWidth: CGFloat = 72

    private var isRoomy: Bool { family == .systemMedium }
    private var chartSize: CGSize { isRoomy ? CGSize(width: 72, height: 34) : CGSize(width: 56, height: 28) }
    private var primaryFont: Font { isRoomy ? .appHeadline : .appSubheadline.weight(.semibold) }
    private var secondaryFont: Font { isRoomy ? .appFootnote : .appCaption }

    var body: some View {
        HStack(spacing: Spacing.element) {
            VStack(alignment: .leading, spacing: 0) {
                Text(series.currency.rawValue)
                    .font(primaryFont)

                Text(series.currency.localizedName(in: locale))
                    .font(secondaryFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let direction = series.direction {
                RateSparkline(rates: series.rates, direction: direction)
                    .frame(width: chartSize.width, height: chartSize.height)
            }

            VStack(alignment: .trailing, spacing: 1) {
                Text(series.rateText(in: locale))
                    .font(primaryFont)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let changeText = series.changeText(in: locale), let direction = series.direction {
                    TrendIndicator(value: changeText, direction: direction)
                        .font(.appCaption2.weight(.semibold))
                        .imageScale(.small)
                        .widgetAccentable()
                }
            }
            .frame(minWidth: metricsMinWidth, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
