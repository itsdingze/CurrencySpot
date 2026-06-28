//
//  ChartStatistics.swift
//  CurrencySpot
//

import Foundation

/// Statistics calculated from a chart's data points.
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
