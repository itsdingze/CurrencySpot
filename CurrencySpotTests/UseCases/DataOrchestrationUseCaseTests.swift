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
            historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase(
                syncStore: syncStore,
                dateProvider: FixedDateProvider(baseDate)
            ),
            dateProvider: FixedDateProvider(baseDate),
            clock: ImmediateClock()
        )
    }

    private static func day(_ offset: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: baseDate)!)
    }

    /// A five-year, today-anchored range — beyond the resident window.
    private static let archiveRange = DateRange(start: day(-1827), end: day(0))

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

    // MARK: - Archive range Tests

    @Test("a covered archive range loads from the blob store without touching the resident series")
    func archiveRange_covered_loadsFromStore() async throws {
        let repository = MockHistoricalRateRepository()
        let blobRows = Self.createTestHistoricalData(dates: [Self.day(-1000), Self.day(-1)])
        repository.historicalDataToReturn = blobRows
        // The backfill already recorded the full five years.
        let syncStore = MockHistoricalSyncStore(from: Self.day(-1827), through: Self.day(0), checkedAt: Self.day(0))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(result.dataPoints == blobRows)
        #expect(result.newDataFetched == false)
        #expect(repository.loadHistoricalRatesCallCount == 1)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.fetchTransientCalls.isEmpty)
        // The archive must never inflate the resident in-memory series.
        #expect(repository.mergeCachedCallCount == 0)
        #expect(repository.cachedData.isEmpty)
    }

    @Test("an uncovered archive range bridges with a transient pair fetch, leaving every store untouched")
    func archiveRange_uncovered_bridgesWithTransientFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.transientDataToReturn = Self.createTestHistoricalData(dates: [Self.day(-1000)])
        // Only the resident year is covered so far.
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "GBP", dateRange: Self.archiveRange)

        #expect(result.dataPoints == repository.transientDataToReturn)
        #expect(result.newDataFetched == false) // nothing persisted: trends must not recalculate
        let transient = try #require(repository.fetchTransientCalls.first)
        #expect(Set(transient.currencies) == Set(["EUR", "GBP"] as [CurrencyCode]))
        #expect(transient.from == Self.archiveRange.start)
        #expect(transient.to == Self.archiveRange.end)
        // No all-currency fetch, no persistence read, no resident-series merge.
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.loadHistoricalRatesCallCount == 0)
        #expect(repository.mergeCachedCallCount == 0)
    }

    @Test("a USD pair's transient fetch requests only the non-USD side")
    func archiveRange_usdPair_requestsOnlyNonUSDQuote() async throws {
        let repository = MockHistoricalRateRepository()
        repository.transientDataToReturn = Self.createTestHistoricalData(dates: [Self.day(-1000)])

        let useCase = Self.makeUseCase(repository: repository)

        _ = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        let transient = try #require(repository.fetchTransientCalls.first)
        #expect(transient.currencies == ["EUR"]) // the rate table synthesizes USD's 1.0
    }

    // MARK: - backfillArchive Tests

    @Test("backfillArchive fetches the archive gap in adjacent half-year chunks, newest first")
    func backfillArchive_fetchesGapInChunks() async throws {
        let repository = MockHistoricalRateRepository()
        // The resident warm-up already stored and recorded the year.
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))
        repository.syncStoreForPersist = syncStore

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        // Cold origins generate multi-year series slower than the 30s resource
        // timeout allows; half-year slices stay comfortably inside it. The gap
        // [day(-1827), day(-365)] is 1463 days -> 8 chunks.
        let calls = repository.fetchAndPersistCalls
        #expect(calls.count == 8)
        // Newest-first, anchored at the stored edge, tiling without gaps…
        #expect(calls.first?.to == Self.day(-365))
        for (older, newer) in zip(calls.dropFirst(), calls) {
            #expect(older.to == Self.calendar.date(byAdding: .day, value: -1, to: newer.from))
        }
        // …reaching the archive start, with no chunk wider than the slice size.
        #expect(calls.last?.from == Self.archiveRange.start)
        for call in calls {
            let days = Self.calendar.dateComponents([.day], from: call.from, to: call.to).day ?? .max
            #expect(days < 183)
        }
        // Coverage landed, so no delayed re-run was needed.
        #expect(syncStore.from == Self.archiveRange.start)
        // Persist-only path: nothing touches the resident series.
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.mergeCachedCallCount == 0)
        #expect(repository.cachedData.isEmpty)
        #expect(repository.waitForPendingWritesCallCount >= 1)
    }

    @Test("a failed chunk stops the run and the delayed re-run resumes from where it left off", .timeLimit(.minutes(1)))
    func backfillArchive_failedChunkResumes() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))
        repository.syncStoreForPersist = syncStore
        repository.fetchAndPersistFailAtCall = 3 // the third chunk's fetch dies

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        // First run: 2 chunks landed and recorded, chunk 3 failed, no skipping
        // ahead. The (immediate-clock) re-run recomputes the gap from coverage and
        // fetches only the remaining 1097 days -> 6 chunks. 3 + 6 = 9 total.
        while repository.fetchAndPersistCalls.count < 9 {
            await Task.yield()
        }
        #expect(repository.fetchAndPersistCalls.count == 9)
        #expect(syncStore.from == Self.archiveRange.start) // archive fully covered
    }

    @Test("a chunk whose deferred save fails aborts the run; the re-run refetches instead of repairing over the hole", .timeLimit(.minutes(1)))
    func backfillArchive_failedPersistAbortsAndResumes() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))
        repository.syncStoreForPersist = syncStore
        repository.persistFailAtCall = 3 // the third chunk's deferred SAVE dies silently

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        // The run must stop at the unlanded chunk — fetching older chunks past a
        // silent save failure would let stored bounds span a hole that the
        // coverage repair then claims as covered, permanently.
        while repository.fetchAndPersistCalls.count < 9 {
            await Task.yield()
        }
        #expect(repository.fetchAndPersistCalls.count == 9) // 3 + the re-run's 6
        #expect(syncStore.from == Self.archiveRange.start) // re-fetched, not repaired over
    }

    @Test("delayed re-runs are bounded, not an infinite poll", .timeLimit(.minutes(1)))
    func backfillArchive_retriesAreBounded() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        repository.shouldThrowErrorOnFetch = true // persistently failing (e.g. offline)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        // Initial run + 2 budgeted re-runs, each dying on its first chunk.
        while repository.fetchAndPersistCalls.count < 3 {
            await Task.yield()
        }
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(repository.fetchAndPersistCalls.count == 3)
    }

    @Test("an archive view on the transient bridge kicks the backfill in the background", .timeLimit(.minutes(1)))
    func archiveBridge_kicksBackgroundBackfill() async throws {
        let repository = MockHistoricalRateRepository()
        repository.transientDataToReturn = Self.createTestHistoricalData(dates: [Self.day(-1000)])
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))
        repository.syncStoreForPersist = syncStore

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        // The user's view got its bridge data immediately…
        #expect(result.dataPoints == repository.transientDataToReturn)
        // …and the session heals itself: the backfill runs behind it until the
        // archive is fully covered.
        while repository.fetchAndPersistCalls.count < 8 {
            await Task.yield()
        }
        #expect(syncStore.from == Self.archiveRange.start)
    }

    @Test("backfillArchive is a no-op once the watermark covers the archive")
    func backfillArchive_skipsWhenCovered() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-1827)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-1827), through: Self.day(0), checkedAt: Self.day(0))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        #expect(repository.fetchAndPersistCalls.isEmpty)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(syncStore.recordCallCount == 0)
    }

    @Test("a resident load during the archive backfill never absorbs archive rows", .timeLimit(.minutes(1)))
    func backfill_concurrentResidentLoad_keepsResidentSeriesSmall() async throws {
        let repository = MockHistoricalRateRepository()
        // Degenerate warm-up: nothing stored, nothing recorded — the backfill's gap
        // is the whole five years, the worst case for a join.
        repository.earliestStoredDateResult = nil
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        var releaseFetches: (() -> Void)!
        let gate = AsyncStream<Void> { continuation in
            releaseFetches = { continuation.finish() }
        }
        repository.fetchBarrier = { for await _ in gate {} }

        let syncStore = MockHistoricalSyncStore()
        repository.syncStoreForPersist = syncStore
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        async let backfill: Void = useCase.backfillArchive()
        async let resident = useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)

        // The backfill now drains in-flight resident fetches before chunking, so it
        // won't touch the network until the resident fetch is released.
        while repository.fetchHistoricalRatesCalls.isEmpty {
            await Task.yield()
        }
        releaseFetches()
        _ = await backfill
        _ = try await resident

        // The resident load fetched its own range (no join with the archive fetch)
        // and the series holds only resident-window dates.
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        let residentFetch = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(residentFetch.from == Self.testDateRange.start)
        #expect(repository.cachedData.allSatisfy { $0.date >= Self.testDateRange.start && $0.date <= Self.testDateRange.end })
    }

    @Test("backfillArchive repairs a watermark that under-claims persisted rows")
    func backfillArchive_repairsUnderClaimingWatermark() async throws {
        let repository = MockHistoricalRateRepository()
        // Rows span the full archive, but the watermark only claims the last year
        // (e.g. the contiguity guard dropped a record at some point).
        repository.earliestStoredDateResult = Self.day(-1827)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        // Nothing to fetch (rows exist), but coverage is healed from stored bounds
        // so archive reads stop bridging over the network forever.
        #expect(repository.fetchAndPersistCalls.isEmpty)
        #expect(syncStore.recordCallCount == 1)
        #expect(syncStore.from == Self.day(-1827))
    }

    @Test("an archive covered through yesterday still reads from the blob store")
    func archiveRange_coveredThroughYesterday_loadsFromStore() async throws {
        let repository = MockHistoricalRateRepository()
        let blobRows = Self.createTestHistoricalData(dates: [Self.day(-1000), Self.day(-1)])
        repository.historicalDataToReturn = blobRows
        // The day's live-edge fetch hasn't run yet: the watermark ends at yesterday.
        let syncStore = MockHistoricalSyncStore(from: Self.day(-1827), through: Self.day(-1), checkedAt: Self.day(-1))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(result.dataPoints == blobRows)
        #expect(repository.fetchTransientCalls.isEmpty)
        #expect(repository.loadHistoricalRatesCallCount == 1)
    }

    @Test("a failed archive bridge falls back to a complete stored archive")
    func archiveRange_bridgeFails_servesStoredArchive() async throws {
        let repository = MockHistoricalRateRepository()
        let storedRows = Self.createTestHistoricalData(dates: [Self.day(-1000)])
        repository.historicalDataToReturn = storedRows
        repository.earliestStoredDateResult = Self.day(-1827) // archive reaches the range start
        repository.shouldThrowErrorOnFetch = true // the transient bridge is unreachable
        // Watermark missing entirely — coverage check fails, bridge is attempted.
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(repository.fetchTransientCalls.count == 1)
        #expect(result.dataPoints == storedRows)
        #expect(result.newDataFetched == false)
    }

    @Test("a failed bridge with only a partial archive on disk surfaces the error")
    func archiveRange_bridgeFailsPartialStore_throws() async throws {
        let repository = MockHistoricalRateRepository()
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.day(-300)])
        repository.earliestStoredDateResult = Self.day(-365) // only the resident year on disk
        repository.shouldThrowErrorOnFetch = true

        let useCase = Self.makeUseCase(repository: repository)

        // Rendering one stored year as a loaded 5Y chart would mask the failure;
        // the error must reach the ViewModel's archive guard instead.
        await #expect(throws: (any Error).self) {
            _ = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)
        }
    }

    @Test("a load after dropInFlightFetches re-fetches instead of joining a doomed fetch", .timeLimit(.minutes(1)))
    func droppedRegistry_isNotJoined() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        var releaseFetches: (() -> Void)!
        let gate = AsyncStream<Void> { continuation in
            releaseFetches = { continuation.finish() }
        }
        repository.fetchBarrier = { for await _ in gate {} }

        let useCase = Self.makeUseCase(repository: repository)

        async let first = useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)
        while repository.fetchHistoricalRatesCalls.isEmpty {
            await Task.yield()
        }

        // A wipe ran: the parked fetch is doomed. A fresh load must not join it.
        useCase.dropInFlightFetches()
        async let second = useCase.loadHistoricalData(for: "GBP", dateRange: Self.testDateRange)
        while repository.fetchHistoricalRatesCalls.count < 2 {
            await Task.yield()
        }
        releaseFetches()
        _ = try await (first, second)

        #expect(repository.fetchHistoricalRatesCallCount == 2)
    }

    @Test("concurrent backfills share one archive download", .timeLimit(.minutes(1)))
    func concurrentBackfills_shareOneDownload() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))

        var releaseFetches: (() -> Void)!
        let gate = AsyncStream<Void> { continuation in
            releaseFetches = { continuation.finish() }
        }
        repository.fetchBarrier = { for await _ in gate {} }
        repository.syncStoreForPersist = syncStore

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        // Launch warm-up overlapping a user-initiated refresh.
        async let first: Void = useCase.backfillArchive()
        async let second: Void = useCase.backfillArchive()
        while repository.fetchAndPersistCalls.isEmpty {
            await Task.yield()
        }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        releaseFetches()
        _ = await (first, second)

        // One run's worth of chunks (the gap is 8 of them) — not two runs'.
        #expect(repository.fetchAndPersistCalls.count == 8)
    }

    @Test("a USD/USD archive view renders the synthesized flat series, not 'no data'")
    func archiveRange_usdAgainstUsd_synthesizesDayGrid() async throws {
        let repository = MockHistoricalRateRepository()
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "USD", base: "USD", dateRange: Self.archiveRange)

        #expect(result.dataPoints.count == 1828) // one snapshot per day, inclusive
        #expect(result.dataPoints.allSatisfy { $0.rates.isEmpty }) // the rate table supplies USD's 1.0
        #expect(repository.fetchTransientCalls.isEmpty)
    }

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
