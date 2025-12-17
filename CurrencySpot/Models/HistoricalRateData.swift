//
//  HistoricalRateData.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import Foundation
import SwiftData

@Model
final class HistoricalRateDataPoint {
    var currencyCode: String
    var rate: Double
    var historicalData: HistoricalRateData?

    init(currencyCode: String, rate: Double) {
        self.currencyCode = currencyCode
        self.rate = rate
    }
}

@Model
final class HistoricalRateData {
    @Attribute(.unique) var date: Date
    @Relationship(deleteRule: .cascade, inverse: \HistoricalRateDataPoint.historicalData)
    var rates: [HistoricalRateDataPoint] = []

    init(date: Date, rates: [HistoricalRateDataPoint]) {
        self.date = date
        self.rates = rates
    }

    // Convenience initializer for API date strings
    convenience init(dateString: String, rates: [HistoricalRateDataPoint]) throws {
        guard let date = TimeZoneManager.parseAPIDate(dateString) else {
            throw AppError.dataValidationError("Invalid date string: \(dateString)")
        }
        self.init(date: date, rates: rates)
    }
}
