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
    /// bookkeeping). Throws on network failure — the caller decides whether to fall
    /// back to saved rates, so a failed fetch is never relabeled as a fresh one.
    func fetchExchangeRates() async throws -> [ExchangeRate]

    /// Cache-first load of current rates, with the network as a last resort.
    func loadExchangeRates() async throws -> [ExchangeRate]

    /// Timestamp of the most recent successful fetch.
    func lastFetchDate() -> Date?
}
