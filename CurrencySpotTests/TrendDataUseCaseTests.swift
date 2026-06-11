//
//  TrendDataUseCaseTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 8/1/25.
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("Trend Data Use Case Tests")
@MainActor
struct TrendDataUseCaseTests {
    // MARK: - Test Data Constants

    /// Fixed anchor (Wednesday, midnight CET) so date math never depends on the wall clock.
    private static let fixedNow = createCETDate(year: 2025, month: 1, day: 15)!
    private static let calendar = TimeZoneManager.cetCalendar

    private static let sampleTrendData: [TrendDataValue] = [
        TrendDataValue(currencyCode: "EUR", weeklyChange: 2.5, miniChartData: [1.0, 1.01, 1.02, 1.025, 1.025]),
        TrendDataValue(currencyCode: "GBP", weeklyChange: -1.8, miniChartData: [0.85, 0.84, 0.835, 0.832, 0.847]),
        TrendDataValue(currencyCode: "JPY", weeklyChange: 0.05, miniChartData: [110.0, 110.2, 110.1, 110.0, 110.05]),
    ]

    /// Ranges inside the trend window (last 7 days before fixedNow).
    private static let affectingRanges: [DateRange] = [
        DateRange(start: createCETDate(year: 2025, month: 1, day: 12)!, end: createCETDate(year: 2025, month: 1, day: 13)!),
        DateRange(start: createCETDate(year: 2025, month: 1, day: 14)!, end: createCETDate(year: 2025, month: 1, day: 15)!),
    ]

    /// Ranges far outside the trend window.
    private static let nonAffectingRanges: [DateRange] = [
        DateRange(start: createCETDate(year: 2024, month: 11, day: 1)!, end: createCETDate(year: 2024, month: 11, day: 5)!),
    ]

    private static func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: fixedNow)!
    }

    /// Historical rows inside the trend window, two days with drifting EUR/GBP rates.
    private static func windowHistoricalData() -> [HistoricalRateDataValue] {
        [
            HistoricalRateDataValue(date: day(-6), rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.0),
                HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.80),
            ]),
            HistoricalRateDataValue(date: day(-1), rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.1),
                HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.76),
            ]),
        ]
    }

    // MARK: - Test Helpers

    private func makeUseCase(
        trendRepository: MockTrendRepository,
        historicalRepository: MockHistoricalRateRepository = MockHistoricalRateRepository()
    ) -> TrendDataUseCase {
        TrendDataUseCase(
            trendRepository: trendRepository,
            historicalRateRepository: historicalRepository,
            dateProvider: FixedDateProvider(Self.fixedNow)
        )
    }

    // MARK: - initializeTrendData Tests

    @Test("When existing trends are available, should return them without calculation")
    func whenExistingTrendsAvailable_shouldReturnWithoutCalculation() async throws {
        let trendRepository = MockTrendRepository(trends: Self.sampleTrendData)
        let historicalRepository = MockHistoricalRateRepository()
        let useCase = makeUseCase(trendRepository: trendRepository, historicalRepository: historicalRepository)

        let result = try await useCase.initializeTrendData()

        #expect(result.count == 3)
        #expect(result.contains { $0.currencyCode == "EUR" })
        #expect(result.contains { $0.currencyCode == "GBP" })
        #expect(result.contains { $0.currencyCode == "JPY" })
        #expect(historicalRepository.fetchAndSaveHistoricalRatesCallCount == 0)
        #expect(trendRepository.saveTrendDataCallCount == 0)
    }

    @Test("When no existing trends and sufficient data, should calculate trends without fetching")
    func whenNoExistingTrendsAndSufficientData_shouldCalculateWithoutFetching() async throws {
        let trendRepository = MockTrendRepository(trends: [])
        trendRepository.historicalWindowData = Self.windowHistoricalData()
        let historicalRepository = MockHistoricalRateRepository()
        let useCase = makeUseCase(trendRepository: trendRepository, historicalRepository: historicalRepository)

        let result = try await useCase.initializeTrendData()

        #expect(historicalRepository.fetchAndSaveHistoricalRatesCallCount == 0)
        #expect(trendRepository.saveTrendDataCallCount == 1)
        #expect(result.count == 2) // EUR and GBP computed from the window data
        let eur = try #require(result.first { $0.currencyCode == "EUR" })
        #expect(abs(eur.weeklyChange - 10.0) < 0.0001) // (1.1 - 1.0) / 1.0 * 100
        #expect(eur.miniChartData == [1.0, 1.1])
    }

    @Test("When no existing trends and insufficient data, should fetch then calculate")
    func whenNoExistingTrendsAndInsufficientData_shouldFetchThenCalculate() async throws {
        let trendRepository = MockTrendRepository(trends: [])
        trendRepository.historicalWindowData = [] // insufficient
        let historicalRepository = MockHistoricalRateRepository()
        let useCase = makeUseCase(trendRepository: trendRepository, historicalRepository: historicalRepository)

        _ = try await useCase.initializeTrendData()

        #expect(historicalRepository.fetchAndSaveHistoricalRatesCallCount == 1)
        #expect(trendRepository.saveTrendDataCallCount == 1)
    }

    @Test("When fetching historical data, should use a 7-day window")
    func whenFetchingHistoricalData_shouldUseProperDateRange() async throws {
        let trendRepository = MockTrendRepository(trends: [])
        let historicalRepository = MockHistoricalRateRepository()
        let useCase = makeUseCase(trendRepository: trendRepository, historicalRepository: historicalRepository)

        _ = try await useCase.initializeTrendData()

        let fetchRange = try #require(historicalRepository.fetchAndSaveHistoricalRatesCalls.first)
        let daysDifference = Self.calendar.dateComponents([.day], from: fetchRange.from, to: fetchRange.to).day
        #expect(daysDifference == 7)
    }

    @Test("When load trends fails, the error propagates to the caller")
    func whenLoadTrendsFails_shouldThrow() async {
        let trendRepository = MockTrendRepository()
        trendRepository.shouldThrowOnLoadTrends = true
        let useCase = makeUseCase(trendRepository: trendRepository)

        await #expect(throws: Error.self) {
            _ = try await useCase.initializeTrendData()
        }
    }

    @Test("When saving calculated trends fails, the error propagates to the caller")
    func whenSaveTrendsFails_shouldThrow() async {
        let trendRepository = MockTrendRepository(trends: [])
        trendRepository.historicalWindowData = Self.windowHistoricalData()
        trendRepository.shouldThrowOnSave = true
        let useCase = makeUseCase(trendRepository: trendRepository)

        await #expect(throws: Error.self) {
            _ = try await useCase.initializeTrendData()
        }
    }

    // MARK: - calculateTrends (pure math, moved out of the persistence layer)

    @Test("calculateTrends computes per-currency weekly change and sparkline, sorted by date")
    func calculateTrendsComputesWeeklyChangeAndSparkline() throws {
        // Deliberately unsorted input rows.
        let rows = [
            HistoricalRateDataValue(date: Self.day(-1), rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.2)]),
            HistoricalRateDataValue(date: Self.day(-6), rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.0)]),
            HistoricalRateDataValue(date: Self.day(-3), rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.1)]),
        ]

        let trends = TrendDataUseCase.calculateTrends(from: rows)

        let eur = try #require(trends.first { $0.currencyCode == "EUR" })
        #expect(eur.miniChartData == [1.0, 1.1, 1.2])
        #expect(abs(eur.weeklyChange - 20.0) < 0.0001) // (1.2 - 1.0) / 1.0 * 100
    }

    @Test("calculateTrends skips currencies with fewer than 2 data points")
    func calculateTrendsSkipsSinglePointCurrencies() {
        let rows = [
            HistoricalRateDataValue(date: Self.day(-1), rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.2),
                HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.8),
            ]),
            HistoricalRateDataValue(date: Self.day(-2), rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.1),
            ]),
        ]

        let trends = TrendDataUseCase.calculateTrends(from: rows)

        #expect(trends.contains { $0.currencyCode == "EUR" })
        #expect(trends.contains { $0.currencyCode == "GBP" } == false)
    }

    @Test("calculateTrends of empty input is empty")
    func calculateTrendsEmptyInput() {
        #expect(TrendDataUseCase.calculateTrends(from: []).isEmpty)
    }

    // MARK: - getTrendData Tests

    @Test("getTrendData matches codes exactly, nil when absent", arguments: [
        ("EUR", 2.5),
        ("GBP", -1.8),
        ("CHF", nil),
    ] as [(String, Double?)])
    func getTrendDataLookup(code: String, expectedWeeklyChange: Double?) throws {
        let useCase = makeUseCase(trendRepository: MockTrendRepository())
        let currency = try #require(CurrencyCode(code))

        let result = useCase.getTrendData(for: currency, from: Self.sampleTrendData)

        #expect(result?.weeklyChange == expectedWeeklyChange)
        if expectedWeeklyChange != nil {
            #expect(result?.currencyCode == currency)
        }
    }

    @Test("When trend data array is empty, should return nil")
    func whenTrendDataArrayIsEmpty_shouldReturnNil() {
        let useCase = makeUseCase(trendRepository: MockTrendRepository())
        #expect(useCase.getTrendData(for: "EUR", from: []) == nil)
    }

    // MARK: - dateRangeAffectsTrends Tests (pure overlap math)

    @Test("dateRangeAffectsTrends detects overlap with the 7-day trend window", arguments: [
        (-30, -15, false), // old historical data
        (-3, 0, true), // recent data
        (-15, -2, true), // spans into the window
        (1, 2, false), // future data
    ])
    func dateRangeAffectsTrendsDetection(startOffset: Int, endOffset: Int, expected: Bool) {
        let useCase = makeUseCase(trendRepository: MockTrendRepository())

        let affects = useCase.dateRangeAffectsTrends(
            startDate: Self.day(startOffset),
            endDate: Self.day(endOffset),
            now: Self.fixedNow
        )

        #expect(affects == expected)
    }

    // MARK: - checkAndRecalculateTrendsIfNeeded Tests

    @Test("When missing ranges affect trends, should recalculate and return updated trends")
    func whenMissingRangesAffectTrends_shouldRecalculateAndReturnUpdatedTrends() async throws {
        let trendRepository = MockTrendRepository(trends: Self.sampleTrendData)
        trendRepository.historicalWindowData = Self.windowHistoricalData()
        let useCase = makeUseCase(trendRepository: trendRepository)

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: Self.affectingRanges)

        #expect(trendRepository.saveTrendDataCallCount == 1)
        // The recalculated trends replace the stored fixture set.
        #expect(result.count == 2)
        #expect(result.contains { $0.currencyCode == "EUR" })
    }

    @Test("When missing ranges do not affect trends, should return existing trends without recalculation")
    func whenMissingRangesDoNotAffectTrends_shouldReturnExistingTrendsWithoutRecalculation() async {
        let trendRepository = MockTrendRepository(trends: Self.sampleTrendData)
        let useCase = makeUseCase(trendRepository: trendRepository)

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: Self.nonAffectingRanges)

        #expect(result == Self.sampleTrendData)
        #expect(trendRepository.saveTrendDataCallCount == 0)
    }

    @Test("When empty date ranges provided, should return existing trends without processing")
    func whenEmptyDateRangesProvided_shouldReturnExistingTrendsWithoutProcessing() async {
        let trendRepository = MockTrendRepository(trends: Self.sampleTrendData)
        let useCase = makeUseCase(trendRepository: trendRepository)

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: [])

        #expect(result == Self.sampleTrendData)
        #expect(trendRepository.saveTrendDataCallCount == 0)
    }

    @Test("When recalculate trends fails, should return empty array and continue gracefully")
    func whenRecalculateTrendsFails_shouldReturnEmptyArrayAndContinueGracefully() async {
        let trendRepository = MockTrendRepository(trends: Self.sampleTrendData)
        trendRepository.historicalWindowData = Self.windowHistoricalData()
        trendRepository.shouldThrowOnSave = true
        let useCase = makeUseCase(trendRepository: trendRepository)

        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: Self.affectingRanges)

        #expect(result.isEmpty)
    }
}
