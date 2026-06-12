//
//  DataCoordinator.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/24/25.
//

import Foundation
import SwiftData

// MARK: - DataCoordinator

/// Orchestrates data operations across the network, persistence, and cache layers,
/// implementing the aggregate repository protocols the rest of the app depends on.
/// This is the single owner of post-fetch bookkeeping (persist, cache, stamp) and the
/// only layer that sees network DTOs; everything above it speaks domain types.
final class DataCoordinator {
    // MARK: - Dependencies

    private let networkService: NetworkService
    private let persistenceService: PersistenceService
    private let cacheService: CacheService
    private let syncStore: HistoricalSyncStore
    private let dateProvider: DateProvider
    private let logger: LoggerService

    // MARK: - Initialization

    /// - Parameter syncStore: Historical coverage window, reset alongside a full data clear so the
    ///   watermark never outlives the data it describes.
    init(
        networkService: NetworkService,
        persistenceService: PersistenceService,
        cacheService: CacheService,
        syncStore: HistoricalSyncStore = UserDefaultsHistoricalSyncStore(),
        dateProvider: DateProvider = SystemDateProvider(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.networkService = networkService
        self.persistenceService = persistenceService
        self.cacheService = cacheService
        self.syncStore = syncStore
        self.dateProvider = dateProvider
        self.logger = logger
    }

    // MARK: - DTO -> Domain Mapping

    /// Codes were validated at the network boundary (FrankfurterV2Mapper); this is a
    /// mechanical re-key into domain values.
    private static func domainRates(from rates: [String: Double]) -> [ExchangeRate] {
        rates.compactMap { code, rate in
            CurrencyCode(code).map { ExchangeRate(currencyCode: $0, rate: rate) }
        }
    }
}

// MARK: - ExchangeRateRepository

extension DataCoordinator: ExchangeRateRepository {
    func shouldRefreshRates() async -> Bool {
        await networkService.shouldFetchNewRates()
    }

    func lastFetchDate() -> Date? {
        networkService.getLastFetchDate()
    }

    /// Fetches the latest rates and coordinates storage across layers.
    func fetchExchangeRates() async throws -> [ExchangeRate] {
        do {
            let response = try await networkService.fetchExchangeRates()

            var updatedRates = response.rates
            updatedRates[response.base] = 1.0
            let domainRates = Self.domainRates(from: updatedRates)

            // Store in cache and persistence concurrently with error handling
            async let cacheOperation: Void = cacheService.cacheExchangeRates(domainRates)
            async let persistOperation: Void = persistenceService.saveExchangeRates(updatedRates)

            // Attempt to store but don't fail if storage fails
            do {
                _ = try await (cacheOperation, persistOperation)
            } catch {
                logger.warning("Failed to store fetched rates: \(error.localizedDescription)", category: .data)
            }

            networkService.updateLastFetchDate(dateProvider.now())
            return domainRates
        } catch {
            // Network failed, try fallback to cached/persisted data
            logger.error("Network fetch failed: \(error.localizedDescription), attempting fallback", category: .network)

            if let cachedRates = await loadFallbackRates() {
                // The fetch date was previously stamped even for this synthetic success
                // (by the ViewModel); the stamp stays to preserve user-visible freshness.
                networkService.updateLastFetchDate(dateProvider.now())
                return cachedRates
            }

            // If all fallbacks fail, throw the original error
            throw error
        }
    }

    /// Loads exchange rates with cache-first strategy and a network last resort.
    /// Throws when no real data can be obtained; presentation decides any mock fallback.
    func loadExchangeRates() async throws -> [ExchangeRate] {
        // Check cache first for fast response
        if let cachedRates = await cacheService.getCachedExchangeRates(), !cachedRates.isEmpty {
            return cachedRates
        }

        // Try to load from persistence
        do {
            let persistedRates = try await persistenceService.loadExchangeRates()
            if !persistedRates.isEmpty {
                await cacheService.cacheExchangeRates(persistedRates)
                return persistedRates
            }
        } catch {
            logger.warning("Failed to load from persistence: \(error.localizedDescription)", category: .persistence)
        }

        // No local data: try the network as a last resort. This is gated on actually
        // being unable to load locally, not on the freshness TTL.
        do {
            return try await fetchExchangeRates()
        } catch {
            logger.warning("Network fetch also failed: \(error.localizedDescription)", category: .network)
            throw error
        }
    }

    /// Helper method to load fallback rates from cache or persistence
    private func loadFallbackRates() async -> [ExchangeRate]? {
        // Try cache first
        if let cachedRates = await cacheService.getCachedExchangeRates(), !cachedRates.isEmpty {
            logger.info("Using cached rates as fallback", category: .cache)
            return cachedRates
        }

        // Try persistence
        do {
            let persistedRates = try await persistenceService.loadExchangeRates()
            if !persistedRates.isEmpty {
                logger.info("Using persisted rates as fallback", category: .persistence)
                // Update cache with persisted data
                await cacheService.cacheExchangeRates(persistedRates)
                return persistedRates
            }
        } catch {
            logger.warning("Failed to load persisted rates: \(error.localizedDescription)", category: .persistence)
        }

        return nil
    }
}

// MARK: - HistoricalRateRepository

extension DataCoordinator: HistoricalRateRepository {
    /// Fetches historical rates for a specific date range and coordinates storage.
    func fetchAndSaveHistoricalRates(from startDate: Date, to endDate: Date) async throws {
        let historicalResponse = try await networkService.fetchHistoricalRates(
            from: startDate,
            to: endDate
        )

        // Save to persistence layer
        try await persistenceService.saveHistoricalExchangeRates(historicalResponse.rates)

        // Update the last fetch date
        networkService.updateLastFetchDate(dateProvider.now())
    }

    /// Loads historical rates from persistence (the source of truth), with a network fallback on error.
    ///
    /// This deliberately does NOT read the in-memory cache: the historical cache is owned by
    /// `DataOrchestrationUseCase`, which reads it for gap detection and writes the merged result.
    /// Reading it here would shadow data just written by a fresh fetch (a successful 3-month fetch
    /// would still read back only the older, narrower cached window).
    func loadHistoricalRates(for currency: CurrencyCode, in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        do {
            return try await persistenceService.loadHistoricalRates(
                currency: currency.rawValue,
                from: range.start,
                to: range.end
            )
        } catch {
            logger.warning("Failed to load historical data from persistence: \(error.localizedDescription)", category: .persistence)

            // Try to fetch from network if connected
            if await networkService.shouldFetchNewRates() {
                do {
                    try await fetchAndSaveHistoricalRates(from: range.start, to: range.end)

                    // Try loading again after fetch
                    return try await persistenceService.loadHistoricalRates(
                        currency: currency.rawValue,
                        from: range.start,
                        to: range.end
                    )
                } catch {
                    logger.warning("Network fetch for historical data also failed: \(error.localizedDescription)", category: .network)
                }
            }

            // Return empty array as final fallback
            return []
        }
    }

    func earliestStoredDate() async throws -> Date? {
        try await persistenceService.getEarliestStoredDate()
    }

    func latestStoredDate() async throws -> Date? {
        try await persistenceService.getLatestStoredDate()
    }

    func cachedHistoricalRates(for currency: CurrencyCode) async -> [HistoricalRateSnapshot] {
        await cacheService.getCachedHistoricalData(for: currency.rawValue) ?? []
    }

    func replaceCachedHistoricalRates(_ data: [HistoricalRateSnapshot], for currency: CurrencyCode) async {
        await cacheService.cacheHistoricalData(data, for: currency.rawValue)
    }
}

// MARK: - TrendRepository

extension DataCoordinator: TrendRepository {
    func loadTrendData() async throws -> [Trend] {
        // Check cache first for fast response
        if let cachedTrends = await cacheService.getCachedTrendData() {
            return cachedTrends
        }

        // Load from persistence and update cache
        let persistedTrends = try await persistenceService.loadTrendData()
        await cacheService.cacheTrendData(persistedTrends)

        return persistedTrends
    }

    func saveTrendData(_ trends: [Trend]) async throws {
        try await persistenceService.saveTrendData(trends)
        await cacheService.cacheTrendData(trends)
    }

    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        try await persistenceService.loadHistoricalRates(from: startDate, to: endDate)
    }
}

// MARK: - DataClearing

extension DataCoordinator: DataClearing {
    func clearAllData() async throws {
        // Clear from persistence layer
        try await persistenceService.clearAllData()

        // Clear cache
        await cacheService.clearCache()

        // Clear last fetch date
        networkService.updateLastFetchDate(Date.distantPast)

        // Drop the historical coverage window, or it would claim coverage over the now-empty
        // store and leave charts blank with no refetch (same hazard the v2 migration guards against).
        syncStore.reset()
    }
}
