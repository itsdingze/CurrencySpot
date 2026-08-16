@testable import CurrencySpot
import Foundation
import Testing

// MARK: - Test Suite

@Suite("DataOrchestrationUseCase Tests")
struct DataOrchestrationUseCaseTests {
    // MARK: - Test Data

    static let testCurrency: CurrencyCode = "EUR"
    static let baseDate = createCETDate(year: 2025, month: 1, day: 15)!
    static let calendar = TimeZoneManager.cetCalendar

    static let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: baseDate) ?? baseDate)
    static let endDate = calendar.startOfDay(for: baseDate)
    static let testDateRange = DateRange.spanning(startDate, endDate)

    // MARK: - Test Helper Methods

    private static func makeUseCase(
        repository: MockHistoricalRateRepository,
        syncStore: MockHistoricalSyncStore = MockHistoricalSyncStore(),
        clock: ClockService = ImmediateClock()
    ) -> DataOrchestrationUseCase {
        DataOrchestrationUseCase(
            repository: repository,
            historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase(
                syncCoverage: syncStore,
                dateProvider: FixedDateProvider(baseDate)
            ),
            dateProvider: FixedDateProvider(baseDate),
            clock: clock
        )
    }

    private static func day(_ offset: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: baseDate)!)
    }

    private static let archiveRange = DateRange.spanning(day(-1827), day(0))

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

        #expect(result.snapshots == cachedData)
        #expect(result.newDataFetched == false)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.loadHistoricalRatesCallCount == 0)
    }

    @Test("loadHistoricalData should fetch missing data and merge with cache")
    func loadHistoricalData_partialCacheMiss_shouldFetchAndMerge() async throws {
        let repository = MockHistoricalRateRepository()
        let existingCachedData = Self.createTestHistoricalData(dates: [Self.startDate])
        repository.seedCache(existingCachedData)

        let missingRange = DateRange.spanning(Self.calendar.date(byAdding: .day, value: 1, to: Self.startDate) ?? Self.startDate, Self.endDate)

        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.endDate])
        repository.earliestStoredDateResult = nil

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(result.snapshots.count == 2)
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(repository.loadHistoricalRatesCallCount == 0)

        let fetchCall = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(fetchCall.from == missingRange.start)
        #expect(fetchCall.to == missingRange.end)

        #expect(repository.mergeCachedCallCount == 1)
    }

    @Test("data loaded for one currency serves any other currency from the shared cache")
    func loadHistoricalData_sharedCacheServesOtherCurrencies() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        let useCase = Self.makeUseCase(repository: repository)

        _ = try await useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)
        let second = try await useCase.loadHistoricalData(for: "GBP", dateRange: Self.testDateRange)

        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(repository.loadHistoricalRatesCallCount == 0)
        #expect(second.newDataFetched == false)
        #expect(second.snapshots.count == 2)
    }

    @Test("concurrent loads for the same range share one network fetch", .timeLimit(.minutes(1)))
    func concurrentLoads_sameRange_shareOneFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }

        let useCase = Self.makeUseCase(repository: repository)

        async let first = useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)
        async let second = useCase.loadHistoricalData(for: "GBP", dateRange: Self.testDateRange)

        await waitUntil { repository.cachedReadCount >= 2 }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        gateContinuation.finish()

        let results = try await (first, second)

        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(results.0.snapshots.count == 2)
        #expect(results.1.snapshots.count == 2)
    }

    @Test("concurrent loads for disjoint ranges union their rows instead of clobbering", .timeLimit(.minutes(1)))
    func concurrentDisjointLoads_unionTheirRows() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        let oldRange = DateRange.spanning(day(-30), day(-20))
        let recentRange = DateRange.spanning(day(-7), day(0))
        repository.fetchedDataProvider = { from, _ in
            Self.createTestHistoricalData(dates: [from])
        }

        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }

        let useCase = Self.makeUseCase(repository: repository)

        async let old = useCase.loadHistoricalData(for: "EUR", dateRange: oldRange)
        async let recent = useCase.loadHistoricalData(for: "EUR", dateRange: recentRange)

        await waitUntil { repository.fetchHistoricalRatesCallCount >= 2 }
        gateContinuation.finish()
        _ = try await (old, recent)

        let cachedDates = Set(repository.cachedData.map(\.date))
        #expect(cachedDates.contains(oldRange.start))
        #expect(cachedDates.contains(recentRange.start))
    }

    @Test("a narrower load joins a covering in-flight fetch instead of refetching", .timeLimit(.minutes(1)))
    func narrowLoad_joinsCoveringInFlightFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }

        let useCase = Self.makeUseCase(repository: repository)

        let wideRange = DateRange.spanning(
            Self.calendar.date(byAdding: .day, value: -30, to: Self.endDate)!,
            Self.endDate
        )
        async let wide = useCase.loadHistoricalData(for: "USD", dateRange: wideRange)
        async let narrow = useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)

        await waitUntil { repository.cachedReadCount >= 2 }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        gateContinuation.finish()

        _ = try await (wide, narrow)

        #expect(repository.fetchHistoricalRatesCallCount == 1)
        let call = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(call.from == wideRange.start)
        #expect(call.to == wideRange.end)
    }

    @Test("loadHistoricalData should fetch all data when no cache exists")
    func loadHistoricalData_noCacheExists_shouldFetchAllData() async throws {
        let repository = MockHistoricalRateRepository()
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])
        repository.earliestStoredDateResult = nil

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(result.snapshots.isEmpty == false)
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(repository.loadHistoricalRatesCallCount == 0)
    }

    @Test("a new day's load fetches only the missing edge, not the whole window")
    func newDayLoad_fetchesOnlyTheGap() async throws {
        let repository = MockHistoricalRateRepository()

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        repository.earliestStoredDateResult = day(-365)
        repository.latestStoredDateResult = day(-1)
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [day(-2), day(-1)])
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [day(0)])
        let syncStore = MockHistoricalSyncStore(from: day(-365), through: day(-1), checkedAt: day(-1))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let yearRange = DateRange.spanning(day(-365), day(0))
        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: yearRange)

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

        repository.earliestStoredDateResult = Self.calendar.date(byAdding: .day, value: -10, to: Self.startDate)
        repository.latestStoredDateResult = Self.calendar.date(byAdding: .day, value: 10, to: Self.endDate)
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: Self.testDateRange)

        #expect(result.newDataFetched == false)
        #expect(result.snapshots.isEmpty == false)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.loadHistoricalRatesCallCount == 1)
    }

    @Test("loadHistoricalData fetches a separate range for each genuine gap before and after the cache")
    func loadHistoricalData_multipleMissingRanges_shouldFetchEachGap() async throws {
        let repository = MockHistoricalRateRepository()

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        let requiredRange = DateRange.spanning(day(-20), day(0))
        let cacheDates = [day(-10), day(-9), day(-8)]
        repository.seedCache(Self.createTestHistoricalData(dates: cacheDates))

        repository.earliestStoredDateResult = nil

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: requiredRange)

        #expect(result.newDataFetched == true)
        #expect(repository.fetchHistoricalRatesCallCount == 2)
        #expect(repository.loadHistoricalRatesCallCount == 0)

        let calls = repository.fetchHistoricalRatesCalls.sorted { $0.from < $1.from }
        #expect(calls.count == 2)
        #expect(calls.first?.from == day(-20))
        #expect(calls.last?.to == day(0))
        if let beforeGap = calls.first, let afterGap = calls.last {
            #expect(beforeGap.to < afterGap.from)
        }
    }

    @Test("loadHistoricalData degrades to cached data when every fetch fails")
    func loadHistoricalData_networkError_returnsCachedData() async throws {
        let repository = MockHistoricalRateRepository()

        func day(_ offset: Int) -> Date {
            Self.calendar.startOfDay(for: Self.calendar.date(byAdding: .day, value: offset, to: Self.baseDate)!)
        }
        let requiredRange = DateRange.spanning(day(-20), day(0))
        let cachedData = Self.createTestHistoricalData(dates: [day(-10), day(-9), day(-8)])
        repository.seedCache(cachedData)

        repository.earliestStoredDateResult = nil
        repository.historicalDataToReturn = []
        repository.shouldThrowErrorOnFetch = true
        repository.errorToThrow = AppError.networkError("Test network error")

        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: Self.testCurrency, dateRange: requiredRange)

        #expect(repository.fetchHistoricalRatesCallCount >= 1)
        #expect(repository.loadHistoricalRatesCallCount == repository.fetchHistoricalRatesCallCount)
        #expect(result.newDataFetched == false)
        #expect(result.snapshots == cachedData)
    }

    // MARK: - Archive range Tests

    @Test("a covered archive range loads from the blob store without touching the resident series")
    func archiveRange_covered_loadsFromStore() async throws {
        let repository = MockHistoricalRateRepository()
        let blobRows = Self.createTestHistoricalData(dates: [Self.day(-1000), Self.day(-1)])
        repository.historicalDataToReturn = blobRows
        let syncStore = MockHistoricalSyncStore(from: Self.day(-1827), through: Self.day(0), checkedAt: Self.day(0))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(result.snapshots == blobRows)
        #expect(result.newDataFetched == false)
        #expect(repository.loadHistoricalRatesCallCount == 1)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.fetchTransientCalls.isEmpty)
        #expect(repository.mergeCachedCallCount == 0)
        #expect(repository.cachedData.isEmpty)
    }

    @Test("an uncovered archive range bridges with a transient pair fetch, leaving every store untouched")
    func archiveRange_uncovered_bridgesWithTransientFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.transientDataToReturn = Self.createTestHistoricalData(dates: [Self.day(-1000)])
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "GBP", dateRange: Self.archiveRange)

        #expect(result.snapshots == repository.transientDataToReturn)
        #expect(result.newDataFetched == false)
        let transient = try #require(repository.fetchTransientCalls.first)
        #expect(Set(transient.currencies) == Set(["EUR", "GBP"] as [CurrencyCode]))
        #expect(transient.from == Self.archiveRange.start)
        #expect(transient.to == Self.archiveRange.end)
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
        #expect(transient.currencies == ["EUR"])
    }

    // MARK: - backfillArchive Tests

    @Test("backfillArchive fetches the archive gap in adjacent half-year chunks, newest first")
    func backfillArchive_fetchesGapInChunks() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))
        repository.syncStoreForPersist = syncStore

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        let calls = repository.fetchAndPersistCalls
        #expect(calls.count == 8)
        #expect(calls.first?.to == Self.day(-365))
        for (older, newer) in zip(calls.dropFirst(), calls) {
            #expect(older.to == Self.calendar.date(byAdding: .day, value: -1, to: newer.from))
        }
        #expect(calls.last?.from == Self.archiveRange.start)
        for call in calls {
            let days = Self.calendar.dateComponents([.day], from: call.from, to: call.to).day ?? .max
            #expect(days < 183)
        }
        #expect(syncStore.from == Self.archiveRange.start)
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
        repository.fetchAndPersistFailAtCall = 3

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        await waitUntil { repository.fetchAndPersistCalls.count >= 9 }
        #expect(repository.fetchAndPersistCalls.count == 9)
        #expect(syncStore.from == Self.archiveRange.start)
    }

    @Test("a chunk whose deferred save fails aborts the run; the re-run refetches instead of repairing over the hole", .timeLimit(.minutes(1)))
    func backfillArchive_failedPersistAbortsAndResumes() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))
        repository.syncStoreForPersist = syncStore
        repository.persistFailAtCall = 3

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        await waitUntil { repository.fetchAndPersistCalls.count >= 9 }
        #expect(repository.fetchAndPersistCalls.count == 9)
        #expect(syncStore.from == Self.archiveRange.start)
    }

    @Test("delayed re-runs are bounded, not an infinite poll", .timeLimit(.minutes(1)))
    func backfillArchive_retriesAreBounded() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        repository.shouldThrowErrorOnFetch = true
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        await waitUntil { repository.fetchAndPersistCalls.count >= 3 }
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(repository.fetchAndPersistCalls.count == 3)
    }

    @Test("a second failing run replaces its delayed re-run instead of orphaning an uncancellable one", .timeLimit(.minutes(1)))
    func backfillArchive_secondRetryCancelsTheFirst() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        repository.shouldThrowErrorOnFetch = true
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))
        let clock = GatedClock()

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore, clock: clock)

        await useCase.backfillArchive()
        await useCase.backfillArchive()

        let callsBeforeWipe = repository.fetchAndPersistCalls.count
        useCase.dropInFlightFetches()
        clock.release()
        for _ in 0 ..< 50 {
            await Task.yield()
        }

        #expect(repository.fetchAndPersistCalls.count == callsBeforeWipe)
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

        #expect(result.snapshots == repository.transientDataToReturn)
        await waitUntil { repository.fetchAndPersistCalls.count >= 8 }
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
        repository.earliestStoredDateResult = nil
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }

        let syncStore = MockHistoricalSyncStore()
        repository.syncStoreForPersist = syncStore
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        async let backfill: Void = useCase.backfillArchive()
        async let resident = useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)

        await waitUntil { repository.fetchHistoricalRatesCalls.isEmpty == false }
        gateContinuation.finish()
        _ = await backfill
        _ = try await resident

        #expect(repository.fetchHistoricalRatesCallCount == 1)
        let residentFetch = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(residentFetch.from == Self.testDateRange.start)
        #expect(repository.cachedData.allSatisfy { $0.date >= Self.testDateRange.start && $0.date <= Self.testDateRange.end })
    }

    @Test("backfillArchive repairs a watermark that under-claims persisted rows")
    func backfillArchive_repairsUnderClaimingWatermark() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-1827)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        #expect(repository.fetchAndPersistCalls.isEmpty)
        #expect(syncStore.recordCallCount == 1)
        #expect(syncStore.from == Self.day(-1827))
    }

    @Test("an archive covered through yesterday still reads from the blob store")
    func archiveRange_coveredThroughYesterday_loadsFromStore() async throws {
        let repository = MockHistoricalRateRepository()
        let blobRows = Self.createTestHistoricalData(dates: [Self.day(-1000), Self.day(-1)])
        repository.historicalDataToReturn = blobRows
        let syncStore = MockHistoricalSyncStore(from: Self.day(-1827), through: Self.day(-1), checkedAt: Self.day(-1))

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(result.snapshots == blobRows)
        #expect(repository.fetchTransientCalls.isEmpty)
        #expect(repository.loadHistoricalRatesCallCount == 1)
    }

    @Test("a failed archive bridge falls back to a complete stored archive")
    func archiveRange_bridgeFails_servesStoredArchive() async throws {
        let repository = MockHistoricalRateRepository()
        let storedRows = Self.createTestHistoricalData(dates: [Self.day(-1000)])
        repository.historicalDataToReturn = storedRows
        repository.earliestStoredDateResult = Self.day(-1827)
        repository.shouldThrowErrorOnFetch = true
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(repository.fetchTransientCalls.count == 1)
        #expect(result.snapshots == storedRows)
        #expect(result.newDataFetched == false)
    }

    @Test("a failed bridge with only a partial archive on disk surfaces the error")
    func archiveRange_bridgeFailsPartialStore_throws() async throws {
        let repository = MockHistoricalRateRepository()
        repository.historicalDataToReturn = Self.createTestHistoricalData(dates: [Self.day(-300)])
        repository.earliestStoredDateResult = Self.day(-365)
        repository.shouldThrowErrorOnFetch = true

        let useCase = Self.makeUseCase(repository: repository)

        await #expect(throws: AppError.self) {
            _ = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)
        }
    }

    @Test("a load after dropInFlightFetches re-fetches instead of joining a doomed fetch", .timeLimit(.minutes(1)))
    func droppedRegistry_isNotJoined() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil
        repository.fetchedDataToReturn = Self.createTestHistoricalData(dates: [Self.startDate, Self.endDate])

        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        let cancellationImmuneGate = Task { for await _ in gate {} }
        var cancelledFetches = 0
        repository.fetchBarrier = {
            await cancellationImmuneGate.value
            if Task.isCancelled { cancelledFetches += 1 }
        }

        let useCase = Self.makeUseCase(repository: repository)

        async let first = useCase.loadHistoricalData(for: "EUR", dateRange: Self.testDateRange)
        await waitUntil { repository.fetchHistoricalRatesCalls.isEmpty == false }

        useCase.dropInFlightFetches()
        async let second = useCase.loadHistoricalData(for: "GBP", dateRange: Self.testDateRange)
        await waitUntil { repository.fetchHistoricalRatesCalls.count >= 2 }
        gateContinuation.finish()
        _ = try await (first, second)

        #expect(repository.fetchHistoricalRatesCallCount == 2)
        #expect(cancelledFetches == 1)
    }

    @Test("concurrent backfills share one archive download", .timeLimit(.minutes(1)))
    func concurrentBackfills_shareOneDownload() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))

        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }
        repository.syncStoreForPersist = syncStore

        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        async let first: Void = useCase.backfillArchive()
        async let second: Void = useCase.backfillArchive()
        await waitUntil { repository.fetchAndPersistCalls.isEmpty == false }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        gateContinuation.finish()
        _ = await (first, second)

        #expect(repository.fetchAndPersistCalls.count == 8)
    }

    @Test("a USD/USD archive view renders the synthesized flat series, not 'no data'")
    func archiveRange_usdAgainstUsd_synthesizesDayGrid() async throws {
        let repository = MockHistoricalRateRepository()
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "USD", base: "USD", dateRange: Self.archiveRange)

        #expect(result.snapshots.count == 1828)
        #expect(result.snapshots.allSatisfy { $0.rates.isEmpty })
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
        repository.earliestStoredDateResult = nil
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
