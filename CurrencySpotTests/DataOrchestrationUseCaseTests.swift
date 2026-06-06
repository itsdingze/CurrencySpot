//
//  DataOrchestrationUseCaseTests.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/1/25.
//

@testable import CurrencySpot
import Foundation
import Testing

// MARK: - Mock Services

/// Mock implementation of ExchangeRateService for testing DataOrchestrationUseCase
final class MockExchangeRateServiceForOrchestration: ExchangeRateService {
    // MARK: - Test Configuration Properties

    var shouldFetchNewRatesResult = false
    var fetchAndSaveHistoricalRatesCallCount = 0
    var loadHistoricalRatesCallCount = 0
    var getEarliestStoredDateResult: Date?
    var getLatestStoredDateResult: Date?
    var lastFetchDate: Date?

    // Test data storage
    var historicalDataToReturn: [HistoricalRateDataValue] = []
    var exchangeRatesToReturn: [ExchangeRateDataValue] = []
    var trendDataToReturn: [TrendDataValue] = []

    // Call tracking
    var fetchAndSaveHistoricalRatesCalls: [(from: Date, to: Date)] = []
    var loadHistoricalRatesForCurrencyCalls: [(currency: String, startDate: String, endDate: String)] = []

    // Error simulation
    var shouldThrowErrorOnFetch = false
    var shouldThrowErrorOnLoad = false
    var errorToThrow: Error = AppError.networkError("Mock error")

    // MARK: - Rate Fetching Check Methods

    func shouldFetchNewRates() async -> Bool {
        shouldFetchNewRatesResult
    }

    // MARK: - Network Data Fetching Methods

    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        if shouldThrowErrorOnFetch {
            throw errorToThrow
        }

        return ExchangeRatesResponse(
            base: "USD",
            date: TimeZoneManager.formatForAPI(Date()),
            rates: ["EUR": 0.85, "GBP": 0.75, "JPY": 110.0]
        )
    }

    func fetchAndSaveHistoricalRates(from startDate: Date, to endDate: Date) async throws {
        // Record the attempt before any throw so failed fetches remain observable.
        fetchAndSaveHistoricalRatesCallCount += 1
        fetchAndSaveHistoricalRatesCalls.append((from: startDate, to: endDate))

        if shouldThrowErrorOnFetch {
            throw errorToThrow
        }
    }

    // MARK: - Data Persistence Methods

    func saveExchangeRates(_: [String: Double]) async throws {
        // No-op for testing
    }

    func saveHistoricalExchangeRates(_: [String: [String: Double]]) async throws {
        // No-op for testing
    }

    // MARK: - Data Loading Methods

    func loadExchangeRates() async throws -> [ExchangeRateDataValue] {
        if shouldThrowErrorOnLoad {
            throw errorToThrow
        }
        return exchangeRatesToReturn
    }

    func loadHistoricalRatesForCurrency(
        currency: String,
        startDate: String,
        endDate: String
    ) async throws -> [HistoricalRateDataValue] {
        if shouldThrowErrorOnLoad {
            throw errorToThrow
        }

        loadHistoricalRatesCallCount += 1
        loadHistoricalRatesForCurrencyCalls.append((currency: currency, startDate: startDate, endDate: endDate))

        return historicalDataToReturn
    }

    // MARK: - Date Management Methods

    func updateLastFetchDate(_ date: Date) {
        lastFetchDate = date
    }

    func getLastFetchDate() -> Date? {
        lastFetchDate
    }

    func getEarliestStoredDate() async throws -> Date? {
        getEarliestStoredDateResult
    }

    func getLatestStoredDate() async throws -> Date? {
        getLatestStoredDateResult
    }

    // MARK: - Trend Data Methods

    func loadTrendData() async throws -> [TrendDataValue] {
        if shouldThrowErrorOnLoad {
            throw errorToThrow
        }
        return trendDataToReturn
    }

    func calculateAndSaveTrendData() async throws {
        // No-op for testing
    }

    func hasSufficientHistoricalDataForTrends() async throws -> Bool {
        true
    }

    func doesDateRangeAffectTrends(startDate _: Date, endDate _: Date) async throws -> Bool {
        true
    }

    // MARK: - Data Management Methods

    func clearAllData() async throws {
        // No-op for testing
    }

    // MARK: - Test Helper Methods

    func reset() {
        shouldFetchNewRatesResult = false
        fetchAndSaveHistoricalRatesCallCount = 0
        loadHistoricalRatesCallCount = 0
        getEarliestStoredDateResult = nil
        getLatestStoredDateResult = nil
        lastFetchDate = nil
        historicalDataToReturn = []
        exchangeRatesToReturn = []
        trendDataToReturn = []
        fetchAndSaveHistoricalRatesCalls = []
        loadHistoricalRatesForCurrencyCalls = []
        shouldThrowErrorOnFetch = false
        shouldThrowErrorOnLoad = false
        errorToThrow = AppError.networkError("Mock error")
    }
}

/// Mock implementation of CacheService for testing DataOrchestrationUseCase
actor MockCacheServiceForOrchestration: CacheService {
    // MARK: - Test Configuration Properties

    private var cachedExchangeRates: [ExchangeRateDataValue]?
    private var cachedHistoricalData: [String: [HistoricalRateDataValue]] = [:]
    private var cachedTrendData: [TrendDataValue]?

    // Call tracking
    private(set) var cacheHistoricalDataCallCount = 0
    private(set) var getCachedHistoricalDataCallCount = 0
    private(set) var clearCacheCallCount = 0

    // MARK: - CacheService Implementation

    func cacheExchangeRates(_ rates: [ExchangeRateDataValue]) async {
        cachedExchangeRates = rates
    }

    func getCachedExchangeRates() async -> [ExchangeRateDataValue]? {
        cachedExchangeRates
    }

    func cacheHistoricalData(_ data: [HistoricalRateDataValue], for currency: String) async {
        cacheHistoricalDataCallCount += 1
        cachedHistoricalData[currency] = data
    }

    func getCachedHistoricalData(for currency: String) async -> [HistoricalRateDataValue]? {
        getCachedHistoricalDataCallCount += 1
        return cachedHistoricalData[currency]
    }

    func cacheTrendData(_ trends: [TrendDataValue]) async {
        cachedTrendData = trends
    }

    func getCachedTrendData() async -> [TrendDataValue]? {
        cachedTrendData
    }

    func clearCache() async {
        clearCacheCallCount += 1
        cachedExchangeRates = nil
        cachedHistoricalData.removeAll()
        cachedTrendData = nil
    }

    func cacheProcessedChartData(_: [ChartDataPoint], for _: String) async {
        // No-op for testing
    }

    func getCachedProcessedChartData(for _: String) async -> [ChartDataPoint]? {
        nil // Always return nil for testing to force recalculation
    }

    // MARK: - Test Helper Methods

    func reset() async {
        cachedExchangeRates = nil
        cachedHistoricalData.removeAll()
        cachedTrendData = nil
        cacheHistoricalDataCallCount = 0
        getCachedHistoricalDataCallCount = 0
        clearCacheCallCount = 0
    }

    func setCachedHistoricalData(_ data: [HistoricalRateDataValue], for currency: String) async {
        cachedHistoricalData[currency] = data
    }
}

// MARK: - Test Suite

@Suite("DataOrchestrationUseCase Tests")
struct DataOrchestrationUseCaseTests {
    // MARK: - Test Data

    static let testCurrency = "EUR"
    static let baseDate = Date()
    static let calendar = TimeZoneManager.cetCalendar

    // Create consistent test dates
    static let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: baseDate) ?? baseDate)
    static let endDate = calendar.startOfDay(for: baseDate)
    static let testDateRange = DateRange(start: startDate, end: endDate)

    // MARK: - Test Helper Methods

    /// Creates test historical data for specified dates
    static func createTestHistoricalData(dates: [Date]) -> [HistoricalRateDataValue] {
        dates.map { date in
            let rates = [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 0.85),
                HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.75),
                HistoricalRateDataPointValue(currencyCode: "JPY", rate: 110.0),
            ]
            return HistoricalRateDataValue(date: date, rates: rates)
        }
    }

    /// Creates a date range with specified number of days before the base date
    static func createDateRange(daysBefore: Int) -> DateRange {
        let start = calendar.date(byAdding: .day, value: -daysBefore, to: baseDate) ?? baseDate
        return DateRange(start: calendar.startOfDay(for: start), end: endDate)
    }

    // MARK: - loadHistoricalData Tests

    @Test("loadHistoricalData should return cached data when cache covers entire range")
    func loadHistoricalData_cacheHit_shouldReturnCachedData() async throws {
        // GIVEN: Mocks configured for cache hit scenario
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        let cachedData = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        await mockCacheService.setCachedHistoricalData(cachedData, for: Self.testCurrency)

        // Configure mock to return no missing ranges (cache hit)
        // Configure cache to cover entire range (cache hit scenario)

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Loading historical data
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        // THEN: Should return cached data without API calls
        #expect(result.dataPoints == cachedData)
        #expect(result.newDataFetched == false)
        #expect(mockService.fetchAndSaveHistoricalRatesCallCount == 0)
        #expect(mockService.loadHistoricalRatesCallCount == 0)
        // Real analysis use case used - can't verify call counts
    }

    @Test("loadHistoricalData should fetch missing data and merge with cache")
    func loadHistoricalData_partialCacheMiss_shouldFetchAndMerge() async throws {
        // GIVEN: Mocks configured for partial cache miss
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        let existingCachedData = Self.createTestHistoricalData(dates: [Self.startDate])
        await mockCacheService.setCachedHistoricalData(existingCachedData, for: Self.testCurrency)

        let missingRange = DateRange(start: Self.calendar.date(byAdding: .day, value: 1, to: Self.startDate) ?? Self.startDate, end: Self.endDate)
        // Real analysis use case will determine missing ranges based on cached data

        let newDataFromAPI = Self.createTestHistoricalData(dates: [Self.endDate])
        mockService.historicalDataToReturn = newDataFromAPI
        mockService.getEarliestStoredDateResult = nil // Force fetch from API

        // Real analysis use case will merge the data properly

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Loading historical data
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        // THEN: Should fetch missing data and merge
        #expect(result.newDataFetched == true)
        #expect(!result.dataPoints.isEmpty) // Real use case will merge appropriately
        #expect(mockService.fetchAndSaveHistoricalRatesCallCount == 1)
        #expect(mockService.loadHistoricalRatesCallCount == 1)
        // Real analysis use case used - can't verify call counts

        // Verify API calls
        #expect(mockService.fetchAndSaveHistoricalRatesCalls.count == 1)
        let fetchCall = mockService.fetchAndSaveHistoricalRatesCalls[0]
        #expect(fetchCall.from == missingRange.start)
        #expect(fetchCall.to == missingRange.end)

        // Verify cache was updated
        #expect(await mockCacheService.cacheHistoricalDataCallCount == 1)
    }

    @Test("loadHistoricalData should fetch all data when no cache exists")
    func loadHistoricalData_noCacheExists_shouldFetchAllData() async throws {
        // GIVEN: Mocks configured for no cache scenario
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        // No cached data exists
        // Real analysis use case will determine missing ranges

        let newDataFromAPI = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        mockService.historicalDataToReturn = newDataFromAPI
        mockService.getEarliestStoredDateResult = nil // Force fetch from API

        // Real analysis use case will merge data properly

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Loading historical data
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        // THEN: Should fetch all data
        #expect(result.newDataFetched == true)
        #expect(!result.dataPoints.isEmpty) // Real use case will provide merged data
        #expect(mockService.fetchAndSaveHistoricalRatesCallCount == 1)
        #expect(mockService.loadHistoricalRatesCallCount == 1)

        // Real analysis use case used - can't verify internal merge calls
    }

    @Test("loadHistoricalData should skip API fetch when SwiftData has required data")
    func loadHistoricalData_swiftDataHasData_shouldSkipApiFetch() async throws {
        // GIVEN: Mocks configured to simulate SwiftData having required data
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        // Real analysis use case will determine missing ranges based on cached data

        // Configure service to indicate SwiftData has the data (earliest stored date covers the range)
        let earlierDate = Self.calendar.date(byAdding: .day, value: -10, to: Self.startDate) ?? Self.startDate
        let laterDate = Self.calendar.date(byAdding: .day, value: 10, to: Self.endDate) ?? Self.endDate
        mockService.getEarliestStoredDateResult = earlierDate
        mockService.getLatestStoredDateResult = laterDate

        let existingDataFromSwiftData = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        mockService.historicalDataToReturn = existingDataFromSwiftData

        // Real analysis use case will merge data properly

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Loading historical data
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        // THEN: Should load from SwiftData without API fetch
        #expect(result.newDataFetched == false)
        #expect(!result.dataPoints.isEmpty) // Real use case will provide data
        #expect(mockService.fetchAndSaveHistoricalRatesCallCount == 0) // No API fetch
        #expect(mockService.loadHistoricalRatesCallCount == 1) // Load from SwiftData
    }

    @Test("loadHistoricalData fetches a separate range for each genuine gap before and after the cache")
    func loadHistoricalData_multipleMissingRanges_shouldFetchEachGap() async throws {
        // GIVEN: a wide required range with a small cached island in the middle, so the real
        // analysis produces TWO genuine gaps — one before the cache (>4 days) and one after it.
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        let requiredRange = DateRange(start: day(-20), end: day(0))
        let cacheDates = [day(-10), day(-9), day(-8)] // sorted ascending; CurrencyCache trusts sort order
        await mockCacheService.setCachedHistoricalData(
            Self.createTestHistoricalData(dates: cacheDates), for: Self.testCurrency
        )

        mockService.getEarliestStoredDateResult = nil // force an API fetch for each gap
        mockService.historicalDataToReturn = []

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: loading the wide range
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: requiredRange)

        // THEN: exactly two distinct fetches and loads — the multi-range path is genuinely exercised.
        #expect(result.newDataFetched == true)
        #expect(mockService.fetchAndSaveHistoricalRatesCallCount == 2)
        #expect(mockService.loadHistoricalRatesCallCount == 2)

        let calls = mockService.fetchAndSaveHistoricalRatesCalls.sorted { $0.from < $1.from }
        #expect(calls.count == 2)
        #expect(calls.first?.from == day(-20)) // before-gap starts at the required start
        #expect(calls.last?.to == day(0)) // after-gap ends at the required end
        if let beforeGap = calls.first, let afterGap = calls.last {
            #expect(beforeGap.to < afterGap.from) // the two gaps are disjoint
        }
    }

    @Test("loadHistoricalData degrades to cached data when every fetch fails")
    func loadHistoricalData_networkError_returnsCachedData() async throws {
        // GIVEN: a cached island inside a wide range, so real gaps trigger fetches that all fail,
        // yet recoverable cached data exists to fall back on.
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        let requiredRange = DateRange(start: day(-20), end: day(0))
        let cachedData = Self.createTestHistoricalData(dates: [day(-10), day(-9), day(-8)])
        await mockCacheService.setCachedHistoricalData(cachedData, for: Self.testCurrency)

        mockService.getEarliestStoredDateResult = nil
        mockService.historicalDataToReturn = []
        mockService.shouldThrowErrorOnFetch = true
        mockService.errorToThrow = AppError.networkError("Test network error")

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: loading with every fetch failing
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: requiredRange)

        // THEN: a fetch was attempted, but the cached island survives and nothing is reported as fetched.
        #expect(mockService.fetchAndSaveHistoricalRatesCallCount >= 1)
        #expect(result.newDataFetched == false)
        #expect(result.dataPoints == cachedData)
    }

    // MARK: - getCachedData Tests

    @Test("getCachedData should return filtered cached data within date range")
    func getCachedData_withCachedData_shouldReturnFilteredData() async throws {
        // GIVEN: Cached data with dates both inside and outside the range
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        let dateBeforeRange = Self.calendar.date(byAdding: .day, value: -10, to: Self.startDate) ?? Self.startDate
        let dateInRange = Self.startDate
        let dateAfterRange = Self.calendar.date(byAdding: .day, value: 1, to: Self.endDate) ?? Self.endDate

        let allCachedData = Self.createTestHistoricalData(dates: [dateBeforeRange, dateInRange, dateAfterRange])
        await mockCacheService.setCachedHistoricalData(allCachedData, for: Self.testCurrency)

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Getting cached data for specific range
        let result = await useCase.getCachedData(for: Self.testCurrency, dateRange: Self.testDateRange)

        // THEN: Should return only data within the range
        #expect(result.count == 1)
        #expect(result[0].date == dateInRange)
        #expect(await mockCacheService.getCachedHistoricalDataCallCount == 1)
    }

    @Test("getCachedData should return empty array when no cached data exists")
    func getCachedData_noCachedData_shouldReturnEmptyArray() async throws {
        // GIVEN: No cached data
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Getting cached data
        let result = await useCase.getCachedData(for: Self.testCurrency, dateRange: Self.testDateRange)

        // THEN: Should return empty array
        #expect(result.isEmpty)
        #expect(await mockCacheService.getCachedHistoricalDataCallCount == 1)
    }

    @Test("getCachedData should handle inclusive date range boundaries correctly")
    func getCachedData_inclusiveBoundaries_shouldIncludeBoundaryDates() async throws {
        // GIVEN: Cached data exactly on range boundaries
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        let boundaryData = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        await mockCacheService.setCachedHistoricalData(boundaryData, for: Self.testCurrency)

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Getting cached data for exact range
        let result = await useCase.getCachedData(for: Self.testCurrency, dateRange: Self.testDateRange)

        // THEN: Should include both boundary dates
        #expect(result.count == 2)
        #expect(result.contains { $0.date == Self.startDate })
        #expect(result.contains { $0.date == Self.endDate })
    }

    // MARK: - clearAllCache Tests

    @Test("clearAllCache should delegate to cache service")
    func clearAllCache_shouldDelegateToService() async throws {
        // GIVEN: Use case with mock cache service
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Clearing all cache
        await useCase.clearAllCache()

        // THEN: Should delegate to cache service
        #expect(await mockCacheService.clearCacheCallCount == 1)
    }

    // MARK: - shouldFetchMissingData Tests (Private method tested through loadHistoricalData behavior)

    @Test("loadHistoricalData should fetch when no stored date exists")
    func loadHistoricalData_noStoredDate_shouldFetch() async throws {
        // GIVEN: Service returns nil for earliest stored date
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        // Real analysis use case will determine missing ranges
        mockService.getEarliestStoredDateResult = nil // No stored data
        mockService.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate])
        // Real analysis use case will merge data properly

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Loading historical data
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        // THEN: Should fetch from API
        #expect(result.newDataFetched == true)
        #expect(mockService.fetchAndSaveHistoricalRatesCallCount == 1)
    }

    @Test("loadHistoricalData should not fetch when stored data covers required range")
    func loadHistoricalData_storedDataCoversRange_shouldNotFetch() async throws {
        // GIVEN: Service returns stored date that covers the required range
        let mockService = MockExchangeRateServiceForOrchestration()
        let mockCacheService = MockCacheServiceForOrchestration()
        let realAnalysisUseCase = HistoricalDataAnalysisUseCase()

        // Real analysis use case will determine missing ranges

        // Stored date is earlier than required start date
        let earlierStoredDate = Self.calendar.date(byAdding: .day, value: -10, to: Self.startDate) ?? Self.startDate
        let laterStoredDate = Self.calendar.date(byAdding: .day, value: 10, to: Self.endDate) ?? Self.endDate
        mockService.getEarliestStoredDateResult = earlierStoredDate
        mockService.getLatestStoredDateResult = laterStoredDate

        mockService.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate])
        // Real analysis use case will merge data properly

        let useCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: realAnalysisUseCase,
            cacheService: mockCacheService
        )

        // WHEN: Loading historical data
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        // THEN: Should not fetch from API (loads from SwiftData instead)
        #expect(result.newDataFetched == false)
        #expect(mockService.fetchAndSaveHistoricalRatesCallCount == 0)
        #expect(mockService.loadHistoricalRatesCallCount == 1)
    }
}
