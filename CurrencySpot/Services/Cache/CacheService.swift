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
    // MARK: - Cache Storage

    private var exchangeRates: [ExchangeRate] = []

    private var historicalSeries: [HistoricalRateSnapshot] = []

    private var trends: [Trend] = []

    private let processedChartDataLimit: Int
    private var processedChartData: [String: [ChartDataPoint]] = [:]
    private var processedChartDataRecency: [String] = []

    // MARK: - Initialization

    init(processedChartDataLimit: Int = 50) {
        self.processedChartDataLimit = processedChartDataLimit
    }

    // MARK: - Exchange Rates Cache

    func cacheExchangeRates(_ rates: [ExchangeRate]) {
        exchangeRates = rates
    }

    func getCachedExchangeRates() -> [ExchangeRate]? {
        exchangeRates.isEmpty ? nil : exchangeRates
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
        self.trends = trends
    }

    func getCachedTrendData() -> [Trend]? {
        trends.isEmpty ? nil : trends
    }

    // MARK: - Processed Chart Data Cache

    func cacheProcessedChartData(_ data: [ChartDataPoint], for key: String) {
        processedChartData[key] = data
        markRecentlyUsed(key)
        while processedChartDataRecency.count > processedChartDataLimit {
            processedChartData[processedChartDataRecency.removeFirst()] = nil
        }
    }

    func getCachedProcessedChartData(for key: String) -> [ChartDataPoint]? {
        guard let data = processedChartData[key], !data.isEmpty else { return nil }
        markRecentlyUsed(key)
        return data
    }

    private func markRecentlyUsed(_ key: String) {
        processedChartDataRecency.removeAll { $0 == key }
        processedChartDataRecency.append(key)
    }

    // MARK: - Cache Management

    func clearCache() {
        exchangeRates = []
        historicalSeries = []
        trends = []
        processedChartData = [:]
        processedChartDataRecency = []
    }
}
