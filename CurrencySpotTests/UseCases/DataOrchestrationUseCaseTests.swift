//
//  DataOrchestrationUseCaseTests.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/1/25.
//

@testable import CurrencySpot
import Foundation
import Testing

// MARK: - Test Suite

@Suite("DataOrchestrationUseCase Tests")
struct DataOrchestrationUseCaseTests {
    // MARK: - Test Data

    static let testCurrency: CurrencyCode = "EUR"
    /// Fixed anchor (Wednesday, midnight CET) so fixtures never depend on the wall clock.
    static let baseDate = createCETDate(year: 2025, month: 1, day: 15)!
    static let calendar = TimeZoneManager.cetCalendar

    // Create consistent test dates
    static let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: baseDate) ?? baseDate)
    static let endDate = calendar.startOfDay(for: baseDate)
    static let testDateRange = DateRange(start: startDate, end: endDate)

    // MARK: - Test Helper Methods

    private static func makeUseCase(
        repository: MockHistoricalRateRepository,
        syncStore: MockHistoricalSyncStore = MockHistoricalSyncStore()
    ) -> DataOrchestrationUseCase {
        DataOrchestrationUseCase(
            repository: repository,
            historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase(syncStore: syncStore),
            dateProvider: FixedDateProvider(baseDate)
        )
    }

    /// Creates test historical data for specified dates
    static func createTestHistoricalData(dates: [Date]) -> [HistoricalRateSnapshot] {
        dates.map { date in
            let rates = [
                HistoricalRatePoint(currencyCode: "EUR", rate: 0.85),
                HistoricalRatePoint(currencyCode: "GBP", rate: 0.75),
                HistoricalRatePoint(currencyCode: "JPY", rate: 110.0),
            ]
            return HistoricalRateSnapshot(date: date, rates: rates)
        }
    }

    // MARK: - loadHistoricalData Tests

    @Test("loadHistoricalData should return cached data when cache covers entire range")
    func loadHistoricalData_cacheHit_shouldReturnCachedData() async throws {
        let repository = MockHistoricalRateRepository()
        let cachedData = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        repository.seedCache(cachedData, for: Self.testCurrency)

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.dataPoints == cachedData)
        #expect(result.newDataFetched == false)
        #expect(repository.fetchAndSaveHistoricalRatesCallCount == 0)
        #expect(repository.loadHistoricalRatesCallCount == 0)
    }

    @Test("loadHistoricalData should fetch missing data and merge with cache")
    func loadHistoricalData_partialCacheMiss_shouldFetchAndMerge() async throws {
        let repository = MockHistoricalRateRepository()
        let existingCachedData = Self.createTestHistoricalData(dates: [Self.startDate])
        repository.seedCache(existingCachedData, for: Self.testCurrency)

        let missingRange = DateRange(start: Self.calendar.date(byAdding: .day, value: 1, to: Self.startDate) ?? Self.startDate, end: Self.endDate)

        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.endDate])
        repository.earliestStoredDateResult = nil // Force fetch from API

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(result.dataPoints.isEmpty == false)
        #expect(repository.fetchAndSaveHistoricalRatesCallCount == 1)
        #expect(repository.loadHistoricalRatesCallCount == 1)

        // Verify API calls
        let fetchCall = try #require(repository.fetchAndSaveHistoricalRatesCalls.first)
        #expect(fetchCall.from == missingRange.start)
        #expect(fetchCall.to == missingRange.end)

        // Verify the repository's cache was updated
        #expect(repository.replaceCachedCallCount == 1)
    }

    @Test("loadHistoricalData should fetch all data when no cache exists")
    func loadHistoricalData_noCacheExists_shouldFetchAllData() async throws {
        let repository = MockHistoricalRateRepository()
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        repository.earliestStoredDateResult = nil // Force fetch from API

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(result.dataPoints.isEmpty == false)
        #expect(repository.fetchAndSaveHistoricalRatesCallCount == 1)
        #expect(repository.loadHistoricalRatesCallCount == 1)
    }

    @Test("loadHistoricalData should skip API fetch when SwiftData has required data")
    func loadHistoricalData_swiftDataHasData_shouldSkipApiFetch() async throws {
        let repository = MockHistoricalRateRepository()

        // Stored bounds cover the required range → no API fetch.
        repository.earliestStoredDateResult = Self.calendar.date(byAdding: .day, value: -10, to: Self.startDate)
        repository.latestStoredDateResult = Self.calendar.date(byAdding: .day, value: 10, to: Self.endDate)
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == false)
        #expect(result.dataPoints.isEmpty == false)
        #expect(repository.fetchAndSaveHistoricalRatesCallCount == 0) // No API fetch
        #expect(repository.loadHistoricalRatesCallCount == 1) // Load from SwiftData
    }

    @Test("loadHistoricalData fetches a separate range for each genuine gap before and after the cache")
    func loadHistoricalData_multipleMissingRanges_shouldFetchEachGap() async throws {
        // GIVEN: a wide required range with a small cached island in the middle, so the real
        // analysis produces TWO genuine gaps — one before the cache and one after it.
        let repository = MockHistoricalRateRepository()

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        let requiredRange = DateRange(start: day(-20), end: day(0))
        let cacheDates = [day(-10), day(-9), day(-8)] // sorted ascending; CurrencyCache trusts sort order
        repository.seedCache(Self.createTestHistoricalData(dates: cacheDates), for: Self.testCurrency)

        repository.earliestStoredDateResult = nil // force an API fetch for each gap
        repository.historicalDataToReturn = []

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: requiredRange)

        // THEN: exactly two distinct fetches and loads — the multi-range path is genuinely exercised.
        #expect(result.newDataFetched == true)
        #expect(repository.fetchAndSaveHistoricalRatesCallCount == 2)
        #expect(repository.loadHistoricalRatesCallCount == 2)

        let calls = repository.fetchAndSaveHistoricalRatesCalls.sorted { $0.from < $1.from }
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
        let repository = MockHistoricalRateRepository()

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        let requiredRange = DateRange(start: day(-20), end: day(0))
        let cachedData = Self.createTestHistoricalData(dates: [day(-10), day(-9), day(-8)])
        repository.seedCache(cachedData, for: Self.testCurrency)

        repository.earliestStoredDateResult = nil
        repository.historicalDataToReturn = []
        repository.shouldThrowErrorOnFetch = true
        repository.errorToThrow = AppError.networkError("Test network error")

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: requiredRange)

        // THEN: a fetch was attempted, but the cached island survives and nothing is reported as fetched.
        #expect(repository.fetchAndSaveHistoricalRatesCallCount >= 1)
        #expect(result.newDataFetched == false)
        #expect(result.dataPoints == cachedData)
    }

    // MARK: - Sync-coverage watermark Tests

    @Test("a cold-cache fetch records the synced coverage window")
    func loadHistoricalData_coldFetch_recordsSyncCoverage() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = MockHistoricalSyncStore()

        repository.earliestStoredDateResult = nil // force an API fetch
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.endDate])

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        _ = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(syncStore.recordCallCount == 1)
        #expect(syncStore.through == Self.testDateRange.end)
    }

    @Test("an empty fetch response still records coverage so empty days aren't refetched")
    func loadHistoricalData_emptyFetch_stillRecordsSyncCoverage() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = MockHistoricalSyncStore()

        repository.earliestStoredDateResult = nil // force a fetch
        repository.historicalDataToReturn = [] // v2 had no data for the range

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        _ = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(syncStore.recordCallCount == 1)
        #expect(syncStore.through == Self.testDateRange.end)
    }

    @Test("a SwiftData-covered load does not advance the sync watermark")
    func loadHistoricalData_swiftDataCovered_doesNotRecordSync() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = MockHistoricalSyncStore()

        // SwiftData already covers the required range → no API fetch.
        repository.earliestStoredDateResult = Self.calendar.date(byAdding: .day, value: -10, to: Self.startDate)
        repository.latestStoredDateResult = Self.calendar.date(byAdding: .day, value: 10, to: Self.endDate)
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        _ = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(repository.fetchAndSaveHistoricalRatesCallCount == 0)
        #expect(syncStore.recordCallCount == 0)
    }

    // MARK: - getCachedData Tests

    @Test("getCachedData should return filtered cached data within date range")
    func getCachedData_withCachedData_shouldReturnFilteredData() async throws {
        let repository = MockHistoricalRateRepository()

        let dateBeforeRange = Self.calendar.date(byAdding: .day, value: -10, to: Self.startDate) ?? Self.startDate
        let dateInRange = Self.startDate
        let dateAfterRange = Self.calendar.date(byAdding: .day, value: 1, to: Self.endDate) ?? Self.endDate

        let allCachedData = Self.createTestHistoricalData(dates: [dateBeforeRange, dateInRange, dateAfterRange])
        repository.seedCache(allCachedData, for: Self.testCurrency)

        let useCase = Self.makeUseCase(repository: repository)

        let result = await useCase.getCachedData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.count == 1)
        #expect(result[0].date == dateInRange)
        #expect(repository.cachedReadCount == 1)
    }

    @Test("getCachedData should return empty array when no cached data exists")
    func getCachedData_noCachedData_shouldReturnEmptyArray() async throws {
        let repository = MockHistoricalRateRepository()
        let useCase = Self.makeUseCase(repository: repository)

        let result = await useCase.getCachedData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.isEmpty)
        #expect(repository.cachedReadCount == 1)
    }

    @Test("getCachedData should handle inclusive date range boundaries correctly")
    func getCachedData_inclusiveBoundaries_shouldIncludeBoundaryDates() async throws {
        let repository = MockHistoricalRateRepository()
        let boundaryData = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        repository.seedCache(boundaryData, for: Self.testCurrency)

        let useCase = Self.makeUseCase(repository: repository)

        let result = await useCase.getCachedData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.count == 2)
        #expect(result.contains { $0.date == Self.startDate })
        #expect(result.contains { $0.date == Self.endDate })
    }

    // MARK: - shouldFetchMissingData Tests (Private method tested through loadHistoricalData behavior)

    @Test("loadHistoricalData should fetch when no stored date exists")
    func loadHistoricalData_noStoredDate_shouldFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil // No stored data
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate])

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(repository.fetchAndSaveHistoricalRatesCallCount == 1)
    }

    @Test("loadHistoricalData should not fetch when stored data covers required range")
    func loadHistoricalData_storedDataCoversRange_shouldNotFetch() async throws {
        let repository = MockHistoricalRateRepository()

        repository.earliestStoredDateResult = Self.calendar.date(byAdding: .day, value: -10, to: Self.startDate)
        repository.latestStoredDateResult = Self.calendar.date(byAdding: .day, value: 10, to: Self.endDate)
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate])

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == false)
        #expect(repository.fetchAndSaveHistoricalRatesCallCount == 0)
        #expect(repository.loadHistoricalRatesCallCount == 1)
    }
}
