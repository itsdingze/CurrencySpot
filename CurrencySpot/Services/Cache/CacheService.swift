//
//  CacheService.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/31/25.
//

import Foundation

// MARK: - CacheService Protocol

/// `nonisolated` keeps the protocol out of MainActor default isolation so the
/// actor conformer can satisfy it; `Sendable` lets MainActor callers hand the
/// existential to nonisolated async work.
nonisolated protocol CacheService: Sendable {
    /// Stores exchange rates in memory cache
    func cacheExchangeRates(_ rates: [ExchangeRate]) async

    /// Retrieves cached exchange rates
    func getCachedExchangeRates() async -> [ExchangeRate]?

    /// Stores the shared historical series (every snapshot carries all currencies)
    func cacheHistoricalData(_ data: [HistoricalRateSnapshot]) async

    /// Merges new rows into the shared historical series by date and returns the
    /// result. Atomic inside the cache: concurrent writers union instead of
    /// last-writer-wins clobbering each other's rows.
    func mergeHistoricalData(_ new: [HistoricalRateSnapshot]) async -> [HistoricalRateSnapshot]

    /// Retrieves the shared historical series
    func getCachedHistoricalData() async -> [HistoricalRateSnapshot]?

    /// Stores trend data in memory cache
    func cacheTrendData(_ trends: [Trend]) async

    /// Retrieves cached trend data
    func getCachedTrendData() async -> [Trend]?

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
        static let trendDataLimit = 1 // Only need current trends
        static let processedChartDataLimit = 50 // Cache processed chart data for currency pairs

        static let exchangeRatesKey = "exchangeRates"
        static let trendDataKey = "trendData"
    }

    // MARK: - Cache Storage

    /// Current exchange rates cache
    private let exchangeRatesCache = NSCache<NSString, NSArray>()

    /// The shared all-currency historical series. A stored property, NOT an NSCache:
    /// this series is the render source for every chart, and NSCache silently evicts
    /// under the very memory spikes the launch warm-up produces — observed as the
    /// freshly prefetched year vanishing before the first chart open. A few MB held
    /// deliberately beats an unpredictable re-read from SwiftData.
    private var historicalSeries: [HistoricalRateSnapshot] = []

    /// Trend data cache
    private let trendDataCache = NSCache<NSString, NSArray>()

    /// Processed chart data cache for quick currency switching
    private let processedChartDataCache = NSCache<NSString, NSArray>()

    // MARK: - Initialization

    init() {
        // Configure exchange rates cache
        exchangeRatesCache.countLimit = CacheConstants.exchangeRatesLimit
        exchangeRatesCache.name = "InMemoryCacheService.ExchangeRates"

        // Configure trend data cache
        trendDataCache.countLimit = CacheConstants.trendDataLimit
        trendDataCache.name = "InMemoryCacheService.TrendData"

        // Configure processed chart data cache
        processedChartDataCache.countLimit = CacheConstants.processedChartDataLimit
        processedChartDataCache.name = "InMemoryCacheService.ProcessedChartData"
    }

    // MARK: - Exchange Rates Cache

    func cacheExchangeRates(_ rates: [ExchangeRate]) {
        let cachedArray = rates as NSArray
        exchangeRatesCache.setObject(cachedArray, forKey: CacheConstants.exchangeRatesKey as NSString)
    }

    func getCachedExchangeRates() -> [ExchangeRate]? {
        guard let cachedArray = exchangeRatesCache.object(forKey: CacheConstants.exchangeRatesKey as NSString),
              let rates = cachedArray as? [ExchangeRate]
        else {
            return nil
        }
        return rates.isEmpty ? nil : rates
    }

    // MARK: - Historical Data Cache

    /// One shared series for every currency: each snapshot already carries all ~160
    /// currencies' rates, so per-currency entries would only duplicate the same rows.
    func cacheHistoricalData(_ data: [HistoricalRateSnapshot]) {
        // IMPORTANT: The data passed here is already merged, deduplicated, and sorted by DataOrchestrationUseCase
        historicalSeries = data
    }

    /// Synchronous on the actor: no suspension between the read and the write, which
    /// is what makes concurrent merges union rather than overwrite.
    func mergeHistoricalData(_ new: [HistoricalRateSnapshot]) -> [HistoricalRateSnapshot] {
        historicalSeries = HistoricalRateSnapshot.merge(existing: historicalSeries, new: new)
        return historicalSeries
    }

    func getCachedHistoricalData() -> [HistoricalRateSnapshot]? {
        historicalSeries.isEmpty ? nil : historicalSeries
    }

    // MARK: - Trend Data Cache

    func cacheTrendData(_ trends: [Trend]) {
        let cachedArray = trends as NSArray
        trendDataCache.setObject(cachedArray, forKey: CacheConstants.trendDataKey as NSString)
    }

    func getCachedTrendData() -> [Trend]? {
        guard let cachedArray = trendDataCache.object(forKey: CacheConstants.trendDataKey as NSString),
              let trends = cachedArray as? [Trend]
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
        historicalSeries = []
        trendDataCache.removeAllObjects()
        processedChartDataCache.removeAllObjects()
    }
}
