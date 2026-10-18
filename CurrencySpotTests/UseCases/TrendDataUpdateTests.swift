@testable import CurrencySpot
import Foundation
import Testing

@Suite("Trend Data Update Tests")
struct TrendDataUpdateTests {
    private let graph: HistoryTestGraph

    init() throws {
        graph = try HistoryTestGraph()
    }

    private func makeHistoricalData(for currency: CurrencyCode, days: Int) -> [HistoricalRateSnapshot] {
        let calendar = CETCalendar.calendar
        return (0 ..< days).reversed().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: graph.today) else { return nil }
            let baseRate = currency == "EUR" ? 0.92 : (currency == "GBP" ? 0.79 : 1.5)
            let rate = baseRate + Double(dayOffset) * 0.001
            return HistoricalRateSnapshot(
                date: date,
                rates: [HistoricalRatePoint(currencyCode: currency, rate: rate)]
            )
        }
    }

    private func range(daysBeforeToday days: Int) throws -> DateRange {
        let start = try #require(CETCalendar.calendar.date(byAdding: .day, value: -days, to: graph.today))
        return DateRange.spanning(start, graph.today)
    }

    // MARK: - LoadHistoricalRatesUseCase

    @Test("a cold load reports fetched ranges that stay within the requested range")
    func coldLoadReportsFetchedRanges() async throws {
        let requestedRange = try range(daysBeforeToday: 90)

        let result = try await graph.loadHistoricalRates.loadHistoricalData(for: "EUR", base: "USD", dateRange: requestedRange)

        #expect(result.newDataFetched == true)
        let fetched = try #require(result.fetchedRanges.first)
        #expect(fetched.start >= requestedRange.start)
        #expect(fetched.end <= requestedRange.end)
    }

    @Test("a range inside an already loaded one is served without fetching")
    func coveredRangeServedWithoutFetching() async throws {
        _ = try await graph.loadHistoricalRates.loadHistoricalData(for: "EUR", base: "USD", dateRange: try range(daysBeforeToday: 20))

        let result = try await graph.loadHistoricalRates.loadHistoricalData(for: "EUR", base: "USD", dateRange: try range(daysBeforeToday: 7))

        #expect(result.newDataFetched == false)
        #expect(result.fetchedRanges.isEmpty)
    }

    // MARK: - Trend Recalculation

    @Test("trends recalculate when a fetched range affects the trend window")
    func trendRecalculatesWhenRangeAffectsTrends() async throws {
        let existing = [Trend(currencyCode: "EUR", weeklyChange: 1.0, miniChartData: [1.0, 1.1])]
        let trendRepository = MockTrendRepository(trends: existing)
        let historicalRepository = MockHistoricalRateRepository()
        historicalRepository.storedRows = makeHistoricalData(for: "EUR", days: 7)
        let useCase = try HistoryTestGraph(
            historicalRepository: historicalRepository,
            trendRepository: trendRepository
        ).trendDataUseCase

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: [try range(daysBeforeToday: 2)])

        #expect(trendRepository.saveTrendDataCallCount == 1)
        #expect(result != existing)
        #expect(result.contains { $0.currencyCode == "EUR" })
    }

    @Test("trends are not recalculated when no range affects the trend window")
    func trendDoesNotRecalculateForUnaffectingRange() async throws {
        let existing = [Trend(currencyCode: "EUR", weeklyChange: 1.0, miniChartData: [1.0, 1.1])]
        let trendRepository = MockTrendRepository(trends: existing)
        let useCase = try HistoryTestGraph(trendRepository: trendRepository).trendDataUseCase
        let unaffectingRange = DateRange.spanning(
            try #require(createCETDate(year: 2024, month: 10, day: 1)),
            try #require(createCETDate(year: 2024, month: 10, day: 7))
        )

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: [unaffectingRange])

        #expect(trendRepository.saveTrendDataCallCount == 0)
        #expect(result == existing)
    }

    // MARK: - Base Currency Conversion (exact values from the fixture)

    @Test("EUR-base GBP trend is GBP/EUR per point with the derived weekly change", .timeLimit(.minutes(1)))
    func trendConversionNonUSDBase() async throws {
        let viewModel = graph.makeListViewModel()
        await viewModel.warmUp().value
        graph.ratesStore.updateBaseCurrency("EUR")

        let trend = try #require(viewModel.trend(for: "GBP"))

        let expected = [0.76 / 0.85, 0.755 / 0.855, 0.753 / 0.857, 0.751 / 0.858, 0.749 / 0.859, 0.748 / 0.860, 0.75 / 0.86]
        #expect(trend.miniChartData.count == expected.count)
        for (actual, want) in zip(trend.miniChartData, expected) {
            #expect(abs(actual - want) < 0.0001)
        }
        let first = try #require(expected.first)
        let last = try #require(expected.last)
        #expect(abs(trend.weeklyChange - (last - first) / first * 100) < 0.001)
    }

    @Test("EUR-base USD trend is the inverted EUR fixture with the derived weekly change", .timeLimit(.minutes(1)))
    func trendConversionUSDInversion() async throws {
        let viewModel = graph.makeListViewModel()
        await viewModel.warmUp().value
        graph.ratesStore.updateBaseCurrency("EUR")

        let usd = try #require(viewModel.trend(for: "USD"))

        let eurFixture = [0.85, 0.855, 0.857, 0.858, 0.859, 0.860, 0.86]
        let expected = eurFixture.map { 1.0 / $0 }
        #expect(usd.miniChartData.count == expected.count)
        for (actual, want) in zip(usd.miniChartData, expected) {
            #expect(abs(actual - want) < 0.0001)
        }
        let first = try #require(expected.first)
        let last = try #require(expected.last)
        #expect(abs(usd.weeklyChange - (last - first) / first * 100) < 0.001)
    }
}
