//
//  TrendDataValue.swift
//  CurrencySpot
//

import Foundation

/// A currency's weekly trend: percentage change plus the sparkline series behind it.
struct TrendDataValue: Identifiable, Equatable, Sendable {
    let currencyCode: CurrencyCode
    let weeklyChange: Double
    let miniChartData: [Double]

    var id: CurrencyCode { currencyCode }

    var direction: TrendDirection {
        TrendDirection(percentChange: weeklyChange)
    }
}
