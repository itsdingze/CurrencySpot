//
//  FrankfurterV2Mapper.swift
//  CurrencySpot
//

import Foundation

/// A single rate entry from the Frankfurter v2 API.
/// v2 returns a flat array of these (one per currency), unlike v1's keyed `rates` object.
struct FrankfurterV2Rate: Codable, Sendable {
    let date: String
    let base: String
    let quote: String
    let rate: Double
}

/// Collapses Frankfurter v2's flat rate arrays back into the app's existing response shapes,
/// so nothing downstream of the API client has to know v2's format.
enum FrankfurterV2Mapper {
    /// Maps a v2 "latest" array into the keyed `ExchangeRatesResponse` the app consumes.
    static func latest(from entries: [FrankfurterV2Rate], base: String) -> ExchangeRatesResponse {
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
    static func historical(from entries: [FrankfurterV2Rate], base: String) -> HistoricalRatesResponse {
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
            start_date: sortedDates.first ?? "",
            end_date: sortedDates.last ?? "",
            rates: rates
        )
    }
}
