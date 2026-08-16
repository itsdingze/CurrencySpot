import Foundation

struct ChartStatistics: Sendable {
    let currentRate: Double
    let highestRate: Double
    let lowestRate: Double
    let averageRate: Double
    let priceChange: Double?
    let percentChange: Double?
    let volatility: Double?
    let trendDirection: TrendDirection
    let chartYDomain: ClosedRange<Double>
}
