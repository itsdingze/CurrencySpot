//
//  ExchangeRateService.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/28/25.
//

import Foundation

// MARK: - Service Protocols

// The individual service protocols are defined in their respective files:
// - NetworkService (NetworkService.swift)
// - PersistenceService (PersistenceService.swift)
// - CacheService (CacheService.swift)

// MARK: - ExchangeRateService Protocol

/// Unified interface for exchange rate data operations.
/// This protocol represents the public interface for all currency data operations in the app.
protocol ExchangeRateService {
    // MARK: - Rate Fetching Check Methods

    /// Returns `true` if new exchange rates should be fetched from the API.
    func shouldFetchNewRates() async -> Bool

    // MARK: - Network Data Fetching Methods

    /// Fetches exchange rates from the network and coordinates storage.
    func fetchExchangeRates() async throws -> ExchangeRatesResponse

    /// Fetches historical rates for a specific date range and coordinates storage.
    func fetchAndSaveHistoricalRates(from startDate: Date, to endDate: Date) async throws

    // MARK: - Data Persistence Methods

    /// Saves exchange rates to persistent storage.
    func saveExchangeRates(_ rates: [String: Double]) async throws

    /// Saves historical exchange rates to persistent storage.
    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws

    // MARK: - Data Loading Methods

    /// Loads exchange rates with cache-first strategy.
    func loadExchangeRates() async throws -> [ExchangeRateDataValue]

    /// Loads historical rates with cache-first strategy.
    func loadHistoricalRatesForCurrency(
        currency: String,
        startDate: String,
        endDate: String
    ) async throws -> [HistoricalRateDataValue]

    // MARK: - Date Management Methods

    /// Updates the date we last fetched data.
    func updateLastFetchDate(_ date: Date)

    /// Gets the last date we fetched data.
    func getLastFetchDate() -> Date?

    /// Gets the earliest stored date in historical data.
    func getEarliestStoredDate() async throws -> Date?

    /// Gets the latest stored date in historical data.
    func getLatestStoredDate() async throws -> Date?

    // MARK: - Trend Data Methods

    /// Loads trend data with cache-first strategy.
    func loadTrendData() async throws -> [TrendDataValue]

    /// Calculates and saves trend data based on historical rates.
    func calculateAndSaveTrendData() async throws

    /// Checks if sufficient historical data exists for trend calculation (last 7 days).
    func hasSufficientHistoricalDataForTrends() async throws -> Bool

    /// Checks if the provided date range contains data that would affect trend calculation (within last 7 days).
    func doesDateRangeAffectTrends(startDate: Date, endDate: Date) async throws -> Bool

    // MARK: - Data Management Methods

    /// Clears all cached and persistent data.
    func clearAllData() async throws
}
