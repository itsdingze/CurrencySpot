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

    /// Deterministic historical data (no randomness) covering `days` ending today.
    private func makeHistoricalData(for currency: String, days: Int) -> [HistoricalRateDataValue] {
        let calendar = TimeZoneManager.cetCalendar
        let today = Date()
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
        let mockService = MockExchangeRateService()
        let cacheService = InMemoryCacheService()
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase(),
            cacheService: cacheService
        )

        let calendar = TimeZoneManager.cetCalendar
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: endDate)!
        let requestedRange = DateRange(start: startDate, end: endDate)

        let result = try await dataOrchestrationUseCase.loadHistoricalData(for: "EUR", dateRange: requestedRange)

        #expect(result.newDataFetched == true)
        #expect(!result.fetchedRanges.isEmpty)
        let fetched = try #require(result.fetchedRanges.first)
        #expect(fetched.start >= requestedRange.start)
        #expect(fetched.end <= requestedRange.end)
    }

    @Test("DataOrchestrationUseCase serves from cache without fetching when the range is covered")
    func dataOrchestrationReturnsEmptyFetchedRangesFromCache() async throws {
        let mockService = MockExchangeRateService()
        let cacheService = InMemoryCacheService()
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase(),
            cacheService: cacheService
        )

        await cacheService.cacheHistoricalData(makeHistoricalData(for: "EUR", days: 90), for: "EUR")

        let calendar = TimeZoneManager.cetCalendar
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        let requestedRange = DateRange(start: startDate, end: endDate)

        let result = try await dataOrchestrationUseCase.loadHistoricalData(for: "EUR", dateRange: requestedRange)

        #expect(result.newDataFetched == false)
        #expect(result.fetchedRanges.isEmpty)
    }

    // MARK: - Trend Recalculation Tests (call-counting spy)

    @Test("Trends recalculate when a fetched range affects the trend window")
    func trendRecalculatesWhenRangeAffectsTrends() async {
        let existing = [TrendDataValue(currencyCode: "EUR", weeklyChange: 1.0, miniChartData: [1.0, 1.1])]
        let recalculated = [TrendDataValue(currencyCode: "EUR", weeklyChange: 2.0, miniChartData: [1.2, 1.3])]
        let spy = SpyExchangeRateService(existingTrends: existing, recalculatedTrends: recalculated)
        spy.affectsTrends = true
        let useCase = TrendDataUseCase(service: spy)

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: [Self.anyRange])

        #expect(spy.calculateAndSaveTrendDataCallCount == 1)
        #expect(result == recalculated)
    }

    @Test("Trends are NOT recalculated when no range affects the trend window")
    func trendDoesNotRecalculateForUnaffectingRange() async {
        let existing = [TrendDataValue(currencyCode: "EUR", weeklyChange: 1.0, miniChartData: [1.0, 1.1])]
        let recalculated = [TrendDataValue(currencyCode: "EUR", weeklyChange: 2.0, miniChartData: [1.2, 1.3])]
        let spy = SpyExchangeRateService(existingTrends: existing, recalculatedTrends: recalculated)
        spy.affectsTrends = false
        let useCase = TrendDataUseCase(service: spy)

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: [Self.anyRange])

        #expect(spy.calculateAndSaveTrendDataCallCount == 0)
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

    private static let anyRange = DateRange(
        start: TimeZoneManager.createCETDate(year: 2025, month: 3, day: 1)!,
        end: TimeZoneManager.createCETDate(year: 2025, month: 3, day: 7)!
    )

    @MainActor
    private static func makeFixtureBackedViewModel() -> HistoryViewModel {
        let service = MockExchangeRateService()
        let cacheService = InMemoryCacheService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()
        return HistoryViewModel(
            service: service,
            calculatorVM: CalculatorViewModel(service: service),
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: DataOrchestrationUseCase(
                service: service,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
                cacheService: cacheService
            ),
            chartDataPreparationUseCase: ChartDataPreparationUseCase(
                rateCalculationUseCase: RateCalculationUseCase(),
                cacheService: cacheService
            ),
            trendDataUseCase: TrendDataUseCase(service: service)
        )
    }
}

// MARK: - Spy

/// Records trend-recalculation calls and serves distinct trend sets before/after recalculation,
/// so a use case's "recalculate only when needed" branching is directly observable.
private final class SpyExchangeRateService: ExchangeRateService {
    private let base = MockExchangeRateService()
    var affectsTrends = false
    private(set) var calculateAndSaveTrendDataCallCount = 0
    private let existingTrends: [TrendDataValue]
    private let recalculatedTrends: [TrendDataValue]
    private var didRecalculate = false

    init(existingTrends: [TrendDataValue], recalculatedTrends: [TrendDataValue]) {
        self.existingTrends = existingTrends
        self.recalculatedTrends = recalculatedTrends
    }

    // Overridden trend behavior under test.
    func doesDateRangeAffectTrends(startDate _: Date, endDate _: Date) async throws -> Bool { affectsTrends }

    func calculateAndSaveTrendData() async throws {
        calculateAndSaveTrendDataCallCount += 1
        didRecalculate = true
    }

    func loadTrendData() async throws -> [TrendDataValue] {
        didRecalculate ? recalculatedTrends : existingTrends
    }

    // Everything else delegates to the standard mock.
    func shouldFetchNewRates() async -> Bool { await base.shouldFetchNewRates() }
    func fetchExchangeRates() async throws -> ExchangeRatesResponse { try await base.fetchExchangeRates() }
    func fetchAndSaveHistoricalRates(from startDate: Date, to endDate: Date) async throws {
        try await base.fetchAndSaveHistoricalRates(from: startDate, to: endDate)
    }
    func saveExchangeRates(_ rates: [String: Double]) async throws { try await base.saveExchangeRates(rates) }
    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws {
        try await base.saveHistoricalExchangeRates(rates)
    }
    func loadExchangeRates() async throws -> [ExchangeRateDataValue] { try await base.loadExchangeRates() }
    func loadHistoricalRatesForCurrency(currency: String, startDate: String, endDate: String) async throws -> [HistoricalRateDataValue] {
        try await base.loadHistoricalRatesForCurrency(currency: currency, startDate: startDate, endDate: endDate)
    }
    func updateLastFetchDate(_ date: Date) { base.updateLastFetchDate(date) }
    func getLastFetchDate() -> Date? { base.getLastFetchDate() }
    func getEarliestStoredDate() async throws -> Date? { try await base.getEarliestStoredDate() }
    func getLatestStoredDate() async throws -> Date? { try await base.getLatestStoredDate() }
    func hasSufficientHistoricalDataForTrends() async throws -> Bool { try await base.hasSufficientHistoricalDataForTrends() }
    func clearAllData() async throws { try await base.clearAllData() }
}
