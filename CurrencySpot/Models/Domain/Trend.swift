import Foundation

nonisolated struct Trend: Identifiable, Equatable, Sendable {
    let currencyCode: CurrencyCode
    let weeklyChange: Double
    let miniChartData: [Double]

    var id: CurrencyCode { currencyCode }

    var direction: TrendDirection {
        TrendDirection(percentChange: weeklyChange)
    }
}
