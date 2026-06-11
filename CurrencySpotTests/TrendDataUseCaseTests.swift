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

    private static let sampleTrendData: [TrendDataValue] = [
        TrendDataValue(currencyCode: "EUR", weeklyChange: 2.5, miniChartData: [1.0, 1.01, 1.02, 1.025, 1.025]),
        TrendDataValue(currencyCode: "GBP", weeklyChange: -1.8, miniChartData: [0.85, 0.84, 0.835, 0.832, 0.847]),
        TrendDataValue(currencyCode: "JPY", weeklyChange: 0.05, miniChartData: [110.0, 110.2, 110.1, 110.0, 110.05]),
    ]

    private static let sampleDateRanges: [DateRange] = [
        DateRange(start: createCETDate(year: 2025, month: 1, day: 12)!, end: createCETDate(year: 2025, month: 1, day: 13)!),
        DateRange(start: createCETDate(year: 2025, month: 1, day: 14)!, end: createCETDate(year: 2025, month: 1, day: 15)!),
    ]

    // MARK: - Test Helpers

    /// Creates a configurable mock service for testing different scenarios
    private func createMockService(
        existingTrends: [TrendDataValue] = [],
        hasSufficientData: Bool = true,
        shouldThrowOnLoad: Bool = false,
        shouldThrowOnCalculate: Bool = false,
        affectsTrends: Bool = false
    ) -> ConfigurableMockExchangeRateService {
        ConfigurableMockExchangeRateService(
            existingTrends: existingTrends,
            hasSufficientData: hasSufficientData,
            shouldThrowOnLoad: shouldThrowOnLoad,
            shouldThrowOnCalculate: shouldThrowOnCalculate,
            affectsTrends: affectsTrends
        )
    }

    // MARK: - initializeTrendData Tests

    @Test("When existing trends are available, should return them without calculation")
    func whenExistingTrendsAvailable_shouldReturnWithoutCalculation() async {
        // GIVEN: A service with existing trend data
        let mockService = createMockService(existingTrends: Self.sampleTrendData)
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Initializing trend data
        let result = await useCase.initializeTrendData()

        // THEN: Should return existing trends without fetching or calculating
        #expect(result.count == 3)
        #expect(result.contains { $0.currencyCode == "EUR" })
        #expect(result.contains { $0.currencyCode == "GBP" })
        #expect(result.contains { $0.currencyCode == "JPY" })
        #expect(mockService.didFetchHistoricalData == false)
        #expect(mockService.didCalculateTrends == false)
    }

    @Test("When no existing trends and sufficient data, should calculate trends without fetching")
    func whenNoExistingTrendsAndSufficientData_shouldCalculateWithoutFetching() async {
        // GIVEN: A service with no existing trends but sufficient historical data
        let mockService = createMockService(
            existingTrends: [],
            hasSufficientData: true
        )
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Initializing trend data
        let result = await useCase.initializeTrendData()

        // THEN: Should calculate trends without fetching historical data
        #expect(result == Self.sampleTrendData)
        #expect(mockService.didFetchHistoricalData == false)
        #expect(mockService.didCalculateTrends)
    }

    @Test("When no existing trends and insufficient data, should fetch then calculate")
    func whenNoExistingTrendsAndInsufficientData_shouldFetchThenCalculate() async {
        // GIVEN: A service with no existing trends and insufficient historical data
        let mockService = createMockService(
            existingTrends: [],
            hasSufficientData: false
        )
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Initializing trend data
        let result = await useCase.initializeTrendData()

        // THEN: Should fetch historical data then calculate trends
        #expect(result == Self.sampleTrendData)
        #expect(mockService.didFetchHistoricalData)
        #expect(mockService.didCalculateTrends)
    }

    @Test("When load trends fails, should return empty array and handle error")
    func whenLoadTrendsFails_shouldReturnEmptyArrayAndHandleError() async {
        // GIVEN: A service that throws when loading trends
        let mockService = createMockService(shouldThrowOnLoad: true)
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Initializing trend data
        let result = await useCase.initializeTrendData()

        // THEN: Should return empty array and error should be handled by AppState
        #expect(result.isEmpty)
        // Note: We can't easily test AppState.shared.errorHandler.handle call without dependency injection
        // This is a trade-off in the current architecture
    }

    @Test("When calculate trends fails, should return empty array and handle error")
    func whenCalculateTrendsFails_shouldReturnEmptyArrayAndHandleError() async {
        // GIVEN: A service that throws when calculating trends
        let mockService = createMockService(
            existingTrends: [],
            shouldThrowOnCalculate: true
        )
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Initializing trend data
        let result = await useCase.initializeTrendData()

        // THEN: Should return empty array
        #expect(result.isEmpty)
    }

    @Test("When fetching historical data specified correctly, should use proper date range")
    func whenFetchingHistoricalData_shouldUseProperDateRange() async throws {
        // GIVEN: A service with insufficient data
        let mockService = createMockService(
            existingTrends: [],
            hasSufficientData: false
        )
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Initializing trend data
        _ = await useCase.initializeTrendData()

        // THEN: Should fetch 7 days of historical data
        #expect(mockService.didFetchHistoricalData)
        let fetchRange = try #require(mockService.lastFetchedDateRange)
        let daysDifference = TimeZoneManager.cetCalendar.dateComponents([.day], from: fetchRange.start, to: fetchRange.end).day
        #expect(daysDifference == 7)
    }

    // MARK: - getTrendData Tests

    /// Lookup fixture spanning ordinary codes, boundary weeklyChange values, and
    /// special-character codes, so one parameterized test covers all lookup behavior.
    private static let lookupFixture: [TrendDataValue] = sampleTrendData + [
        TrendDataValue(currencyCode: "USD-TEST", weeklyChange: Double.greatestFiniteMagnitude, miniChartData: [1.0]),
        TrendDataValue(currencyCode: "EUR@2024", weeklyChange: -Double.greatestFiniteMagnitude, miniChartData: [1.0]),
        TrendDataValue(currencyCode: "ZERO", weeklyChange: 0.0, miniChartData: [1.0]),
    ]

    @Test("getTrendData matches codes exactly (case- and character-sensitive), nil when absent", arguments: [
        ("EUR", 2.5), // ordinary hit
        ("GBP", -1.8),
        ("CHF", nil), // absent code
        ("eur", nil), // case-sensitive: lowercase must not match "EUR"
        ("USD-TEST", Double.greatestFiniteMagnitude), // special characters + boundary value
        ("EUR@2024", -Double.greatestFiniteMagnitude),
        ("ZERO", 0.0),
    ] as [(String, Double?)])
    func getTrendDataLookup(code: String, expectedWeeklyChange: Double?) {
        let useCase = TrendDataUseCase(service: MockExchangeRateService())

        let result = useCase.getTrendData(for: code, from: Self.lookupFixture)

        #expect(result?.weeklyChange == expectedWeeklyChange)
        if expectedWeeklyChange != nil {
            #expect(result?.currencyCode == code)
        }
    }

    @Test("When trend data array is empty, should return nil")
    func whenTrendDataArrayIsEmpty_shouldReturnNil() {
        let useCase = TrendDataUseCase(service: MockExchangeRateService())
        let result = useCase.getTrendData(for: "EUR", from: [])
        #expect(result == nil)
    }

    // MARK: - checkAndRecalculateT rendsIfNeeded Tests

    @Test("When missing ranges affect trends, should recalculate and return updated trends")
    func whenMissingRangesAffectTrends_shouldRecalculateAndReturnUpdatedTrends() async {
        // GIVEN: A service where date ranges affect trends
        let mockService = createMockService(
            existingTrends: Self.sampleTrendData,
            affectsTrends: true
        )
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Checking and recalculating trends for missing ranges
        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: Self.sampleDateRanges)

        // THEN: Should recalculate trends and return updated data
        #expect(result == Self.sampleTrendData)
        #expect(mockService.didCalculateTrends)
    }

    @Test("When missing ranges do not affect trends, should return existing trends without recalculation")
    func whenMissingRangesDoNotAffectTrends_shouldReturnExistingTrendsWithoutRecalculation() async {
        // GIVEN: A service where date ranges do not affect trends
        let mockService = createMockService(
            existingTrends: Self.sampleTrendData,
            affectsTrends: false
        )
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Checking and recalculating trends for missing ranges
        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: Self.sampleDateRanges)

        // THEN: Should return existing trends without recalculation
        #expect(result == Self.sampleTrendData)
        #expect(mockService.didCalculateTrends == false)
        #expect(mockService.doesDateRangeAffectTrendsCallCount == Self.sampleDateRanges.count) // Should check all ranges
    }

    @Test("When multiple ranges provided but first affects trends, should stop checking after first match")
    func whenMultipleRangesButFirstAffectsTrends_shouldStopCheckingAfterFirstMatch() async throws {
        // GIVEN: A service where only the first range affects trends
        let mockService = ConfigurableMockExchangeRateService(
            existingTrends: Self.sampleTrendData,
            hasSufficientData: true,
            shouldThrowOnLoad: false,
            shouldThrowOnCalculate: false,
            affectsTrends: true,
            affectsTrendsOnlyFirst: true
        )
        let useCase = TrendDataUseCase(service: mockService)
        func day(_ d: Int) throws -> Date {
            try #require(createCETDate(year: 2025, month: 1, day: d))
        }
        let multipleRanges = try [
            DateRange(start: day(10), end: day(11)),
            DateRange(start: day(12), end: day(13)),
            DateRange(start: day(14), end: day(15)),
        ]

        // WHEN: Checking multiple ranges
        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: multipleRanges)

        // THEN: Should stop after first affecting range and recalculate
        #expect(result == Self.sampleTrendData)
        #expect(mockService.didCalculateTrends)
        #expect(mockService.doesDateRangeAffectTrendsCallCount == 1) // Should stop after first match
    }

    @Test("When empty date ranges provided, should return existing trends without processing")
    func whenEmptyDateRangesProvided_shouldReturnExistingTrendsWithoutProcessing() async {
        // GIVEN: A service with existing trends
        let mockService = createMockService(existingTrends: Self.sampleTrendData)
        let useCase = TrendDataUseCase(service: mockService)
        let emptyRanges: [DateRange] = []

        // WHEN: Checking empty ranges
        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: emptyRanges)

        // THEN: Should return existing trends without any processing
        #expect(result == Self.sampleTrendData)
        #expect(mockService.didCalculateTrends == false)
        #expect(mockService.doesDateRangeAffectTrendsCallCount == 0)
    }

    @Test("When checking date range fails, should return empty array and continue gracefully")
    func whenCheckingDateRangeFails_shouldReturnEmptyArrayAndContinueGracefully() async {
        // GIVEN: A service that throws when checking if date range affects trends
        let mockService = ConfigurableMockExchangeRateService(
            existingTrends: Self.sampleTrendData,
            hasSufficientData: true,
            shouldThrowOnLoad: false,
            shouldThrowOnCalculate: false,
            shouldThrowOnDateRangeCheck: true,
            affectsTrends: false
        )
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Checking and recalculating trends
        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: Self.sampleDateRanges)

        // THEN: Should return empty array and continue gracefully
        #expect(result.isEmpty)
        #expect(mockService.didCalculateTrends == false)
    }

    @Test("When recalculate trends fails, should return empty array and continue gracefully")
    func whenRecalculateTrendsFails_shouldReturnEmptyArrayAndContinueGracefully() async {
        // GIVEN: A service that affects trends but fails when recalculating
        let mockService = createMockService(
            existingTrends: Self.sampleTrendData,
            shouldThrowOnCalculate: true,
            affectsTrends: true
        )
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Checking and recalculating trends
        let result = await useCase.checkAndRecalculateTrendsIfNeeded(for: Self.sampleDateRanges)

        // THEN: Should return empty array and continue gracefully
        #expect(result.isEmpty)
    }
}

// MARK: - Test Double: Configurable Mock Service

/// A more sophisticated mock service that allows configuration of different behaviors for comprehensive testing
private class ConfigurableMockExchangeRateService: ExchangeRateService {
    // Sample data for testing
    private let sampleTrendData: [TrendDataValue] = [
        TrendDataValue(currencyCode: "EUR", weeklyChange: 2.5, miniChartData: [1.0, 1.01, 1.02, 1.025, 1.025]),
        TrendDataValue(currencyCode: "GBP", weeklyChange: -1.8, miniChartData: [0.85, 0.84, 0.835, 0.832, 0.847]),
        TrendDataValue(currencyCode: "JPY", weeklyChange: 0.05, miniChartData: [110.0, 110.2, 110.1, 110.0, 110.05]),
    ]

    // Configuration properties
    private let existingTrends: [TrendDataValue]
    private let hasSufficientData: Bool
    private let shouldThrowOnLoad: Bool
    private let shouldThrowOnCalculate: Bool
    private let shouldThrowOnDateRangeCheck: Bool
    private let affectsTrends: Bool
    private let affectsTrendsOnlyFirst: Bool

    // Tracking properties
    private(set) var didFetchHistoricalData = false
    private(set) var didCalculateTrends = false
    private(set) var loadTrendDataCallCount = 0
    private(set) var doesDateRangeAffectTrendsCallCount = 0
    private(set) var lastFetchedDateRange: (start: Date, end: Date)?

    init(
        existingTrends: [TrendDataValue] = [],
        hasSufficientData: Bool = true,
        shouldThrowOnLoad: Bool = false,
        shouldThrowOnCalculate: Bool = false,
        shouldThrowOnDateRangeCheck: Bool = false,
        affectsTrends: Bool = false,
        affectsTrendsOnlyFirst: Bool = false
    ) {
        self.existingTrends = existingTrends
        self.hasSufficientData = hasSufficientData
        self.shouldThrowOnLoad = shouldThrowOnLoad
        self.shouldThrowOnCalculate = shouldThrowOnCalculate
        self.shouldThrowOnDateRangeCheck = shouldThrowOnDateRangeCheck
        self.affectsTrends = affectsTrends
        self.affectsTrendsOnlyFirst = affectsTrendsOnlyFirst
    }

    // MARK: - ExchangeRateService Implementation

    func shouldFetchNewRates() async -> Bool { false }

    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        ExchangeRatesResponse(base: "USD", date: "2025-08-01", rates: [:])
    }

    func fetchAndSaveHistoricalRates(from startDate: Date, to endDate: Date) async throws {
        didFetchHistoricalData = true
        lastFetchedDateRange = (startDate, endDate)
    }

    func saveExchangeRates(_: [String: Double]) async throws {}
    func saveHistoricalExchangeRates(_: [String: [String: Double]]) async throws {}

    func loadExchangeRates() async throws -> [ExchangeRateDataValue] { [] }

    func loadHistoricalRatesForCurrency(currency _: String, startDate _: String, endDate _: String) async throws -> [HistoricalRateDataValue] { [] }

    func updateLastFetchDate(_: Date) {}
    func getLastFetchDate() -> Date? { Date() }
    func getEarliestStoredDate() async throws -> Date? { Date() }
    func getLatestStoredDate() async throws -> Date? { Date() }
    func clearAllData() async throws {}

    // MARK: - Trend Data Methods (Main Test Focus)

    func loadTrendData() async throws -> [TrendDataValue] {
        loadTrendDataCallCount += 1

        if shouldThrowOnLoad {
            throw AppError.unknownError("Mock load error")
        }

        // After trends are calculated, return sample data instead of empty trends
        if didCalculateTrends, existingTrends.isEmpty {
            return sampleTrendData
        }

        return existingTrends
    }

    func calculateAndSaveTrendData() async throws {
        didCalculateTrends = true

        if shouldThrowOnCalculate {
            throw AppError.unknownError("Mock calculation error")
        }
    }

    func hasSufficientHistoricalDataForTrends() async throws -> Bool {
        hasSufficientData
    }

    func doesDateRangeAffectTrends(startDate _: Date, endDate _: Date) async throws -> Bool {
        doesDateRangeAffectTrendsCallCount += 1

        if shouldThrowOnDateRangeCheck {
            throw AppError.dateCalculationError("Mock date range check error")
        }

        // If configured to only affect trends on first call, return false after first call
        if affectsTrendsOnlyFirst {
            return doesDateRangeAffectTrendsCallCount == 1 && affectsTrends
        }

        return affectsTrends
    }
}
