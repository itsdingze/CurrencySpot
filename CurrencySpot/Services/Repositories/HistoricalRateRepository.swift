//
//  HistoricalRateRepository.swift
//  CurrencySpot
//

import Foundation

/// Historical rates aggregate: range fetch/load, stored-coverage queries, and the
/// shared in-memory series that backs chart gap detection.
protocol HistoricalRateRepository {
    /// Fetches a date range from the network and returns the decoded snapshots immediately.
    /// Persistence happens behind the returned data, and the coverage watermark is recorded
    /// only after that save commits. Readers that need the rows on disk must sequence
    /// behind `waitForPendingHistoricalWrites()`.
    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot]

    /// Suspends until every scheduled background historical save has settled.
    func waitForPendingHistoricalWrites() async

    /// One-off pair-scoped archive fetch returning decoded snapshots only — never
    /// persisted, never recorded, never cached. Bridges archive-range views while the
    /// all-currency backfill hasn't landed; pair-scoped rows must stay out of the
    /// all-currency store or they would masquerade as full coverage.
    func fetchTransientHistoricalRates(for currencies: [CurrencyCode], from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot]

    /// Fetches a range straight into the deferred persist without materializing
    /// domain snapshots — the archive backfill's path, where decoded rows would
    /// only be discarded (and must never reach the resident series).
    func fetchAndPersistHistoricalRates(from startDate: Date, to endDate: Date) async throws

    /// Loads ALL stored historical rates within a range, with a network fallback when
    /// persistence fails. Deliberately currency-agnostic: results feed the shared
    /// series, and a per-currency-filtered date set would poison it for every other
    /// currency.
    func loadHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot]

    /// Bounds of the persisted historical data; nil when nothing is stored.
    func earliestStoredDate() async throws -> Date?
    func latestStoredDate() async throws -> Date?

    /// The shared in-memory historical series (merged, deduplicated, date-sorted).
    /// Every snapshot carries all currencies, so one series serves every chart.
    func cachedHistoricalRates() async -> [HistoricalRateSnapshot]

    /// Merges new rows into the shared series by date, atomically, and returns the
    /// merged result. Concurrent loads union instead of overwriting each other.
    func mergeCachedHistoricalRates(_ new: [HistoricalRateSnapshot]) async -> [HistoricalRateSnapshot]
}
