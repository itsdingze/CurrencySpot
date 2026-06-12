//
//  HistoricalRateSnapshot.swift
//  CurrencySpot
//

import Foundation

/// One currency's USD-normalized rate on a historical date.
struct HistoricalRatePoint: Identifiable, Equatable, Sendable {
    let currencyCode: CurrencyCode
    let rate: Double

    var id: CurrencyCode { currencyCode }
}

/// All recorded rates for a single historical date.
/// Identity is the date: collections of these are merged/deduplicated by date upstream.
struct HistoricalRateSnapshot: Identifiable, Equatable, Sendable {
    let date: Date
    let rates: [HistoricalRatePoint]

    var id: Date { date }

    init(dateString: String, rates: [HistoricalRatePoint]) throws {
        guard let date = TimeZoneManager.parseAPIDate(dateString) else {
            throw AppError.dataValidationError("Invalid date string: \(dateString)")
        }
        self.date = date
        self.rates = rates
    }

    init(date: Date, rates: [HistoricalRatePoint]) {
        self.date = date
        self.rates = rates
    }
}
