//
//  CacheService.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/31/25.
//

import Foundation

// MARK: - CacheService Protocol

protocol CacheService {
    /// Stores exchange rates in memory cache
    func cacheExchangeRates(_ rates: [ExchangeRateDataValue]) async

    /// Retrieves cached exchange rates
    func getCachedExchangeRates() async -> [ExchangeRateDataValue]?

    /// Stores historical data for a specific currency in memory cache
    func cacheHistoricalData(_ data: [HistoricalRateDataValue], for currency: String) async

    /// Retrieves cached historical data for a specific currency
    func getCachedHistoricalData(for currency: String) async -> [HistoricalRateDataValue]?

    /// Stores trend data in memory cache
    func cacheTrendData(_ trends: [TrendDataValue]) async

    /// Retrieves cached trend data
    func getCachedTrendData() async -> [TrendDataValue]?

    /// Stores processed chart data points for a specific currency pair and time range
    func cacheProcessedChartData(_ data: [ChartDataPoint], for key: String) async

    /// Retrieves cached processed chart data points
    func getCachedProcessedChartData(for key: String) async -> [ChartDataPoint]?

    /// Clears all cached data
    func clearCache() async
}

// MARK: - InMemoryCacheService

/// Thread-safe in-memory cache using NSCache with count limits and Swift's actor model for concurrency
actor InMemoryCacheService: CacheService {
    // MARK: - Constants

    private enum CacheConstants {
        static let exchangeRatesLimit = 1 // Only need current rates
        static let historicalDataLimit = 10 // Maximum currency pairs
        static let trendDataLimit = 1 // Only need current trends
        static let processedChartDataLimit = 50 // Cache processed chart data for currency pairs

        static let exchangeRatesKey = "exchangeRates"
        static let trendDataKey = "trendData"
    }

    // MARK: - Cache Storage

    /// Current exchange rates cache
    private let exchangeRatesCache = NSCache<NSString, NSArray>()

    /// Historical data cache organized by currency
    private let historicalDataCache = NSCache<NSString, NSArray>()

    /// Trend data cache
    private let trendDataCache = NSCache<NSString, NSArray>()

    /// Processed chart data cache for quick currency switching
    private let processedChartDataCache = NSCache<NSString, NSArray>()

    // MARK: - Initialization

    init() {
        // Configure exchange rates cache
        exchangeRatesCache.countLimit = CacheConstants.exchangeRatesLimit
        exchangeRatesCache.name = "InMemoryCacheService.ExchangeRates"

        // Configure historical data cache
        historicalDataCache.countLimit = CacheConstants.historicalDataLimit
        historicalDataCache.name = "InMemoryCacheService.HistoricalData"

        // Configure trend data cache
        trendDataCache.countLimit = CacheConstants.trendDataLimit
        trendDataCache.name = "InMemoryCacheService.TrendData"

        // Configure processed chart data cache
        processedChartDataCache.countLimit = CacheConstants.processedChartDataLimit
        processedChartDataCache.name = "InMemoryCacheService.ProcessedChartData"
    }

    // MARK: - Exchange Rates Cache

    func cacheExchangeRates(_ rates: [ExchangeRateDataValue]) {
        let cachedArray = rates as NSArray
        exchangeRatesCache.setObject(cachedArray, forKey: CacheConstants.exchangeRatesKey as NSString)
    }

    func getCachedExchangeRates() -> [ExchangeRateDataValue]? {
        guard let cachedArray = exchangeRatesCache.object(forKey: CacheConstants.exchangeRatesKey as NSString),
              let rates = cachedArray as? [ExchangeRateDataValue]
        else {
            return nil
        }
        return rates.isEmpty ? nil : rates
    }

    // MARK: - Historical Data Cache

    func cacheHistoricalData(_ data: [HistoricalRateDataValue], for currency: String) {
        // IMPORTANT: The data passed here is already merged, deduplicated, and sorted by DataOrchestrationUseCase

        // Simply cache the already-processed data directly
        let cachedArray = data as NSArray
        historicalDataCache.setObject(cachedArray, forKey: currency as NSString)
    }

    func getCachedHistoricalData(for currency: String) -> [HistoricalRateDataValue]? {
        guard let cachedArray = historicalDataCache.object(forKey: currency as NSString),
              let data = cachedArray as? [HistoricalRateDataValue]
        else {
            return nil
        }
        return data
    }

    // MARK: - Trend Data Cache

    func cacheTrendData(_ trends: [TrendDataValue]) {
        let cachedArray = trends as NSArray
        trendDataCache.setObject(cachedArray, forKey: CacheConstants.trendDataKey as NSString)
    }

    func getCachedTrendData() -> [TrendDataValue]? {
        guard let cachedArray = trendDataCache.object(forKey: CacheConstants.trendDataKey as NSString),
              let trends = cachedArray as? [TrendDataValue]
        else {
            return nil
        }
        return trends.isEmpty ? nil : trends
    }

    // MARK: - Processed Chart Data Cache

    func cacheProcessedChartData(_ data: [ChartDataPoint], for key: String) {
        let cachedArray = data as NSArray
        processedChartDataCache.setObject(cachedArray, forKey: key as NSString)
    }

    func getCachedProcessedChartData(for key: String) -> [ChartDataPoint]? {
        guard let cachedArray = processedChartDataCache.object(forKey: key as NSString),
              let data = cachedArray as? [ChartDataPoint]
        else {
            return nil
        }
        return data.isEmpty ? nil : data
    }

    // MARK: - Cache Management

    func clearCache() {
        exchangeRatesCache.removeAllObjects()
        historicalDataCache.removeAllObjects()
        trendDataCache.removeAllObjects()
        processedChartDataCache.removeAllObjects()
    }
}
