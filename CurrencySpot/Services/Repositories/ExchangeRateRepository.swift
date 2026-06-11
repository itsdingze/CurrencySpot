//
//  ExchangeRateRepository.swift
//  CurrencySpot
//

import Foundation

/// Current exchange rates aggregate: fetch/load plus freshness bookkeeping.
/// Speaks domain types only — DTOs never cross this surface.
protocol ExchangeRateRepository {
    /// True when current rates are stale enough to warrant a network refetch.
    func shouldRefreshRates() async -> Bool

    /// Fetches fresh rates from the network. Persisting, caching, and stamping the
    /// last-fetch date happen inside the repository (single owner of post-fetch
    /// bookkeeping). Falls back to cached/persisted rates when the network fails.
    func fetchExchangeRates() async throws -> [ExchangeRateDataValue]

    /// Cache-first load of current rates, with the network as a last resort.
    func loadExchangeRates() async throws -> [ExchangeRateDataValue]

    /// Timestamp of the most recent successful fetch.
    func lastFetchDate() -> Date?
}
