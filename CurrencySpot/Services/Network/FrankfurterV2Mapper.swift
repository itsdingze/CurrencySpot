//
//  FrankfurterV2Mapper.swift
//  CurrencySpot
//

import Foundation

/// Collapses Frankfurter v2's flat rate arrays back into the app's existing response shapes,
/// so nothing downstream of the API client has to know v2's format.
///
/// This is the network boundary's validation gate: every entry's currency code, rate, and
/// date are checked here, so downstream layers never see malformed values.
nonisolated enum FrankfurterV2Mapper {
    /// Maps a v2 "latest" array into the keyed `ExchangeRatesResponse` the app consumes.
    static func latest(from entries: [FrankfurterV2Rate], base: String) throws -> ExchangeRatesResponse {
        try validate(entries)
        let rates = Dictionary(entries.map { ($0.quote, $0.rate) }, uniquingKeysWith: { _, latest in latest })
        // v2 carries a per-currency date; the snapshot's date is the most recent across them.
        let date = entries.map(\.date).max() ?? ""
        return ExchangeRatesResponse(base: base, date: date, rates: rates)
    }

    /// Maps a v2 time-series array into the per-date keyed `HistoricalRatesResponse`.
    ///
    /// v2 is multi-source, so a currency can be absent on some dates. Each date's row is
    /// forward-filled with the currency's last known rate, keeping series dense and equal-length
    /// for downstream trend/chart logic (v1's ECB data was always dense). A currency is never
    /// backfilled before its first appearance.
    static func historical(from entries: [FrankfurterV2Rate], base: String) throws -> HistoricalRatesResponse {
        try validate(entries)
        var grouped: [String: [String: Double]] = [:]
        for entry in entries {
            grouped[entry.date, default: [:]][entry.quote] = entry.rate
        }

        let sortedDates = grouped.keys.sorted()
        let allCurrencies = Set(entries.map(\.quote))
        var lastKnown: [String: Double] = [:]
        var rates: [String: [String: Double]] = [:]

        for date in sortedDates {
            var row = grouped[date] ?? [:]
            for currency in allCurrencies {
                if let rate = row[currency] {
                    lastKnown[currency] = rate
                } else if let carried = lastKnown[currency] {
                    row[currency] = carried
                }
            }
            rates[date] = row
        }

        return HistoricalRatesResponse(
            base: base,
            startDate: sortedDates.first ?? "",
            endDate: sortedDates.last ?? "",
            rates: rates
        )
    }

    private static func validate(_ entries: [FrankfurterV2Rate]) throws {
        for entry in entries {
            _ = try CurrencyCode(validating: entry.quote)
            guard entry.rate.isFinite, entry.rate > 0 else {
                throw AppError.dataValidationError("Invalid rate \(entry.rate) for \(entry.quote)")
            }
            guard TimeZoneManager.parseAPIDate(entry.date) != nil else {
                throw AppError.dataValidationError("Unparseable date '\(entry.date)' for \(entry.quote)")
            }
        }
    }
}
