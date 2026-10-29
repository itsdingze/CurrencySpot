import SwiftUI
import WidgetKit

struct RateListWidgetView: View {
    let entry: RateSeriesEntry

    @Environment(\.widgetFamily) private var family

    private let separatorGap: CGFloat = 5

    private struct Arrangement: Hashable {
        let showsHeader: Bool
        let rowCount: Int
    }

    private var arrangementsByPreference: [Arrangement] {
        let rowCounts = Array((0...entry.rows.count).reversed())
        let withHeader = rowCounts.map { Arrangement(showsHeader: true, rowCount: $0) }
        guard family == .systemMedium, let fullList = withHeader.first else { return withHeader }
        return [fullList] + rowCounts.map { Arrangement(showsHeader: false, rowCount: $0) }
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(arrangementsByPreference, id: \.self) { arrangement in
                list(arrangement)
            }
        }
        .widgetContentPadding()
    }

    private func list(_ arrangement: Arrangement) -> some View {
        let count = arrangement.rowCount
        let fillsHeight = count < entry.rows.count || entry.rows.count >= RateListLayout.rowLimit(for: family)

        return VStack(spacing: 0) {
            if arrangement.showsHeader {
                WidgetHeader(base: entry.request.base)
                headerGap(fillsHeight: fillsHeight)
            }

            ForEach(Array(entry.rows.prefix(count).enumerated()), id: \.element.currency) { index, series in
                if index > 0 {
                    separator(showsDivider: true, fillsHeight: fillsHeight)
                }

                Link(destination: HistoryLink(base: entry.request.base, target: series.currency).url) {
                    RateListRow(series: series)
                }
            }

            if !fillsHeight {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func headerGap(fillsHeight: Bool) -> some View {
        if family == .systemLarge {
            separator(showsDivider: false, fillsHeight: fillsHeight)
        } else {
            gap(fillsHeight: fillsHeight)
        }
    }

    @ViewBuilder
    private func separator(showsDivider: Bool, fillsHeight: Bool) -> some View {
        gap(fillsHeight: fillsHeight)
        if showsDivider {
            Divider()
        }
        gap(fillsHeight: fillsHeight)
    }

    @ViewBuilder
    private func gap(fillsHeight: Bool) -> some View {
        if fillsHeight {
            Spacer(minLength: separatorGap)
        } else {
            Color.clear.frame(height: separatorGap)
        }
    }
}

#Preview(as: .systemMedium) {
    RateListWidget()
} timeline: {
    SampleRateSeries.entry(for: RateSeriesRequest(base: .usd, currencies: [.eur, .gbp], period: .oneMonth))
}

#Preview(as: .systemLarge) {
    RateListWidget()
} timeline: {
    SampleRateSeries.entry(for: RateSeriesRequest(base: .usd, currencies: [.eur, .jpy, .gbp, .cny, .inr, .chf, .aud], period: .oneMonth))
}
