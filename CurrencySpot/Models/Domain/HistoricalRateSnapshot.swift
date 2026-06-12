//
//  HistoricalRateSnapshot.swift
//  CurrencySpot
//

import Foundation

/// One currency's USD-normalized rate on a historical date.
nonisolated struct HistoricalRatePoint: Identifiable, Equatable, Sendable {
    let currencyCode: CurrencyCode
    let rate: Double

    var id: CurrencyCode { currencyCode }
}

/// All recorded rates for a single historical date.
/// Identity is the date: collections of these are merged/deduplicated by date upstream.
nonisolated struct HistoricalRateSnapshot: Identifiable, Equatable, Sendable {
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

nonisolated extension HistoricalRateSnapshot {
    /// Merges two series by date — rows in `new` replace same-day rows in `existing` —
    /// returning a date-sorted result. Lives on the domain type so both the analysis
    /// use case and the cache actor share one implementation.
    static func merge(existing: [HistoricalRateSnapshot], new: [HistoricalRateSnapshot]) -> [HistoricalRateSnapshot] {
        var byDate: [String: HistoricalRateSnapshot] = [:]
        for item in existing {
            byDate[TimeZoneManager.formatForAPI(item.date)] = item
        }
        for item in new {
            byDate[TimeZoneManager.formatForAPI(item.date)] = item
        }
        return byDate.values.sorted { $0.date < $1.date }
    }
}
