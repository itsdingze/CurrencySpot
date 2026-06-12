//
//  HistoricalRateRepository.swift
//  CurrencySpot
//

import Foundation

/// Historical rates aggregate: range fetch/load, stored-coverage queries, and the
/// per-currency in-memory cache that backs chart gap detection.
protocol HistoricalRateRepository {
    /// Fetches a date range from the network and saves it to persistent storage.
    func fetchAndSaveHistoricalRates(from startDate: Date, to endDate: Date) async throws

    /// Loads stored historical rates for a currency within a range,
    /// with a network fallback when persistence fails.
    func loadHistoricalRates(for currency: CurrencyCode, in range: DateRange) async throws -> [HistoricalRateSnapshot]

    /// Bounds of the persisted historical data; nil when nothing is stored.
    func earliestStoredDate() async throws -> Date?
    func latestStoredDate() async throws -> Date?

    /// The in-memory historical cache for a currency (merged, deduplicated, date-sorted).
    func cachedHistoricalRates(for currency: CurrencyCode) async -> [HistoricalRateSnapshot]

    /// Replaces the in-memory historical cache for a currency.
    func replaceCachedHistoricalRates(_ data: [HistoricalRateSnapshot], for currency: CurrencyCode) async
}
