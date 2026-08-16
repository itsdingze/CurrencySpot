import Foundation

// MARK: - CacheService Protocol

nonisolated protocol CacheService: Sendable {
    func cacheExchangeRates(_ rates: [ExchangeRate]) async

    func getCachedExchangeRates() async -> [ExchangeRate]?

    func cacheHistoricalData(_ data: [HistoricalRateSnapshot]) async

    func mergeHistoricalData(_ new: [HistoricalRateSnapshot]) async -> [HistoricalRateSnapshot]

    func getCachedHistoricalData() async -> [HistoricalRateSnapshot]?

    func cacheTrendData(_ trends: [Trend]) async

    func getCachedTrendData() async -> [Trend]?

    func cacheProcessedChartData(_ data: [ChartDataPoint], for key: String) async

    func getCachedProcessedChartData(for key: String) async -> [ChartDataPoint]?

    func clearCache() async
}

// MARK: - InMemoryCacheService

actor InMemoryCacheService: CacheService {
    // MARK: - Constants

    private enum CacheConstants {
        static let exchangeRatesLimit = 1
        static let trendDataLimit = 1
        static let processedChartDataLimit = 50

        static let exchangeRatesKey = "exchangeRates"
        static let trendDataKey = "trendData"
    }

    // MARK: - Cache Storage

    private let exchangeRatesCache = NSCache<NSString, NSArray>()

    private var historicalSeries: [HistoricalRateSnapshot] = []

    private let trendDataCache = NSCache<NSString, NSArray>()

    private let processedChartDataCache = NSCache<NSString, NSArray>()

    // MARK: - Initialization

    init() {
        exchangeRatesCache.countLimit = CacheConstants.exchangeRatesLimit
        exchangeRatesCache.name = "InMemoryCacheService.ExchangeRates"

        trendDataCache.countLimit = CacheConstants.trendDataLimit
        trendDataCache.name = "InMemoryCacheService.TrendData"

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

    func cacheHistoricalData(_ data: [HistoricalRateSnapshot]) {
        historicalSeries = data
    }

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
