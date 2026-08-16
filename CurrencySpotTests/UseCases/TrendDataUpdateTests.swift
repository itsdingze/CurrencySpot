@testable import CurrencySpot
import Foundation
import Testing

@Suite("Trend Data Update Tests")
struct TrendDataUpdateTests {
    // MARK: - Test Data Setup

    private static let fixedToday = createCETDate(year: 2025, month: 1, day: 15)!

    private func makeHistoricalData(for currency: CurrencyCode, days: Int, endingOn today: Date = fixedToday) -> [HistoricalRateSnapshot] {
        let calendar = TimeZoneManager.cetCalendar
        return (0 ..< days).reversed().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
            let baseRate = currency == "EUR" ? 0.92 : (currency == "GBP" ? 0.79 : 1.5)
            let rate = baseRate + Double(dayOffset) * 0.001
            return HistoricalRateSnapshot(
                date: date,
                rates: [HistoricalRatePoint(currencyCode: currency, rate: rate)]
            )
        }
    }

    // MARK: - DataOrchestrationUseCase Tests

    @Test("DataOrchestrationUseCase reports fetched ranges within the requested range on a cold cache")
    func dataOrchestrationReturnsFetchedRanges() async throws {
        let mockService = PreviewExchangeRateRepository(today: Self.fixedToday)
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            repository: mockService,
            historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase(
                syncCoverage: MockHistoricalSyncStore(),
                dateProvider: FixedDateProvider(Self.fixedToday)
            ),
            dateProvider: FixedDateProvider(Self.fixedToday)
        )

        let calendar = TimeZoneManager.cetCalendar
        let endDate = Self.fixedToday
        let startDate = try #require(calendar.date(byAdding: .month, value: -3, to: endDate))
        let requestedRange = DateRange.spanning(startDate, endDate)

        let result = try await dataOrchestrationUseCase.loadHistoricalData(for: "EUR", dateRange: requestedRange)

        #expect(result.newDataFetched == true)
        #expect(result.fetchedRanges.isEmpty == false)
        let fetched = try #require(result.fetchedRanges.first)
        #expect(fetched.start >= requestedRange.start)
        #expect(fetched.end <= requestedRange.end)
    }

    @Test("DataOrchestrationUseCase serves from cache without fetching when the range is covered")
    func dataOrchestrationReturnsEmptyFetchedRangesFromCache() async throws {
        let mockService = PreviewExchangeRateRepository(today: Self.fixedToday)
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            repository: mockService,
            historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase(
                syncCoverage: MockHistoricalSyncStore(),
                dateProvider: FixedDateProvider(Self.fixedToday)
            ),
            dateProvider: FixedDateProvider(Self.fixedToday)
        )

        _ = await mockService.mergeCachedHistoricalRates(makeHistoricalData(for: "EUR", days: 90))

        let calendar = TimeZoneManager.cetCalendar
        let endDate = Self.fixedToday
        let startDate = try #require(calendar.date(byAdding: .day, value: -7, to: endDate))
        let requestedRange = DateRange.spanning(startDate, endDate)

        let result = try await dataOrchestrationUseCase.loadHistoricalData(for: "EUR", dateRange: requestedRange)

        #expect(result.newDataFetched == false)
        #expect(result.fetchedRanges.isEmpty)
    }

    // MARK: - Trend Recalculation Tests

    @Test("Trends recalculate when a fetched range affects the trend window")
    func trendRecalculatesWhenRangeAffectsTrends() async {
        let existing = [Trend(currencyCode: "EUR", weeklyChange: 1.0, miniChartData: [1.0, 1.1])]
        let trendRepository = MockTrendRepository(trends: existing)
        trendRepository.historicalWindowData = makeHistoricalData(for: "EUR", days: 7)
        let useCase = TrendDataUseCase(
            trendRepository: trendRepository,
            historicalRateRepository: MockHistoricalRateRepository(),
            dateProvider: FixedDateProvider(Self.fixedToday)
        )

        let affectingRange = DateRange.spanning(
            TimeZoneManager.cetCalendar.date(byAdding: .day, value: -2, to: Self.fixedToday)!,
            Self.fixedToday
        )

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: [affectingRange])

        #expect(trendRepository.saveTrendDataCallCount == 1)
        #expect(result != existing)
        #expect(result.contains { $0.currencyCode == "EUR" })
    }

    @Test("Trends are NOT recalculated when no range affects the trend window")
    func trendDoesNotRecalculateForUnaffectingRange() async {
        let existing = [Trend(currencyCode: "EUR", weeklyChange: 1.0, miniChartData: [1.0, 1.1])]
        let trendRepository = MockTrendRepository(trends: existing)
        let useCase = TrendDataUseCase(
            trendRepository: trendRepository,
            historicalRateRepository: MockHistoricalRateRepository(),
            dateProvider: FixedDateProvider(Self.fixedToday)
        )

        let unaffectingRange = DateRange.spanning(
            createCETDate(year: 2024, month: 10, day: 1)!,
            createCETDate(year: 2024, month: 10, day: 7)!
        )

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: [unaffectingRange])

        #expect(trendRepository.saveTrendDataCallCount == 0)
        #expect(result == existing)
    }

    // MARK: - Base Currency Conversion Tests (exact values from the fixture)

    @Test("EUR-base GBP trend is GBP/EUR per point with the derived weekly change")
    func trendConversionNonUSDBase() async {
        let viewModel = Self.makeFixtureBackedViewModel()
        await viewModel.initializeTrendData()
        viewModel.configure(base: "EUR", target: viewModel.targetCurrency)

        guard let trend = viewModel.getTrendData(for: "GBP") else {
            Issue.record("Expected a GBP trend when base is EUR")
            return
        }

        let expected = [0.76 / 0.85, 0.755 / 0.855, 0.753 / 0.857, 0.751 / 0.858, 0.749 / 0.859, 0.748 / 0.860, 0.75 / 0.86]
        #expect(trend.miniChartData.count == expected.count)
        for (actual, want) in zip(trend.miniChartData, expected) {
            #expect(abs(actual - want) < 0.0001)
        }
        let expectedChange = ((expected.last! - expected.first!) / expected.first!) * 100
        #expect(abs(trend.weeklyChange - expectedChange) < 0.001)
    }

    @Test("EUR-base USD trend is the inverted EUR fixture with the derived weekly change")
    func trendConversionUSDInversion() async {
        let viewModel = Self.makeFixtureBackedViewModel()
        await viewModel.initializeTrendData()
        viewModel.configure(base: "EUR", target: viewModel.targetCurrency)

        let usd = viewModel.getTrendData(for: "USD")
        guard let usd else {
            Issue.record("Expected a USD trend when base is EUR")
            return
        }

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
    func loadTriggersTrendRecalculation() async {
        let viewModel = Self.makeFixtureBackedViewModel()
        #expect(viewModel.trendData.isEmpty)

        await viewModel.loadCurrentConfigurationAndWait()

        #expect(viewModel.trendData.count == SampleExchangeRates.trendData.count)
    }

    // MARK: - Fixtures

    private static func makeFixtureBackedViewModel() -> HistoryViewModel {
        let service = PreviewExchangeRateRepository()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncCoverage: MockHistoricalSyncStore())
        let watchlistDefaults = UserDefaults(suiteName: "TrendDataUpdateTests.\(UUID().uuidString)") ?? .standard
        return HistoryViewModel(
            ratesStore: ExchangeRatesStore(),
            watchlist: WatchlistStore(userDefaults: watchlistDefaults, seed: CurrencyDefaults.favoriteCurrencies),
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: DataOrchestrationUseCase(
                repository: service,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase
            ),
            chartDataPreparationUseCase: ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache()),
            trendDataUseCase: TrendDataUseCase(
                trendRepository: service,
                historicalRateRepository: service
            ),
            preferences: InMemoryPreferencesStore(),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false))
        )
    }
}
