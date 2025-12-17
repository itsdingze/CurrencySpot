//
//  DataCoordinator.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/24/25.
//

import Foundation
import SwiftData

// MARK: - DataCoordinator

/// A data coordinator responsible for orchestrating data operations across network, persistence, and cache layers.
/// This class coordinates between NetworkService, PersistenceService, and CacheService to provide
/// a unified interface for all currency data operations in the app.
final class DataCoordinator: ExchangeRateService {
    // MARK: - Dependencies

    private let networkService: NetworkService
    private let persistenceService: PersistenceService
    private let cacheService: CacheService

    // MARK: - Initialization

    init(
        networkService: NetworkService,
        persistenceService: PersistenceService,
        cacheService: CacheService
    ) {
        self.networkService = networkService
        self.persistenceService = persistenceService
        self.cacheService = cacheService
    }

    // MARK: - Rate Fetching Check Methods

    /// Determines whether new exchange rates should be fetched from the API.
    func shouldFetchNewRates() async -> Bool {
        await networkService.shouldFetchNewRates()
    }

    // MARK: - Network Data Fetching Methods

    /// Fetches the latest exchange rates from the API and coordinates storage across layers.
    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        do {
            let response = try await networkService.fetchExchangeRates()

            // Prepare the rates data
            var updatedRates = response.rates
            updatedRates[response.base] = 1.0

            // Convert to value types for caching
            let valueTypeRates = updatedRates.map {
                ExchangeRateDataValue(currencyCode: $0.key, rate: $0.value)
            }

            // Create a local copy for the async operation to avoid capturing issues
            let ratesToPersist = updatedRates

            // Store in cache and persistence concurrently with error handling
            async let cacheOperation: Void = cacheService.cacheExchangeRates(valueTypeRates)
            async let persistOperation: Void = persistenceService.saveExchangeRates(ratesToPersist)

            // Attempt to store but don't fail if storage fails
            do {
                _ = try await (cacheOperation, persistOperation)
            } catch {
                // Log storage error but continue since we have the data
                AppLogger.warning("Failed to store fetched rates: \(error.localizedDescription)", category: .data)
            }

            return response
        } catch {
            // Network failed, try fallback to cached/persisted data
            AppLogger.error("Network fetch failed: \(error.localizedDescription), attempting fallback", category: .network)

            // Try to load from cache or persistence
            if let cachedRates = await loadFallbackRates() {
                // Create a synthetic response from cached data
                return ExchangeRatesResponse(
                    base: "USD",
                    date: TimeZoneManager.formatForAPI(Date()),
                    rates: Dictionary(uniqueKeysWithValues: cachedRates.map { ($0.currencyCode, $0.rate) })
                )
            }

            // If all fallbacks fail, throw the original error
            throw error
        }
    }

    /// Helper method to load fallback rates from cache or persistence
    private func loadFallbackRates() async -> [ExchangeRateDataValue]? {
        // Try cache first
        if let cachedRates = await cacheService.getCachedExchangeRates(), !cachedRates.isEmpty {
            AppLogger.info("Using cached rates as fallback", category: .cache)
            return cachedRates
        }

        // Try persistence
        do {
            let persistedRates = try await persistenceService.loadExchangeRates()
            if !persistedRates.isEmpty {
                AppLogger.info("Using persisted rates as fallback", category: .persistence)
                // Update cache with persisted data
                await cacheService.cacheExchangeRates(persistedRates)
                return persistedRates
            }
        } catch {
            AppLogger.warning("Failed to load persisted rates: \(error.localizedDescription)", category: .persistence)
        }

        return nil
    }

    /// Fetches historical rates for a specific date range and coordinates storage.
    func fetchAndSaveHistoricalRates(from startDate: Date, to endDate: Date) async throws {
        let historicalResponse = try await networkService.fetchHistoricalRates(
            from: startDate,
            to: endDate
        )

        // Save to persistence layer
        try await persistenceService.saveHistoricalExchangeRates(historicalResponse.rates)

        // Update the last fetch date
        networkService.updateLastFetchDate(Date())
    }

    // MARK: - Data Persistence Methods

    /// Saves exchange rates by delegating to persistence service.
    func saveExchangeRates(_ rates: [String: Double]) async throws {
        try await persistenceService.saveExchangeRates(rates)
    }

    /// Saves historical exchange rates by delegating to persistence service.
    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws {
        try await persistenceService.saveHistoricalExchangeRates(rates)
    }

    // MARK: - Data Loading Methods

    /// Loads exchange rates with cache-first strategy and multiple fallback layers.
    func loadExchangeRates() async throws -> [ExchangeRateDataValue] {
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
            AppLogger.warning("Failed to load from persistence: \(error.localizedDescription)", category: .persistence)
        }

        // If no data available, try to fetch from network as last resort
        if await networkService.shouldFetchNewRates() {
            do {
                let response = try await fetchExchangeRates()
                var rates = response.rates
                rates[response.base] = 1.0
                return rates.map { ExchangeRateDataValue(currencyCode: $0.key, rate: $0.value) }
            } catch {
                AppLogger.warning("Network fetch also failed: \(error.localizedDescription)", category: .network)
            }
        }

        // If all else fails, return mock data as ultimate fallback
        AppLogger.warning("All data sources failed, returning mock data", category: .data)
        return MockExchangeRates.rates.map {
            ExchangeRateDataValue(currencyCode: $0.key, rate: $0.value)
        }
    }

    /// Loads historical rates with cache-first strategy and error recovery.
    func loadHistoricalRatesForCurrency(
        currency: String,
        startDate: String,
        endDate: String
    ) async throws -> [HistoricalRateDataValue] {
        // Check cache first
        if let cachedData = await cacheService.getCachedHistoricalData(for: currency) {
            // Filter cached data for the requested date range
            guard let parsedStartDate = TimeZoneManager.parseAPIDate(startDate),
                  let parsedEndDate = TimeZoneManager.parseAPIDate(endDate)
            else {
                // Date parsing error - return empty array instead of throwing
                AppLogger.warning("Failed to parse dates, returning empty data", category: .data)
                return []
            }

            let filteredData = cachedData.filter { data in
                data.date >= parsedStartDate && data.date <= parsedEndDate
            }

            // Return cached data if we have complete coverage
            if !filteredData.isEmpty {
                return filteredData
            }
        }

        // Try to load from persistence layer
        do {
            let persistedHistoricalRates = try await persistenceService.loadHistoricalRatesForCurrency(
                currency: currency,
                startDate: startDate,
                endDate: endDate
            )

            // Update cache with fresh data if we got any
            if !persistedHistoricalRates.isEmpty {
                await cacheService.cacheHistoricalData(persistedHistoricalRates, for: currency)
            }

            return persistedHistoricalRates
        } catch {
            AppLogger.warning("Failed to load historical data from persistence: \(error.localizedDescription)", category: .persistence)

            // Try to fetch from network if connected
            if await networkService.shouldFetchNewRates() {
                do {
                    guard let parsedStartDate = TimeZoneManager.parseAPIDate(startDate),
                          let parsedEndDate = TimeZoneManager.parseAPIDate(endDate)
                    else {
                        return []
                    }

                    try await fetchAndSaveHistoricalRates(from: parsedStartDate, to: parsedEndDate)

                    // Try loading again after fetch
                    return try await persistenceService.loadHistoricalRatesForCurrency(
                        currency: currency,
                        startDate: startDate,
                        endDate: endDate
                    )
                } catch {
                    AppLogger.warning("Network fetch for historical data also failed: \(error.localizedDescription)", category: .network)
                }
            }

            // Return empty array as final fallback
            return []
        }
    }

    // MARK: - Date Management Methods

    func updateLastFetchDate(_ date: Date) {
        networkService.updateLastFetchDate(date)
    }

    func getLastFetchDate() -> Date? {
        networkService.getLastFetchDate()
    }

    func getEarliestStoredDate() async throws -> Date? {
        try await persistenceService.getEarliestStoredDate()
    }

    func getLatestStoredDate() async throws -> Date? {
        try await persistenceService.getLatestStoredDate()
    }

    // MARK: - Trend Data Methods

    func loadTrendData() async throws -> [TrendDataValue] {
        // Check cache first for fast response
        if let cachedTrends = await cacheService.getCachedTrendData() {
            return cachedTrends
        }

        // Load from persistence and update cache
        let persistedTrends = try await persistenceService.loadTrendData()
        await cacheService.cacheTrendData(persistedTrends)

        return persistedTrends
    }

    func calculateAndSaveTrendData() async throws {
        // Calculate new trends in persistence layer
        try await persistenceService.calculateAndSaveTrendData()

        // Reload and cache the updated trends
        let updatedTrends = try await persistenceService.loadTrendData()
        await cacheService.cacheTrendData(updatedTrends)
    }

    func hasSufficientHistoricalDataForTrends() async throws -> Bool {
        try await persistenceService.hasSufficientHistoricalDataForTrends()
    }

    func doesDateRangeAffectTrends(startDate: Date, endDate: Date) async throws -> Bool {
        try await persistenceService.doesDateRangeAffectTrends(startDate: startDate, endDate: endDate)
    }

    // MARK: - Data Management Methods

    func clearAllData() async throws {
        // Clear from persistence layer
        try await persistenceService.clearAllData()

        // Clear cache
        await cacheService.clearCache()

        // Clear last fetch date
        networkService.updateLastFetchDate(Date.distantPast)
    }
}
