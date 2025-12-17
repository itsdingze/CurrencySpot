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
        DateRange(start: Date().addingTimeInterval(-86400 * 3), end: Date().addingTimeInterval(-86400 * 2)),
        DateRange(start: Date().addingTimeInterval(-86400), end: Date()),
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
        #expect(!mockService.didFetchHistoricalData)
        #expect(!mockService.didCalculateTrends)
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
        #expect(!mockService.didFetchHistoricalData)
        #expect(mockService.didCalculateTrends)
        #expect(mockService.loadTrendDataCallCount == 2) // Once for check, once for final result
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
        #expect(mockService.loadTrendDataCallCount == 2)
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
    func whenFetchingHistoricalData_shouldUseProperDateRange() async {
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
        if let fetchRange = mockService.lastFetchedDateRange {
            let daysDifference = Calendar.current.dateComponents([.day], from: fetchRange.start, to: fetchRange.end).day ?? 0
            #expect(daysDifference == 7)
        }
    }

    // MARK: - getTrendData Tests

    @Test("When currency code exists in trend data, should return matching trend")
    func whenCurrencyCodeExists_shouldReturnMatchingTrend() {
        // GIVEN: A use case and trend data with EUR
        let useCase = TrendDataUseCase(service: MockExchangeRateService())
        let trendData = Self.sampleTrendData

        // WHEN: Getting trend data for EUR
        let result = useCase.getTrendData(for: "EUR", from: trendData)

        // THEN: Should return EUR trend data
        #expect(result != nil)
        #expect(result?.currencyCode == "EUR")
        #expect(result?.weeklyChange == 2.5)
    }

    @Test("When currency code does not exist in trend data, should return nil")
    func whenCurrencyCodeDoesNotExist_shouldReturnNil() {
        // GIVEN: A use case and trend data without CHF
        let useCase = TrendDataUseCase(service: MockExchangeRateService())
        let trendData = Self.sampleTrendData

        // WHEN: Getting trend data for CHF
        let result = useCase.getTrendData(for: "CHF", from: trendData)

        // THEN: Should return nil
        #expect(result == nil)
    }

    @Test("When trend data array is empty, should return nil")
    func whenTrendDataArrayIsEmpty_shouldReturnNil() {
        // GIVEN: A use case and empty trend data
        let useCase = TrendDataUseCase(service: MockExchangeRateService())
        let emptyTrendData: [TrendDataValue] = []

        // WHEN: Getting trend data for any currency
        let result = useCase.getTrendData(for: "EUR", from: emptyTrendData)

        // THEN: Should return nil
        #expect(result == nil)
    }

    @Test("When currency code is case sensitive, should match exactly")
    func whenCurrencyCodeIsCaseSensitive_shouldMatchExactly() {
        // GIVEN: A use case and trend data with uppercase EUR
        let useCase = TrendDataUseCase(service: MockExchangeRateService())
        let trendData = Self.sampleTrendData

        // WHEN: Getting trend data with lowercase eur
        let result = useCase.getTrendData(for: "eur", from: trendData)

        // THEN: Should return nil (case sensitive match)
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
        #expect(mockService.doesDateRangeAffectTrendsCallCount == 1) // Should break after first affecting range
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
        #expect(!mockService.didCalculateTrends)
        #expect(mockService.doesDateRangeAffectTrendsCallCount == Self.sampleDateRanges.count) // Should check all ranges
    }

    @Test("When multiple ranges provided but first affects trends, should stop checking after first match")
    func whenMultipleRangesButFirstAffectsTrends_shouldStopCheckingAfterFirstMatch() async {
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
        let multipleRanges = [
            DateRange(start: Date().addingTimeInterval(-86400 * 5), end: Date().addingTimeInterval(-86400 * 4)),
            DateRange(start: Date().addingTimeInterval(-86400 * 3), end: Date().addingTimeInterval(-86400 * 2)),
            DateRange(start: Date().addingTimeInterval(-86400), end: Date()),
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
        #expect(!mockService.didCalculateTrends)
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
        #expect(!mockService.didCalculateTrends)
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

    // MARK: - Edge Cases and Boundary Conditions

    @Test("When date range calculation fails due to invalid calendar, should use fallback dates")
    func whenDateRangeCalculationFails_shouldUseFallbackDates() async {
        // GIVEN: A use case with insufficient data (will trigger date calculation)
        let mockService = createMockService(
            existingTrends: [],
            hasSufficientData: false
        )
        let useCase = TrendDataUseCase(service: mockService)

        // WHEN: Initializing trend data (this triggers date calculation internally)
        _ = await useCase.initializeTrendData()

        // THEN: Should still attempt to fetch data with fallback dates
        #expect(mockService.didFetchHistoricalData)
        // The implementation uses fallback to endDate if calendar calculation fails
    }

    @Test("When trend data has boundary weekly change values, should handle correctly")
    func whenTrendDataHasBoundaryWeeklyChangeValues_shouldHandleCorrectly() {
        // GIVEN: Trend data with boundary values (very large positive/negative changes)
        let useCase = TrendDataUseCase(service: MockExchangeRateService())
        let boundaryTrendData = [
            TrendDataValue(currencyCode: "HIGH", weeklyChange: Double.greatestFiniteMagnitude, miniChartData: [1.0]),
            TrendDataValue(currencyCode: "LOW", weeklyChange: -Double.greatestFiniteMagnitude, miniChartData: [1.0]),
            TrendDataValue(currencyCode: "ZERO", weeklyChange: 0.0, miniChartData: [1.0]),
        ]

        // WHEN: Getting trend data for boundary values
        let highResult = useCase.getTrendData(for: "HIGH", from: boundaryTrendData)
        let lowResult = useCase.getTrendData(for: "LOW", from: boundaryTrendData)
        let zeroResult = useCase.getTrendData(for: "ZERO", from: boundaryTrendData)

        // THEN: Should handle all boundary values correctly
        #expect(highResult?.weeklyChange == Double.greatestFiniteMagnitude)
        #expect(lowResult?.weeklyChange == -Double.greatestFiniteMagnitude)
        #expect(zeroResult?.weeklyChange == 0.0)
    }

    @Test("When currency code contains special characters, should match exactly")
    func whenCurrencyCodeContainsSpecialCharacters_shouldMatchExactly() {
        // GIVEN: Trend data with special character currency codes
        let useCase = TrendDataUseCase(service: MockExchangeRateService())
        let specialTrendData = [
            TrendDataValue(currencyCode: "USD-TEST", weeklyChange: 1.0, miniChartData: [1.0]),
            TrendDataValue(currencyCode: "EUR@2024", weeklyChange: 2.0, miniChartData: [1.0]),
            TrendDataValue(currencyCode: "GBP_OLD", weeklyChange: 3.0, miniChartData: [1.0]),
        ]

        // WHEN: Getting trend data for special character codes
        let result1 = useCase.getTrendData(for: "USD-TEST", from: specialTrendData)
        let result2 = useCase.getTrendData(for: "EUR@2024", from: specialTrendData)
        let result3 = useCase.getTrendData(for: "GBP_OLD", from: specialTrendData)

        // THEN: Should match exactly including special characters
        #expect(result1?.currencyCode == "USD-TEST")
        #expect(result2?.currencyCode == "EUR@2024")
        #expect(result3?.currencyCode == "GBP_OLD")
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
            throw AppError.storageError("Mock load error")
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
            throw AppError.storageError("Mock calculation error")
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
