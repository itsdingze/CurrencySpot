import Charts
import SwiftUI

struct RateAreaLineMarks<LineStyle: ShapeStyle>: ChartContent {
    let date: Date
    let rate: Double
    let lowestRate: Double
    let areaColor: Color
    let lineStyle: LineStyle

    var body: some ChartContent {
        AreaMark(
            x: .value(.rateChartAxisDate, date, unit: .day),
            yStart: .value(.rateChartAxisRate, rate),
            yEnd: .value(.rateChartAxisRate, lowestRate * 0.99)
        )
        .interpolationMethod(.cardinal(tension: 0.8))
        .foregroundStyle(
            .linearGradient(
                colors: [areaColor.opacity(0.15), areaColor.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )

        LineMark(
            x: .value(.rateChartAxisDate, date, unit: .day),
            y: .value(.rateChartAxisRate, rate)
        )
        .interpolationMethod(.cardinal(tension: 0.8))
        .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .foregroundStyle(lineStyle)
    }
}
