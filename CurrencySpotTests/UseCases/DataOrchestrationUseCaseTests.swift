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
        repository.seedCache(cachedData)

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.dataPoints == cachedData)
        #expect(result.newDataFetched == false)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.loadHistoricalRatesCallCount == 0)
    }

    @Test("loadHistoricalData should fetch missing data and merge with cache")
    func loadHistoricalData_partialCacheMiss_shouldFetchAndMerge() async throws {
        let repository = MockHistoricalRateRepository()
        let existingCachedData = Self.createTestHistoricalData(dates: [Self.startDate])
        repository.seedCache(existingCachedData)

        let missingRange = DateRange(start: Self.calendar.date(byAdding: .day, value: 1, to: Self.startDate) ?? Self.startDate, end: Self.endDate)

        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.endDate])
        repository.earliestStoredDateResult = nil // Force fetch from API

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(result.dataPoints.count == 2) // cached island + fetched day
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        // Render-first: the fetched snapshots are the data — no persistence read-back.
        #expect(repository.loadHistoricalRatesCallCount == 0)

        // Verify API calls
        let fetchCall = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(fetchCall.from == missingRange.start)
        #expect(fetchCall.to == missingRange.end)

        // Verify the repository's cache was updated
        #expect(repository.mergeCachedCallCount == 1)
    }

    @Test("data loaded for one currency serves any other currency from the shared cache")
    func loadHistoricalData_sharedCacheServesOtherCurrencies() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil // force the first load to fetch
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        let useCase = Self.makeUseCase(repository: repository)

        _ = try await useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)
        let second = try await useCase.loadHistoricalData(for: "GBP", dateRange: Self.testDateRange)

        // Every fetch returns all currencies, so the snapshots cached by EUR's load
        // must serve GBP without touching the network or persistence.
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(repository.loadHistoricalRatesCallCount == 0)
        #expect(second.newDataFetched == false)
        #expect(second.dataPoints.count == 2)
    }

    @Test("concurrent loads for the same range share one network fetch", .timeLimit(.minutes(1)))
    func concurrentLoads_sameRange_shareOneFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil // force fetching
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        // Hold the first fetch open until the test releases the gate.
        var releaseFetch: (() -> Void)!
        let gate = AsyncStream<Void> { continuation in
            releaseFetch = { continuation.finish() }
        }
        repository.fetchBarrier = { for await _ in gate {} }

        let useCase = Self.makeUseCase(repository: repository)

        async let first = useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)
        async let second = useCase.loadHistoricalData(for: "GBP", dateRange: Self.testDateRange)

        // Let both loads reach the fetch point (everything runs on the main actor,
        // so yielding drains all ready work until both are parked on the gate).
        while repository.cachedReadCount < 2 {
            await Task.yield()
        }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        releaseFetch()

        let results = try await (first, second)

        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(results.0.dataPoints.count == 2)
        #expect(results.1.dataPoints.count == 2)
    }

    @Test("concurrent loads for disjoint ranges union their rows instead of clobbering", .timeLimit(.minutes(1)))
    func concurrentDisjointLoads_unionTheirRows() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        // Disjoint ranges so neither fetch subsumes the other: both must land in the cache.
        let oldRange = DateRange(start: day(-30), end: day(-20))
        let recentRange = DateRange(start: day(-7), end: day(0))
        repository.fetchedDataProvider = { from, _ in
            Self.createTestHistoricalData(dates: [from])
        }

        var releaseFetches: (() -> Void)!
        let gate = AsyncStream<Void> { continuation in
            releaseFetches = { continuation.finish() }
        }
        repository.fetchBarrier = { for await _ in gate {} }

        let useCase = Self.makeUseCase(repository: repository)

        async let old = useCase.loadHistoricalData(for: "EUR", dateRange: oldRange)
        async let recent = useCase.loadHistoricalData(for: "EUR", dateRange: recentRange)

        // Park both fetches on the gate, then let them complete together so the
        // two merges interleave.
        while repository.fetchHistoricalRatesCallCount < 2 {
            await Task.yield()
        }
        releaseFetches()
        _ = try await (old, recent)

        // Both loads' rows survive in the shared series — no last-writer-wins loss.
        let cachedDates = Set(repository.cachedData.map(\.date))
        #expect(cachedDates.contains(oldRange.start))
        #expect(cachedDates.contains(recentRange.start))
    }

    @Test("a narrower load joins a covering in-flight fetch instead of refetching", .timeLimit(.minutes(1)))
    func narrowLoad_joinsCoveringInFlightFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        var releaseFetch: (() -> Void)!
        let gate = AsyncStream<Void> { continuation in
            releaseFetch = { continuation.finish() }
        }
        repository.fetchBarrier = { for await _ in gate {} }

        let useCase = Self.makeUseCase(repository: repository)

        // Wide load (e.g. the launch prefetch) starts first…
        let wideRange = DateRange(
            start: Self.calendar.date(byAdding: .day, value: -30, to: Self.endDate)!,
            end: Self.endDate
        )
        async let wide = useCase.loadHistoricalData(for: "USD", dateRange: wideRange)
        // …then a narrower user-tap load arrives while the wide fetch is in flight.
        async let narrow = useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)

        while repository.cachedReadCount < 2 {
            await Task.yield()
        }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        releaseFetch()

        _ = try await (wide, narrow)

        // The narrow range is inside the wide in-flight fetch, so exactly one request.
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        let call = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(call.from == wideRange.start)
        #expect(call.to == wideRange.end)
    }

    @Test("loadHistoricalData should fetch all data when no cache exists")
    func loadHistoricalData_noCacheExists_shouldFetchAllData() async throws {
        let repository = MockHistoricalRateRepository()
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        repository.earliestStoredDateResult = nil // Force fetch from API

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(result.dataPoints.isEmpty == false)
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(repository.loadHistoricalRatesCallCount == 0)
    }

    @Test("a new day's load fetches only the missing edge, not the whole window")
    func newDayLoad_fetchesOnlyTheGap() async throws {
        let repository = MockHistoricalRateRepository()

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        // The previous day's warm-up stored and recorded a year through yesterday.
        repository.earliestStoredDateResult = day(-365)
        repository.latestStoredDateResult = day(-1)
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [day(-2), day(-1)])
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [day(0)])
        let syncStore = MockHistoricalSyncStore(from: day(-365), through: day(-1), checkedAt: day(-1))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let yearRange = DateRange(start: day(-365), end: day(0))
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: yearRange)

        // Only [yesterday, today] hits the network; the year reads from persistence.
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        let call = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(call.from == day(-1))
        #expect(call.to == day(0))
        #expect(repository.loadHistoricalRatesCallCount == 1)
        #expect(result.newDataFetched == true)
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
        #expect(repository.fetchHistoricalRatesCallCount == 0) // No API fetch
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
        repository.seedCache(Self.createTestHistoricalData(dates: cacheDates))

        repository.earliestStoredDateResult = nil // force an API fetch for each gap

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: requiredRange)

        // THEN: exactly two distinct fetches and zero read-backs — fetched snapshots are used directly.
        #expect(result.newDataFetched == true)
        #expect(repository.fetchHistoricalRatesCallCount == 2)
        #expect(repository.loadHistoricalRatesCallCount == 0)

        let calls = repository.fetchHistoricalRatesCalls.sorted { $0.from < $1.from }
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
        repository.seedCache(cachedData)

        repository.earliestStoredDateResult = nil
        repository.historicalDataToReturn = []
        repository.shouldThrowErrorOnFetch = true
        repository.errorToThrow = AppError.networkError("Test network error")

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: requiredRange)

        // THEN: fetches were attempted, each failure fell back to a persistence read,
        // the cached island survives, and nothing is reported as fetched.
        #expect(repository.fetchHistoricalRatesCallCount >= 1)
        #expect(repository.loadHistoricalRatesCallCount == repository.fetchHistoricalRatesCallCount)
        #expect(result.newDataFetched == false)
        #expect(result.dataPoints == cachedData)
    }

    // NOTE: Sync-coverage watermark recording now lives with the deferred persist in
    // DataCoordinator (record only after the save commits) and is covered by
    // DataCoordinatorHistoricalTests.

    // MARK: - getCachedData Tests

    @Test("getCachedData should return filtered cached data within date range")
    func getCachedData_withCachedData_shouldReturnFilteredData() async throws {
        let repository = MockHistoricalRateRepository()

        let dateBeforeRange = Self.calendar.date(byAdding: .day, value: -10, to: Self.startDate) ?? Self.startDate
        let dateInRange = Self.startDate
        let dateAfterRange = Self.calendar.date(byAdding: .day, value: 1, to: Self.endDate) ?? Self.endDate

        let allCachedData = Self.createTestHistoricalData(dates: [dateBeforeRange, dateInRange, dateAfterRange])
        repository.seedCache(allCachedData)

        let useCase = Self.makeUseCase(repository: repository)

        let result = await useCase.getCachedData(dateRange: Self.testDateRange)

        #expect(result.count == 1)
        #expect(result[0].date == dateInRange)
        #expect(repository.cachedReadCount == 1)
    }

    @Test("getCachedData should return empty array when no cached data exists")
    func getCachedData_noCachedData_shouldReturnEmptyArray() async throws {
        let repository = MockHistoricalRateRepository()
        let useCase = Self.makeUseCase(repository: repository)

        let result = await useCase.getCachedData(dateRange: Self.testDateRange)

        #expect(result.isEmpty)
        #expect(repository.cachedReadCount == 1)
    }

    @Test("getCachedData should handle inclusive date range boundaries correctly")
    func getCachedData_inclusiveBoundaries_shouldIncludeBoundaryDates() async throws {
        let repository = MockHistoricalRateRepository()
        let boundaryData = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        repository.seedCache(boundaryData)

        let useCase = Self.makeUseCase(repository: repository)

        let result = await useCase.getCachedData(dateRange: Self.testDateRange)

        #expect(result.count == 2)
        #expect(result.contains { $0.date == Self.startDate })
        #expect(result.contains { $0.date == Self.endDate })
    }

    // MARK: - shouldFetchMissingData Tests (Private method tested through loadHistoricalData behavior)

    @Test("loadHistoricalData should fetch when no stored date exists")
    func loadHistoricalData_noStoredDate_shouldFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil // No stored data
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate])

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(repository.fetchHistoricalRatesCallCount == 1)
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
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.loadHistoricalRatesCallCount == 1)
    }
}
