@testable import CurrencySpot
import Foundation
import Testing

@Suite("LoadHistoricalRatesUseCase Tests")
struct LoadHistoricalRatesUseCaseTests {
    // MARK: - Fixtures

    private static let calendar = CETCalendar.calendar
    private static let baseDate = createCETDate(year: 2025, month: 1, day: 15)!

    private static func day(_ offset: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: baseDate)!)
    }

    private static let startDate = day(-7)
    private static let endDate = day(0)
    private static let testDateRange = DateRange.spanning(startDate, endDate)
    private static let archiveRange = DateRange.spanning(day(-1827), day(0))

    private static func makeUseCase(
        repository: MockHistoricalRateRepository,
        syncStore: MockHistoricalSyncStore = MockHistoricalSyncStore()
    ) -> LoadHistoricalRatesUseCase {
        let analysis = HistoricalDataAnalysisUseCase(syncCoverage: syncStore, dateProvider: FixedDateProvider(baseDate))
        return LoadHistoricalRatesUseCase(
            repository: repository,
            archive: repository,
            backfill: BackfillArchiveUseCase(archive: repository, analysis: analysis, clock: GatedClock()),
            analysis: analysis
        )
    }

    private static func snapshots(on dates: [Date]) -> [HistoricalRateSnapshot] {
        dates.map { date in
            HistoricalRateSnapshot(date: date, rates: [
                HistoricalRatePoint(currencyCode: "EUR", rate: 0.85),
                HistoricalRatePoint(currencyCode: "GBP", rate: 0.75),
                HistoricalRatePoint(currencyCode: "JPY", rate: 110.0),
            ])
        }
    }

    // MARK: - Resident ranges

    @Test("a range the shared series covers is served from it without a fetch")
    func coveredRangeIsServedFromTheSeries() async throws {
        let repository = MockHistoricalRateRepository()
        let series = Self.snapshots(on: [Self.startDate, Self.endDate])
        repository.seedSeries(series)
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)

        #expect(result.snapshots == series)
        #expect(result.newDataFetched == false)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
    }

    @Test("a partly covered range fetches only the missing days and returns the merged series")
    func partlyCoveredRangeFetchesTheMissingDays() async throws {
        let repository = MockHistoricalRateRepository()
        repository.seedSeries(Self.snapshots(on: [Self.startDate]))
        repository.fetchedDataToReturn = Self.snapshots(on: [Self.endDate])
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(result.snapshots.map(\.date) == [Self.startDate, Self.endDate])
        let fetchCall = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(fetchCall.from == Self.day(-6))
        #expect(fetchCall.to == Self.endDate)
    }

    @Test("data loaded for one currency serves any other currency from the shared series")
    func sharedSeriesServesOtherCurrencies() async throws {
        let repository = MockHistoricalRateRepository()
        repository.fetchedDataToReturn = Self.snapshots(on: [Self.startDate, Self.endDate])
        let useCase = Self.makeUseCase(repository: repository)

        _ = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)
        let second = try await useCase.loadHistoricalData(for: "GBP", base: "USD", dateRange: Self.testDateRange)

        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(second.newDataFetched == false)
        #expect(second.snapshots.map(\.date) == [Self.startDate, Self.endDate])
    }

    @Test("with nothing cached or stored the whole range is fetched")
    func emptyCacheFetchesTheWholeRange() async throws {
        let repository = MockHistoricalRateRepository()
        let fetched = Self.snapshots(on: [Self.startDate, Self.endDate])
        repository.fetchedDataToReturn = fetched
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)

        #expect(result.newDataFetched == true)
        #expect(result.snapshots == fetched)
        #expect(result.fetchedRanges == [Self.testDateRange])
        #expect(repository.fetchHistoricalRatesCallCount == 1)
    }

    @Test("a new day's load fetches only the missing edge and serves the rest from the store")
    func newDayFetchesOnlyTheGap() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(-1)
        repository.storedRows = Self.snapshots(on: [Self.day(-2), Self.day(-1)])
        repository.fetchedDataToReturn = Self.snapshots(on: [Self.day(0)])
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(-1), checkedAt: Self.day(-1))
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(
            for: "EUR",
            base: "USD",
            dateRange: DateRange.spanning(Self.day(-365), Self.day(0))
        )

        let call = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(call.from == Self.day(-1))
        #expect(call.to == Self.day(0))
        #expect(result.newDataFetched == true)
        #expect(result.snapshots.map(\.date) == [Self.day(-2), Self.day(-1), Self.day(0)])
    }

    @Test("a range the store covers is served from the store without a fetch")
    func storedRangeSkipsTheFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-17)
        repository.latestStoredDateResult = Self.day(10)
        let stored = Self.snapshots(on: [Self.startDate, Self.endDate])
        repository.storedRows = stored
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)

        #expect(result.newDataFetched == false)
        #expect(result.snapshots == stored)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
    }

    @Test("each genuine gap before and after the series gets its own fetch")
    func gapsOnBothSidesAreFetchedSeparately() async throws {
        let repository = MockHistoricalRateRepository()
        repository.seedSeries(Self.snapshots(on: [Self.day(-10), Self.day(-9), Self.day(-8)]))
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(
            for: "EUR",
            base: "USD",
            dateRange: DateRange.spanning(Self.day(-20), Self.day(0))
        )

        #expect(result.newDataFetched == true)
        let calls = repository.fetchHistoricalRatesCalls.sorted { $0.from < $1.from }
        #expect(calls.count == 2)
        #expect(calls.first?.from == Self.day(-20))
        #expect(calls.first?.to == Self.day(-11))
        #expect(calls.last?.from == Self.day(-7))
        #expect(calls.last?.to == Self.day(0))
    }

    @Test("when every fetch fails the load serves the series plus whatever the store holds")
    func failedFetchesFallBackToTheStore() async throws {
        let repository = MockHistoricalRateRepository()
        repository.seedSeries(Self.snapshots(on: [Self.day(-10), Self.day(-9), Self.day(-8)]))
        repository.storedRows = Self.snapshots(on: [Self.day(-15)])
        repository.shouldThrowErrorOnFetch = true
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(
            for: "EUR",
            base: "USD",
            dateRange: DateRange.spanning(Self.day(-20), Self.day(0))
        )

        #expect(result.newDataFetched == false)
        #expect(result.snapshots.map(\.date) == [Self.day(-15), Self.day(-10), Self.day(-9), Self.day(-8)])
    }

    @Test("a failed store read falls back to fetching that range")
    func failedStoreReadFallsBackToAFetch() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-17)
        repository.latestStoredDateResult = Self.day(10)
        repository.shouldThrowErrorOnLoad = true
        let fetched = Self.snapshots(on: [Self.startDate, Self.endDate])
        repository.fetchedDataToReturn = fetched
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)

        let call = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(call.from == Self.startDate)
        #expect(call.to == Self.endDate)
        #expect(result.snapshots == fetched)
        #expect(result.newDataFetched == false)
    }

    @Test("a cancelled load stops instead of serving a fallback", .timeLimit(.minutes(1)))
    func cancelledLoadThrowsCancellation() async throws {
        let repository = MockHistoricalRateRepository()
        repository.storedRows = Self.snapshots(on: [Self.startDate])
        repository.shouldThrowErrorOnFetch = true
        repository.errorToThrow = CancellationError()
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }
        let useCase = Self.makeUseCase(repository: repository)

        let load = Task {
            try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)
        }
        await waitUntil { repository.fetchHistoricalRatesCallCount == 1 }
        load.cancel()
        openGate.finish()

        await #expect(throws: CancellationError.self) {
            _ = try await load.value
        }
    }

    @Test("a fetch cancelled by a data reset while the caller is still live falls back like any failed fetch")
    func resetCancelledFetchFallsBackToTheStore() async throws {
        let repository = MockHistoricalRateRepository()
        let stored = Self.snapshots(on: [Self.startDate])
        repository.storedRows = stored
        repository.shouldThrowErrorOnFetch = true
        repository.errorToThrow = CancellationError()
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)

        #expect(result.snapshots == stored)
        #expect(result.newDataFetched == false)
    }

    @Test("a failed fetch that leaves nothing inside the range surfaces the error")
    func failedFetchWithNothingToShowThrows() async throws {
        let repository = MockHistoricalRateRepository()
        repository.seedSeries(Self.snapshots(on: [Self.day(-30)]))
        repository.shouldThrowErrorOnFetch = true
        let useCase = Self.makeUseCase(repository: repository)

        await #expect(throws: AppError.self) {
            _ = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)
        }
    }

    @Test("a successful fetch that returns no days is an empty result, not an error")
    func emptyFetchIsNotAnError() async throws {
        let repository = MockHistoricalRateRepository()
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)

        #expect(result.snapshots.isEmpty)
        #expect(repository.fetchHistoricalRatesCallCount == 1)
    }

    // MARK: - Archive ranges

    @Test("a covered archive range loads from the store without touching the shared series")
    func coveredArchiveLoadsFromTheStore() async throws {
        let repository = MockHistoricalRateRepository()
        let stored = Self.snapshots(on: [Self.day(-1000), Self.day(-1)])
        repository.storedRows = stored
        let syncStore = MockHistoricalSyncStore(from: Self.day(-1827), through: Self.day(0), checkedAt: Self.day(0))
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(result.snapshots == stored)
        #expect(result.newDataFetched == false)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.fetchTransientCalls.isEmpty)
        #expect(repository.series.isEmpty)
    }

    @Test("an archive covered through yesterday still loads from the store")
    func archiveCoveredThroughYesterdayLoadsFromTheStore() async throws {
        let repository = MockHistoricalRateRepository()
        let stored = Self.snapshots(on: [Self.day(-1000), Self.day(-1)])
        repository.storedRows = stored
        let syncStore = MockHistoricalSyncStore(from: Self.day(-1827), through: Self.day(-1), checkedAt: Self.day(-1))
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(result.snapshots == stored)
        #expect(repository.fetchTransientCalls.isEmpty)
    }

    @Test("an uncovered archive range bridges with a transient pair fetch, leaving the shared series untouched")
    func uncoveredArchiveBridgesWithATransientFetch() async throws {
        let repository = MockHistoricalRateRepository()
        let bridged = Self.snapshots(on: [Self.day(-1000)])
        repository.transientDataToReturn = bridged
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "GBP", dateRange: Self.archiveRange)

        #expect(result.snapshots == bridged)
        #expect(result.newDataFetched == false)
        let transient = try #require(repository.fetchTransientCalls.first)
        #expect(Set(transient.currencies) == Set(["EUR", "GBP"] as [CurrencyCode]))
        #expect(transient.from == Self.archiveRange.start)
        #expect(transient.to == Self.archiveRange.end)
        #expect(repository.fetchHistoricalRatesCallCount == 0)
        #expect(repository.series.isEmpty)
    }

    @Test("a covered archive whose store read fails falls through to the transient bridge")
    func failedArchiveStoreReadBridges() async throws {
        let repository = MockHistoricalRateRepository()
        repository.shouldThrowErrorOnLoad = true
        let bridged = Self.snapshots(on: [Self.day(-1000)])
        repository.transientDataToReturn = bridged
        let syncStore = MockHistoricalSyncStore(from: Self.day(-1827), through: Self.day(0), checkedAt: Self.day(0))
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(result.snapshots == bridged)
        #expect(repository.fetchTransientCalls.count == 1)
    }

    @Test("a USD pair's transient fetch requests only the non-USD side")
    func usdPairRequestsOnlyTheOtherSide() async throws {
        let repository = MockHistoricalRateRepository()
        repository.transientDataToReturn = Self.snapshots(on: [Self.day(-1000)])
        let useCase = Self.makeUseCase(repository: repository)

        _ = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        let transient = try #require(repository.fetchTransientCalls.first)
        #expect(transient.currencies == ["EUR"])
    }

    @Test("a USD/USD archive view renders a synthesized flat day grid")
    func usdAgainstUsdSynthesizesADayGrid() async throws {
        let repository = MockHistoricalRateRepository()
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "USD", base: "USD", dateRange: Self.archiveRange)

        #expect(result.snapshots.count == 1828)
        #expect(result.snapshots.allSatisfy { $0.rates.isEmpty })
        #expect(repository.fetchTransientCalls.isEmpty)
    }

    @Test("an archive view on the transient bridge kicks the backfill in the background", .timeLimit(.minutes(1)))
    func bridgeKicksTheBackfill() async throws {
        let repository = MockHistoricalRateRepository()
        let bridged = Self.snapshots(on: [Self.day(-1000)])
        repository.transientDataToReturn = bridged
        repository.earliestStoredDateResult = Self.day(-365)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-365), through: Self.day(0), checkedAt: Self.day(0))
        repository.syncStoreForPersist = syncStore
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(result.snapshots == bridged)
        await waitUntil { repository.fetchAndPersistCalls.count == 8 }
        #expect(syncStore.from == Self.archiveRange.start)
    }

    @Test("a failed bridge falls back to a complete stored archive")
    func failedBridgeServesACompleteStoredArchive() async throws {
        let repository = MockHistoricalRateRepository()
        let stored = Self.snapshots(on: [Self.day(-1000)])
        repository.storedRows = stored
        repository.earliestStoredDateResult = Self.day(-1827)
        repository.shouldThrowErrorOnFetch = true
        let useCase = Self.makeUseCase(repository: repository)

        let result = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)

        #expect(repository.fetchTransientCalls.count == 1)
        #expect(result.snapshots == stored)
        #expect(result.newDataFetched == false)
    }

    @Test("a failed bridge with only a partial archive on disk surfaces the error")
    func failedBridgeWithAPartialArchiveThrows() async throws {
        let repository = MockHistoricalRateRepository()
        repository.storedRows = Self.snapshots(on: [Self.day(-300)])
        repository.earliestStoredDateResult = Self.day(-365)
        repository.shouldThrowErrorOnFetch = true
        let useCase = Self.makeUseCase(repository: repository)

        await #expect(throws: AppError.self) {
            _ = try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.archiveRange)
        }
    }

    @Test("a resident load during the archive backfill never absorbs archive rows", .timeLimit(.minutes(1)))
    func residentLoadDuringBackfillKeepsTheSeriesResident() async throws {
        let repository = MockHistoricalRateRepository()
        repository.fetchedDataToReturn = Self.snapshots(on: [Self.startDate, Self.endDate])
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }
        let syncStore = MockHistoricalSyncStore()
        repository.syncStoreForPersist = syncStore
        let analysis = HistoricalDataAnalysisUseCase(syncCoverage: syncStore, dateProvider: FixedDateProvider(Self.baseDate))
        let backfill = BackfillArchiveUseCase(archive: repository, analysis: analysis, clock: GatedClock())
        let useCase = LoadHistoricalRatesUseCase(repository: repository, archive: repository, backfill: backfill, analysis: analysis)

        let backfillRun = Task { await backfill.backfillArchive() }
        let residentLoad = Task {
            try await useCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: Self.testDateRange)
        }
        await waitUntil { repository.fetchHistoricalRatesCalls.isEmpty == false }
        openGate.finish()
        await backfillRun.value
        _ = try await residentLoad.value

        let residentFetch = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(repository.fetchHistoricalRatesCallCount == 1)
        #expect(residentFetch.from == Self.testDateRange.start)
        #expect(repository.fetchAndPersistCalls.isEmpty == false)
        #expect(repository.series.allSatisfy { Self.testDateRange.start ... Self.testDateRange.end ~= $0.date })
    }

    // MARK: - Ranges and prefetch

    @Test("dateRange(for:) is anchored at today's CET day")
    func dateRangeIsAnchoredAtToday() throws {
        let useCase = Self.makeUseCase(repository: MockHistoricalRateRepository())

        let range = useCase.dateRange(for: .oneWeek)

        #expect(range == DateRange.spanning(Self.day(-7), Self.day(0)))
    }

    @Test("prefetchResidentYear warms a today-anchored one-year window")
    func prefetchWarmsTheResidentYear() async throws {
        let repository = MockHistoricalRateRepository()
        let useCase = Self.makeUseCase(repository: repository)

        await useCase.prefetchResidentYear()

        let call = try #require(repository.fetchHistoricalRatesCalls.first)
        #expect(call.from == createCETDate(year: 2024, month: 1, day: 15))
        #expect(call.to == Self.day(0))
    }

    @Test("a failing prefetch completes quietly")
    func failingPrefetchCompletesQuietly() async throws {
        let repository = MockHistoricalRateRepository()
        repository.shouldThrowErrorOnFetch = true
        repository.shouldThrowErrorOnLoad = true
        let useCase = Self.makeUseCase(repository: repository)

        await useCase.prefetchResidentYear()

        #expect(repository.fetchHistoricalRatesCallCount >= 1)
    }
}
