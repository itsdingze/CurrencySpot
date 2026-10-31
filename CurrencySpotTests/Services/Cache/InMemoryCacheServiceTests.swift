@testable import CurrencySpot
import Foundation
import Testing

@Suite("InMemoryCacheService Tests")
struct InMemoryCacheServiceTests {
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

        #expect(await cache.getCachedExchangeRates() == nil)
        #expect(await cache.getCachedTrendData() == nil)
    }
}
