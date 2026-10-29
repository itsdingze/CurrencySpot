import Charts
import SwiftUI
import WidgetKit

struct RateSparkline: View {
    let rates: [Double]
    let direction: TrendDirection
    var showsEndpoint = false
    var referenceRate: Double?
    var floorRoom = 0.1
    var ceilingRoom = 0.1

    private let lineWidth: CGFloat = 1.75
    private let endpointSize: CGFloat = 7
    private let tension: Double = 0.8

    var body: some View {
        Chart {
            if let referenceRate {
                RuleMark(y: .value(.rateChartAxisRate, referenceRate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            ForEach(Array(rates.enumerated()), id: \.offset) { day, rate in
                LineMark(x: .value(.historyChartPlotDay, day), y: .value(.rateChartAxisRate, rate))
                    .interpolationMethod(.cardinal(tension: tension))
                    .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(direction.color)

                AreaMark(
                    x: .value(.historyChartPlotDay, day),
                    yStart: .value(.rateChartAxisRate, rate),
                    yEnd: .value(.rateChartAxisRate, yDomain.lowerBound)
                )
                .interpolationMethod(.cardinal(tension: tension))
                .foregroundStyle(areaGradient)
            }

            if showsEndpoint, let last = rates.last {
                PointMark(x: .value(.historyChartPlotDay, rates.count - 1), y: .value(.rateChartAxisRate, last))
                    .symbol {
                        Circle()
                            .fill(direction.color)
                            .stroke(.background, lineWidth: 1.5)
                            .frame(width: endpointSize, height: endpointSize)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: yDomain)
        .widgetAccentable()
        .accessibilityHidden(true)
    }

    private var yDomain: ClosedRange<Double> {
        guard let low = rates.min(), let high = rates.max() else { return 0 ... 1 }
        let span = max(high - low, (high + low) / 2 * 0.004)
        let flatPadding = (span - (high - low)) / 2
        return (low - flatPadding - span * floorRoom) ... (high + flatPadding + span * ceilingRoom)
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [direction.color.opacity(0.18), direction.color.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: Spacing.section) {
        RateSparkline(rates: [0.851, 0.853, 0.852, 0.855, 0.857, 0.858, 0.861], direction: .up, showsEndpoint: true)
            .frame(width: 170, height: 52)
        RateSparkline(rates: [153.7, 153.4, 153.1, 152.8, 152.6, 152.37], direction: .down)
            .frame(width: 60, height: 26)
    }
    .padding()
}
