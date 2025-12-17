//
//  ValueTypeModels.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 6/24/25.
//

import Foundation

struct ExchangeRateDataValue: Identifiable, Equatable {
    let id = UUID()
    let currencyCode: String
    let rate: Double

    static func == (lhs: ExchangeRateDataValue, rhs: ExchangeRateDataValue) -> Bool {
        lhs.currencyCode == rhs.currencyCode && lhs.rate == rhs.rate
    }
}

struct HistoricalRateDataPointValue: Identifiable, Equatable {
    let id = UUID()
    let currencyCode: String
    let rate: Double

    static func == (lhs: HistoricalRateDataPointValue, rhs: HistoricalRateDataPointValue) -> Bool {
        lhs.currencyCode == rhs.currencyCode && lhs.rate == rhs.rate
    }
}

struct HistoricalRateDataValue: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let rates: [HistoricalRateDataPointValue]

    static func == (lhs: HistoricalRateDataValue, rhs: HistoricalRateDataValue) -> Bool {
        lhs.date == rhs.date && lhs.rates == rhs.rates
    }

    // Convenience initializer for API date strings
    init(dateString: String, rates: [HistoricalRateDataPointValue]) throws {
        guard let date = TimeZoneManager.parseAPIDate(dateString) else {
            throw AppError.dataValidationError("Invalid date string: \(dateString)")
        }
        self.date = date
        self.rates = rates
    }

    // Standard initializer
    init(date: Date, rates: [HistoricalRateDataPointValue]) {
        self.date = date
        self.rates = rates
    }
}

struct TrendDataValue: Identifiable, Equatable {
    let id = UUID()
    let currencyCode: String
    let weeklyChange: Double // % change over 7 days
    let miniChartData: [Double] // Last 7 days rates for sparkline

    // Computed direction based on weeklyChange
    var direction: TrendDirection {
        if abs(weeklyChange) <= TrendDirection.stableChangeThreshold {
            .stable
        } else if weeklyChange > 0 {
            .up
        } else {
            .down
        }
    }

    static func == (lhs: TrendDataValue, rhs: TrendDataValue) -> Bool {
        lhs.currencyCode == rhs.currencyCode &&
            lhs.weeklyChange == rhs.weeklyChange &&
            lhs.miniChartData == rhs.miniChartData
    }
}
