//
//  TrendDataUpdateTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 12/9/25.
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("Trend Data Update Tests")
struct TrendDataUpdateTests {
    // MARK: - Test Data Setup

    /// Fixed anchor (Wednesday, midnight CET) so fixtures never depend on the wall clock.
    private static let fixedToday = createCETDate(year: 2025, month: 1, day: 15)!

    /// Deterministic historical data (no randomness) covering `days` ending on the fixed anchor.
    private func makeHistoricalData(for currency: CurrencyCode, days: Int, endingOn today: Date = fixedToday) -> [HistoricalRateDataValue] {
        let calendar = TimeZoneManager.cetCalendar
        return (0 ..< days).reversed().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
            let baseRate = currency == "EUR" ? 0.92 : (currency == "GBP" ? 0.79 : 1.5)
            // Gentle deterministic drift so points differ without random noise.
            let rate = baseRate + Double(dayOffset) * 0.001
            return HistoricalRateDataValue(
                date: date,
                rates: [HistoricalRateDataPointValue(currencyCode: currency, rate: rate)]
            )
        }
    }

    // MARK: - DataOrchestrationUseCase Tests

    @Test("DataOrchestrationUseCase reports fetched ranges within the requested range on a cold cache")
    func dataOrchestrationReturnsFetchedRanges() async throws {
        let mockService = MockExchangeRateService(today: Self.fixedToday)
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            repository: mockService,
            historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase(
                syncStore: MockHistoricalSyncStore(),
                dateProvider: FixedDateProvider(Self.fixedToday)
            ),
            dateProvider: FixedDateProvider(Self.fixedToday)
        )

        let calendar = TimeZoneManager.cetCalendar
        let endDate = Self.fixedToday
        let startDate = try #require(calendar.date(byAdding: .month, value: -3, to: endDate))
        let requestedRange = DateRange(start: startDate, end: endDate)

        let result = try await dataOrchestrationUseCase.loadHistoricalData(for: "EUR", dateRange: requestedRange)

        #expect(result.newDataFetched == true)
        #expect(result.fetchedRanges.isEmpty == false)
        let fetched = try #require(result.fetchedRanges.first)
        #expect(fetched.start >= requestedRange.start)
        #expect(fetched.end <= requestedRange.end)
    }

    @Test("DataOrchestrationUseCase serves from cache without fetching when the range is covered")
    func dataOrchestrationReturnsEmptyFetchedRangesFromCache() async throws {
        let mockService = MockExchangeRateService(today: Self.fixedToday)
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            repository: mockService,
            historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase(
                syncStore: MockHistoricalSyncStore(),
                dateProvider: FixedDateProvider(Self.fixedToday)
            ),
            dateProvider: FixedDateProvider(Self.fixedToday)
        )

        await mockService.replaceCachedHistoricalRates(makeHistoricalData(for: "EUR", days: 90), for: "EUR")

        let calendar = TimeZoneManager.cetCalendar
        let endDate = Self.fixedToday
        let startDate = try #require(calendar.date(byAdding: .day, value: -7, to: endDate))
        let requestedRange = DateRange(start: startDate, end: endDate)

        let result = try await dataOrchestrationUseCase.loadHistoricalData(for: "EUR", dateRange: requestedRange)

        #expect(result.newDataFetched == false)
        #expect(result.fetchedRanges.isEmpty)
    }

    // MARK: - Trend Recalculation Tests

    @Test("Trends recalculate when a fetched range affects the trend window")
    func trendRecalculatesWhenRangeAffectsTrends() async {
        let existing = [TrendDataValue(currencyCode: "EUR", weeklyChange: 1.0, miniChartData: [1.0, 1.1])]
        let trendRepository = MockTrendRepository(trends: existing)
        trendRepository.historicalWindowData = makeHistoricalData(for: "EUR", days: 7)
        let useCase = TrendDataUseCase(
            trendRepository: trendRepository,
            historicalRateRepository: MockHistoricalRateRepository(),
            dateProvider: FixedDateProvider(Self.fixedToday)
        )

        // A range ending on "today" overlaps the 7-day trend window.
        let affectingRange = DateRange(
            start: TimeZoneManager.cetCalendar.date(byAdding: .day, value: -2, to: Self.fixedToday)!,
            end: Self.fixedToday
        )

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: [affectingRange])

        #expect(trendRepository.saveTrendDataCallCount == 1)
        // The recalculated set derives from the historical window fixture, not the stale stored set.
        #expect(result != existing)
        #expect(result.contains { $0.currencyCode == "EUR" })
    }

    @Test("Trends are NOT recalculated when no range affects the trend window")
    func trendDoesNotRecalculateForUnaffectingRange() async {
        let existing = [TrendDataValue(currencyCode: "EUR", weeklyChange: 1.0, miniChartData: [1.0, 1.1])]
        let trendRepository = MockTrendRepository(trends: existing)
        let useCase = TrendDataUseCase(
            trendRepository: trendRepository,
            historicalRateRepository: MockHistoricalRateRepository(),
            dateProvider: FixedDateProvider(Self.fixedToday)
        )

        // A range months before the trend window.
        let unaffectingRange = DateRange(
            start: createCETDate(year: 2024, month: 10, day: 1)!,
            end: createCETDate(year: 2024, month: 10, day: 7)!
        )

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: [unaffectingRange])

        #expect(trendRepository.saveTrendDataCallCount == 0)
        #expect(result == existing)
    }

    // MARK: - Base Currency Conversion Tests (exact values from the fixture)

    @Test("EUR-base GBP trend is GBP/EUR per point with the derived weekly change")
    @MainActor
    func trendConversionNonUSDBase() async {
        let viewModel = Self.makeFixtureBackedViewModel()
        await viewModel.initializeTrendData()
        viewModel.baseCurrency = "EUR"

        guard let trend = viewModel.getTrendData(for: "GBP") else {
            Issue.record("Expected a GBP trend when base is EUR")
            return
        }

        // GBP fixture / EUR fixture, element-wise.
        let expected = [0.76 / 0.85, 0.755 / 0.855, 0.753 / 0.857, 0.751 / 0.858, 0.749 / 0.859, 0.748 / 0.860, 0.75 / 0.86]
        #expect(trend.miniChartData.count == expected.count)
        for (actual, want) in zip(trend.miniChartData, expected) {
            #expect(abs(actual - want) < 0.0001)
        }
        // ((last - first) / first) * 100
        let expectedChange = ((expected.last! - expected.first!) / expected.first!) * 100
        #expect(abs(trend.weeklyChange - expectedChange) < 0.001)
    }

    @Test("EUR-base USD trend is the inverted EUR fixture with the derived weekly change")
    @MainActor
    func trendConversionUSDInversion() async {
        let viewModel = Self.makeFixtureBackedViewModel()
        await viewModel.initializeTrendData()
        viewModel.baseCurrency = "EUR"

        let usd = viewModel.getTrendData(for: "USD")
        guard let usd else {
            Issue.record("Expected a USD trend when base is EUR")
            return
        }

        // 1 / EUR fixture, element-wise.
        let eurFixture = [0.85, 0.855, 0.857, 0.858, 0.859, 0.860, 0.86]
        let expected = eurFixture.map { 1.0 / $0 }
        #expect(usd.miniChartData.count == expected.count)
        for (actual, want) in zip(usd.miniChartData, expected) {
            #expect(abs(actual - want) < 0.0001)
        }
        let expectedChange = ((expected.last! - expected.first!) / expected.first!) * 100
        #expect(abs(usd.weeklyChange - expectedChange) < 0.001)
    }

    // MARK: - Integration

    @Test("Loading new data triggers a trend recalculation that populates trend data")
    @MainActor
    func loadTriggersTrendRecalculation() async {
        let viewModel = Self.makeFixtureBackedViewModel()
        #expect(viewModel.trendData.isEmpty) // nothing loaded yet

        await viewModel.loadCurrentConfigurationAndWait()

        // The cold-cache load fetches new data, which affects the trend window and recalculates,
        // yielding the full fixture trend set (deterministic, no sleep).
        #expect(viewModel.trendData.count == MockExchangeRates.trendData.count)
    }

    // MARK: - Fixtures

    @MainActor
    private static func makeFixtureBackedViewModel() -> HistoryViewModel {
        let service = MockExchangeRateService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncStore: MockHistoricalSyncStore())
        return HistoryViewModel(
            ratesStore: ExchangeRatesStore(),
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: DataOrchestrationUseCase(
                repository: service,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase
            ),
            chartDataPreparationUseCase: ChartDataPreparationUseCase(cacheService: InMemoryCacheService()),
            trendDataUseCase: TrendDataUseCase(
                trendRepository: service,
                historicalRateRepository: service
            ),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false))
        )
    }
}
