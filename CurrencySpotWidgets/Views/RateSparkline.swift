import Charts
import SwiftUI
import WidgetKit

struct RateSparkline: View {
    let rates: [Double]
    let direction: TrendDirection
    var referenceRate: Double?
    var fillsHeight = false

    private let lineWidth: CGFloat = 1.5
    private let endpointSize: CGFloat = 6
    private let innerPointSize: CGFloat = 4
    private let tension: Double = 0.8
    private let domainPadding: Double = 0.01
    private let minimumSpanRatio: Double = 0.004

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

            if let last = rates.last {
                PointMark(x: .value(.historyChartPlotDay, rates.count - 1), y: .value(.rateChartAxisRate, last))
                    .symbol {
                        ZStack {
                            Circle()
                                .fill(.background)
                                .frame(width: endpointSize, height: endpointSize)

                            Circle()
                                .fill(direction.color)
                                .frame(width: innerPointSize, height: innerPointSize)
                        }
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: yDomain)
        .widgetAccentable()
        .chartAccessibilityHidden()
    }

    private var yDomain: ClosedRange<Double> {
        guard let low = rates.min(), let high = rates.max() else { return 0 ... 1 }
        guard fillsHeight else {
            return (low * (1 - domainPadding)) ... (high * (1 + domainPadding))
        }

        let span = max(high - low, (high + low) / 2 * minimumSpanRatio)
        let flatPadding = (span - (high - low)) / 2
        return (low - flatPadding) ... (high + flatPadding)
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [direction.color.opacity(0.1), direction.color.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: Spacing.section) {
        RateSparkline(rates: [0.851, 0.853, 0.852, 0.855, 0.857, 0.858, 0.861], direction: .up)
            .frame(width: 170, height: 52)
        RateSparkline(rates: [153.7, 153.4, 153.1, 152.8, 152.6, 152.37], direction: .down)
            .frame(width: 60, height: 26)
    }
    .padding()
}
