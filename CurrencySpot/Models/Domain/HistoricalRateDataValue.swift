//
//  HistoricalRateDataValue.swift
//  CurrencySpot
//

import Foundation

/// One currency's USD-normalized rate on a historical date.
struct HistoricalRateDataPointValue: Identifiable, Equatable, Sendable {
    let currencyCode: CurrencyCode
    let rate: Double

    var id: CurrencyCode { currencyCode }
}

/// All recorded rates for a single historical date.
/// Identity is the date: collections of these are merged/deduplicated by date upstream.
struct HistoricalRateDataValue: Identifiable, Equatable, Sendable {
    let date: Date
    let rates: [HistoricalRateDataPointValue]

    var id: Date { date }

    init(dateString: String, rates: [HistoricalRateDataPointValue]) throws {
        guard let date = TimeZoneManager.parseAPIDate(dateString) else {
            throw AppError.dataValidationError("Invalid date string: \(dateString)")
        }
        self.date = date
        self.rates = rates
    }

    init(date: Date, rates: [HistoricalRateDataPointValue]) {
        self.date = date
        self.rates = rates
    }
}
