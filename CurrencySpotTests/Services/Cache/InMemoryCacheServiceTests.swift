@testable import CurrencySpot
import Foundation
import Testing

@Suite("InMemoryCacheService Tests")
struct InMemoryCacheServiceTests {
    private let points = [ChartDataPoint(date: Date(timeIntervalSince1970: 0), rate: 1.2)]

    @Test("processed chart data evicts the least recently used series once over the limit")
    func chartDataEvictsLeastRecentlyUsed() async {
        let cache = InMemoryCacheService(processedChartDataLimit: 2)
        await cache.cacheProcessedChartData(points, for: "a")
        await cache.cacheProcessedChartData(points, for: "b")
        _ = await cache.getCachedProcessedChartData(for: "a")

        await cache.cacheProcessedChartData(points, for: "c")

        #expect(await cache.getCachedProcessedChartData(for: "a") == points)
        #expect(await cache.getCachedProcessedChartData(for: "b") == nil)
        #expect(await cache.getCachedProcessedChartData(for: "c") == points)
    }

    @Test("exchange rates and trends round-trip and clear")
    func ratesAndTrendsRoundTripAndClear() async {
        let cache = InMemoryCacheService()
        let rates = [ExchangeRate(currencyCode: "EUR", rate: 0.9)]
        let trends = [Trend(currencyCode: "EUR", weeklyChange: 0.4, miniChartData: [0.9, 0.91])]

        await cache.cacheExchangeRates(rates)
        await cache.cacheTrendData(trends)
        #expect(await cache.getCachedExchangeRates() == rates)
        #expect(await cache.getCachedTrendData() == trends)

        await cache.clearCache()
        #expect(await cache.getCachedExchangeRates() == nil)
        #expect(await cache.getCachedTrendData() == nil)
    }

    @Test("an empty cached collection reads back as a miss")
    func emptyCollectionsAreMisses() async {
        let cache = InMemoryCacheService()

        await cache.cacheExchangeRates([])
        await cache.cacheTrendData([])
        await cache.cacheProcessedChartData([], for: "a")

        #expect(await cache.getCachedExchangeRates() == nil)
        #expect(await cache.getCachedTrendData() == nil)
        #expect(await cache.getCachedProcessedChartData(for: "a") == nil)
    }
}
