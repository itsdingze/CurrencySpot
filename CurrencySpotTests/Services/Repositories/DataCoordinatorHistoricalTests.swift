@testable import CurrencySpot
import Foundation
import Testing

@Suite("DataCoordinator historical render-first pipeline")
struct DataCoordinatorHistoricalTests {
    // MARK: - Fixtures

    private static let calendar = CETCalendar.calendar
    private static let now = createCETDate(year: 2025, month: 1, day: 15)!
    private static let startDate = calendar.date(byAdding: .day, value: -7, to: now)!
    private static let endDate = now
    private static let dateRange = DateRange.spanning(startDate, endDate)
    private static let fetchedDay = CETCalendar.date(fromDayString: "2025-01-14")!

    private static func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    private static func response(rates: [String: [String: Double]]) -> HistoricalRatesResponse {
        HistoricalRatesResponse(
            base: "USD",
            startDate: CETCalendar.dayString(for: startDate),
            endDate: CETCalendar.dayString(for: endDate),
            rates: rates
        )
    }

    private static let oneDayResponse = response(rates: ["2025-01-14": ["EUR": 0.85]])

    private static func dailyResponse(from start: Date, to end: Date) -> HistoricalRatesResponse {
        var rates: [String: [String: Double]] = [:]
        var day = calendar.startOfDay(for: start)
        while day <= calendar.startOfDay(for: end) {
            rates[CETCalendar.dayString(for: day)] = ["EUR": 0.85]
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return HistoricalRatesResponse(
            base: "USD",
            startDate: CETCalendar.dayString(for: start),
            endDate: CETCalendar.dayString(for: end),
            rates: rates
        )
    }

    private static func makeCoordinator(
        network: MockNetworkService,
        persistence: MockPersistenceService = MockPersistenceService(),
        syncStore: MockHistoricalSyncStore = MockHistoricalSyncStore(),
        cache: InMemoryCacheService = InMemoryCacheService()
    ) -> DataCoordinator {
        DataCoordinator(
            networkService: network,
            persistenceService: persistence,
            cacheService: cache,
            syncStore: syncStore,
            fetchDateStore: InMemoryRatesFetchDateStore(),
            dateProvider: FixedDateProvider(now)
        )
    }

    private static func gatedNetwork() -> (MockNetworkService, AsyncStream<Void>.Continuation) {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(oneDayResponse)
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        network.historicalFetchBarrier = { for await _ in gate {} }
        return (network, openGate)
    }

    // MARK: - Render-first contract

    @Test("a fetch returns decoded snapshots while its save is still pending", .timeLimit(.minutes(1)))
    func fetchReturnsSnapshotsBeforeTheSave() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.response(rates: [
            "2025-01-14": ["EUR": 0.85, "GBP": 0.75],
            "2025-01-13": ["EUR": 0.84],
        ]))
        let persistence = MockPersistenceService()
        let (save, openSave) = AsyncStream.makeStream(of: Void.self)
        await persistence.gateHistoricalSave(number: 1, on: save)
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        let snapshots = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)

        #expect(snapshots.map(\.date) == [Self.day(-2), Self.day(-1)])
        let firstDay = try #require(snapshots.first)
        #expect(firstDay.rates.first { $0.currencyCode == "EUR" }?.rate == 0.84)
        #expect(syncStore.recordCallCount == 0)
        openSave.finish()
    }

    @Test("a fetch merges its days into the shared series")
    func fetchMergesIntoTheSharedSeries() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let coordinator = Self.makeCoordinator(network: network)

        _ = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)

        #expect(await coordinator.cachedHistoricalRates().map(\.date) == [Self.fetchedDay])
    }

    @Test("the coverage watermark is recorded once the deferred save commits")
    func watermarkRecordedAfterPersist() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let persistence = MockPersistenceService()
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        _ = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        _ = try await coordinator.earliestStoredDate()

        #expect(await persistence.savedHistoricalRates.count == 1)
        #expect(syncStore.recordCallCount == 1)
        #expect(syncStore.from == Self.startDate)
        #expect(syncStore.through == Self.endDate)
    }

    @Test("a store read issued while a save is pending sees the saved days", .timeLimit(.minutes(1)))
    func storeReadWaitsForThePendingSave() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let persistence = MockPersistenceService()
        let (save, openSave) = AsyncStream.makeStream(of: Void.self)
        await persistence.gateHistoricalSave(number: 1, on: save)
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence)

        _ = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        while await persistence.historicalSaveAttempts < 1 { await Task.yield() }
        let started = StartedWaiters()
        let read = Task {
            started.record()
            return try await coordinator.loadStoredHistoricalRates(in: Self.dateRange)
        }
        await waitUntil { started.count == 1 }
        openSave.finish()

        #expect(try await read.value.map(\.date) == [Self.fetchedDay])
    }

    @Test("a failed save leaves the watermark unrecorded so the range is refetched later")
    func failedPersistDoesNotRecordCoverage() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let persistence = MockPersistenceService()
        await persistence.stubSaveHistoricalError(AppError.unknownError("disk full"))
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        let snapshots = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        _ = try await coordinator.earliestStoredDate()

        #expect(snapshots.count == 1)
        #expect(syncStore.recordCallCount == 0)
    }

    @Test("an empty response still records coverage so empty days are not refetched")
    func emptyResponseRecordsCoverage() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.response(rates: [:]))
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, syncStore: syncStore)

        let snapshots = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        _ = try await coordinator.earliestStoredDate()

        #expect(snapshots.isEmpty)
        #expect(syncStore.recordCallCount == 1)
    }

    @Test("a failed save evicts the un-persisted window from the shared series")
    func failedPersistEvictsWindowFromCache() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let persistence = MockPersistenceService()
        await persistence.stubSaveHistoricalError(AppError.unknownError("disk full"))
        let cache = InMemoryCacheService()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, cache: cache)

        let outside = HistoricalRateSnapshot(date: Self.day(1), rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 0.86)])
        await cache.cacheHistoricalData([
            HistoricalRateSnapshot(date: Self.day(-3), rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 0.85)]),
            outside,
        ])

        _ = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        _ = try await coordinator.earliestStoredDate()

        #expect(await coordinator.cachedHistoricalRates().map(\.date) == [outside.date])
    }

    @Test("a stored read merges its rows into the shared series")
    func storedReadMergesIntoTheSharedSeries() async throws {
        let persistence = MockPersistenceService()
        try await persistence.saveHistoricalExchangeRates(["2025-01-10": ["EUR": 0.85], "2025-01-11": ["EUR": 0.86]])
        let coordinator = Self.makeCoordinator(network: MockNetworkService(), persistence: persistence)

        let rows = try await coordinator.loadAndMergeStoredHistoricalRates(in: Self.dateRange)

        #expect(rows.map(\.date) == [Self.day(-5), Self.day(-4)])
        #expect(await coordinator.cachedHistoricalRates() == rows)
    }

    @Test("a store-only read leaves the shared series alone")
    func storeOnlyReadLeavesTheSeriesAlone() async throws {
        let persistence = MockPersistenceService()
        try await persistence.saveHistoricalExchangeRates(["2025-01-10": ["EUR": 0.85]])
        let coordinator = Self.makeCoordinator(network: MockNetworkService(), persistence: persistence)

        let rows = try await coordinator.loadStoredHistoricalRates(in: Self.dateRange)

        #expect(rows.map(\.date) == [Self.day(-5)])
        #expect(await coordinator.cachedHistoricalRates().isEmpty)
    }

    // MARK: - Single-flight fetches

    @Test("concurrent fetches for the same range share one network request", .timeLimit(.minutes(1)))
    func sameRangeSharesOneRequest() async throws {
        let (network, openGate) = Self.gatedNetwork()
        let coordinator = Self.makeCoordinator(network: network)
        let started = StartedWaiters()

        let first = Task {
            started.record()
            return try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        }
        let second = Task {
            started.record()
            return try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        }
        await waitUntil { started.count == 2 }
        openGate.finish()

        #expect(try await first.value.map(\.date) == [Self.fetchedDay])
        #expect(try await second.value.map(\.date) == [Self.fetchedDay])
        #expect(network.fetchHistoricalRatesCalls.count == 1)
    }

    @Test("a narrower fetch joins a covering in-flight fetch and gets only its own days", .timeLimit(.minutes(1)))
    func narrowFetchJoinsCoveringFetch() async throws {
        let (network, openGate) = Self.gatedNetwork()
        let wideRange = DateRange.spanning(Self.day(-30), Self.day(0))
        let narrowRange = DateRange.spanning(Self.day(-3), Self.day(0))
        network.historicalRatesProvider = { from, to in Self.dailyResponse(from: from, to: to) }
        let coordinator = Self.makeCoordinator(network: network)
        let started = StartedWaiters()

        let wide = Task {
            started.record()
            return try await coordinator.fetchAndMergeHistoricalRates(in: wideRange)
        }
        let narrow = Task {
            started.record()
            return try await coordinator.fetchAndMergeHistoricalRates(in: narrowRange)
        }
        await waitUntil { started.count == 2 }
        openGate.finish()

        #expect(try await wide.value.count == 31)
        #expect(try await narrow.value.map(\.date) == [Self.day(-3), Self.day(-2), Self.day(-1), Self.day(0)])
        let call = try #require(network.fetchHistoricalRatesCalls.first)
        #expect(network.fetchHistoricalRatesCalls.count == 1)
        #expect(call.from == wideRange.start)
        #expect(call.to == wideRange.end)
    }

    @Test("concurrent fetches for disjoint ranges both land in the shared series", .timeLimit(.minutes(1)))
    func disjointFetchesUnionInTheSeries() async throws {
        let (network, openGate) = Self.gatedNetwork()
        let oldRange = DateRange.spanning(Self.day(-30), Self.day(-29))
        let recentRange = DateRange.spanning(Self.day(-1), Self.day(0))
        network.historicalRatesProvider = { from, to in Self.dailyResponse(from: from, to: to) }
        let coordinator = Self.makeCoordinator(network: network)

        let old = Task { try await coordinator.fetchAndMergeHistoricalRates(in: oldRange) }
        let recent = Task { try await coordinator.fetchAndMergeHistoricalRates(in: recentRange) }
        await waitUntil { network.fetchHistoricalRatesCalls.count == 2 }
        openGate.finish()
        _ = try await (old.value, recent.value)

        #expect(await coordinator.cachedHistoricalRates().map(\.date) == [Self.day(-30), Self.day(-29), Self.day(-1), Self.day(0)])
    }

    @Test("a fetch after clearAllData starts a new request instead of joining the cleared one", .timeLimit(.minutes(1)))
    func fetchAfterClearDoesNotJoinTheClearedFetch() async throws {
        let (network, openGate) = Self.gatedNetwork()
        let coordinator = Self.makeCoordinator(network: network)

        let cleared = Task { try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange) }
        await waitUntil { network.fetchHistoricalRatesCalls.count == 1 }
        try await coordinator.clearAllData()
        let fresh = Task { try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange) }
        await waitUntil { network.fetchHistoricalRatesCalls.count == 2 }
        openGate.finish()

        await #expect(throws: CancellationError.self) {
            _ = try await cleared.value
        }
        #expect(try await fresh.value.map(\.date) == [Self.fetchedDay])
    }

    // MARK: - Cancellation

    @Test("cancelling one of two waiters keeps the shared fetch running for the other", .timeLimit(.minutes(1)))
    func cancellingOneWaiterKeepsTheFetch() async throws {
        let (network, openGate) = Self.gatedNetwork()
        let coordinator = Self.makeCoordinator(network: network)
        let started = StartedWaiters()

        let cancelled = Task {
            started.record()
            return try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        }
        let kept = Task {
            started.record()
            return try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        }
        await waitUntil { started.count == 2 }
        cancelled.cancel()
        openGate.finish()

        #expect(try await kept.value.map(\.date) == [Self.fetchedDay])
        #expect(network.cancelledHistoricalFetchCount == 0)
        #expect(network.fetchHistoricalRatesCalls.count == 1)
    }

    @Test("cancelling the last waiter cancels the network request and leaves every store untouched", .timeLimit(.minutes(1)))
    func cancellingTheLastWaiterCancelsTheFetch() async throws {
        let (network, openGate) = Self.gatedNetwork()
        let persistence = MockPersistenceService()
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        let waiter = Task { try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange) }
        await waitUntil { network.fetchHistoricalRatesCalls.count == 1 }
        waiter.cancel()
        await waitUntil { network.cancelledHistoricalFetchCount == 1 }
        openGate.finish()

        await #expect(throws: CancellationError.self) {
            _ = try await waiter.value
        }
        _ = try await coordinator.earliestStoredDate()
        #expect(network.cancelledHistoricalFetchCount == 1)
        #expect(await coordinator.cachedHistoricalRates().isEmpty)
        #expect(await persistence.historicalSaveAttempts == 0)
        #expect(syncStore.recordCallCount == 0)
    }

    @Test("a fetch started while an abandoned fetch unwinds gets its own request and its rows", .timeLimit(.minutes(1)))
    func abandonedFetchIsNotJoined() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        let cancellationImmuneGate = Task { for await _ in gate {} }
        network.historicalFetchBarrier = { await cancellationImmuneGate.value }
        let coordinator = Self.makeCoordinator(network: network)

        let abandoned = Task { try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange) }
        await waitUntil { network.fetchHistoricalRatesCalls.count == 1 }
        abandoned.cancel()
        let narrowRange = DateRange.spanning(Self.day(-2), Self.day(0))
        let fresh = Task { try await coordinator.fetchAndMergeHistoricalRates(in: narrowRange) }
        await waitUntil { network.fetchHistoricalRatesCalls.count == 2 }
        openGate.finish()

        #expect(try await fresh.value.map(\.date) == [Self.fetchedDay])
        await #expect(throws: CancellationError.self) {
            _ = try await abandoned.value
        }
    }

    // MARK: - Transient pair fetches

    @Test("a transient pair fetch returns snapshots but caches, persists, records, and stamps nothing")
    func transientFetchLeavesEveryStoreUntouched() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let persistence = MockPersistenceService()
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        let snapshots = try await coordinator.fetchTransientHistoricalRates(for: ["EUR", "GBP"], in: Self.dateRange)
        _ = try await coordinator.earliestStoredDate()

        #expect(snapshots.count == 1)
        let quotes = try #require(network.fetchHistoricalRatesQuotesCalls.first)
        #expect(Set(quotes.quotes) == Set(["EUR", "GBP"]))
        #expect(await persistence.savedHistoricalRates.isEmpty)
        #expect(await coordinator.cachedHistoricalRates().isEmpty)
        #expect(syncStore.recordCallCount == 0)
        #expect(coordinator.lastFetchDate() == nil)
    }

    @Test("a transient fetch in flight when clearAllData runs surfaces nothing", .timeLimit(.minutes(1)))
    func clearAllDataFencesInFlightTransientFetches() async throws {
        let (network, openGate) = Self.gatedNetwork()
        let coordinator = Self.makeCoordinator(network: network)

        let fetchTask = Task { try await coordinator.fetchTransientHistoricalRates(for: ["EUR"], in: Self.dateRange) }
        await waitUntil { network.fetchHistoricalRatesQuotesCalls.isEmpty == false }
        try await coordinator.clearAllData()
        openGate.finish()

        await #expect(throws: CancellationError.self) {
            _ = try await fetchTask.value
        }
    }

    @Test("a history fetch leaves the latest-rates fetch date alone")
    func historyFetchDoesNotStampRatesFetchDate() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let coordinator = Self.makeCoordinator(network: network)

        _ = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        _ = try await coordinator.earliestStoredDate()

        #expect(coordinator.lastFetchDate() == nil)
    }

    // MARK: - Persist-only fetches

    @Test("a persist-only fetch returns after its save landed and coverage was recorded, leaving the series alone")
    func fetchAndPersistSavesAndRecords() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let persistence = MockPersistenceService()
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        try await coordinator.fetchAndPersistHistoricalRates(in: Self.dateRange)

        #expect(await persistence.savedHistoricalRates.count == 1)
        #expect(syncStore.from == Self.startDate)
        #expect(syncStore.through == Self.endDate)
        #expect(await coordinator.cachedHistoricalRates().isEmpty)
        #expect(coordinator.lastFetchDate() == nil)
    }

    @Test("a persist-only fetch whose save fails throws and records no coverage")
    func fetchAndPersistThrowsWhenTheSaveFails() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let persistence = MockPersistenceService()
        await persistence.stubSaveHistoricalError(AppError.unknownError("disk full"))
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        await #expect(throws: AppError.self) {
            try await coordinator.fetchAndPersistHistoricalRates(in: Self.dateRange)
        }
        #expect(syncStore.recordCallCount == 0)
    }

    @Test("archive stored bounds include the days an in-flight merging fetch is about to persist", .timeLimit(.minutes(1)))
    func archiveStoredBoundsIncludeInFlightMergingFetches() async throws {
        let (network, openGate) = Self.gatedNetwork()
        let coordinator = Self.makeCoordinator(network: network)
        let started = StartedWaiters()

        let fetch = Task { try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange) }
        await waitUntil { network.fetchHistoricalRatesCalls.count == 1 }
        let bounds = Task {
            started.record()
            return try await coordinator.archiveStoredBounds()
        }
        await waitUntil { started.count == 1 }
        openGate.finish()

        let stored = try await bounds.value
        #expect(stored.earliest == Self.fetchedDay)
        #expect(stored.latest == Self.fetchedDay)
        #expect(try await fetch.value.map(\.date) == [Self.fetchedDay])
    }

    // MARK: - clearAllData barrier

    @Test("clearAllData settles pending writes; nothing is saved or recorded after the wipe")
    func clearAllDataSettlesPendingWrites() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let persistence = MockPersistenceService()
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        _ = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        try await coordinator.clearAllData()

        #expect(await persistence.clearAllDataCallCount == 1)
        #expect(await persistence.savedHistoricalAfterClear == false)
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)

        _ = try await coordinator.earliestStoredDate()
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
        #expect(await coordinator.cachedHistoricalRates().isEmpty)
    }

    @Test("a write scheduled while clearAllData waits is still awaited afterwards", .timeLimit(.minutes(1)))
    func clearAllDataKeepsWritesScheduledDuringTheClear() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.oneDayResponse)
        let persistence = MockPersistenceService()
        let (firstSave, openFirstSave) = AsyncStream.makeStream(of: Void.self)
        let (secondSave, openSecondSave) = AsyncStream.makeStream(of: Void.self)
        await persistence.gateHistoricalSave(number: 1, on: firstSave)
        await persistence.gateHistoricalSave(number: 2, on: secondSave)
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        _ = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        while await persistence.historicalSaveAttempts < 1 { await Task.yield() }
        let clear = Task { try await coordinator.clearAllData() }
        await Task.yield()
        _ = try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange)
        openFirstSave.finish()
        try await clear.value

        Task {
            while await persistence.historicalSaveAttempts < 2 { await Task.yield() }
            openSecondSave.finish()
        }
        _ = try await coordinator.earliestStoredDate()

        #expect(syncStore.from == Self.startDate)
    }

    @Test("a fetch in flight when clearAllData runs cannot persist, record, or surface data", .timeLimit(.minutes(1)))
    func clearAllDataFencesInFlightFetches() async throws {
        let (network, openGate) = Self.gatedNetwork()
        let persistence = MockPersistenceService()
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        let fetchTask = Task { try await coordinator.fetchAndMergeHistoricalRates(in: Self.dateRange) }
        await waitUntil { network.fetchHistoricalRatesCalls.isEmpty == false }
        try await coordinator.clearAllData()
        openGate.finish()

        await #expect(throws: CancellationError.self) {
            _ = try await fetchTask.value
        }

        _ = try await coordinator.earliestStoredDate()
        #expect(await persistence.savedHistoricalRates.isEmpty)
        #expect(await persistence.savedHistoricalAfterClear == false)
        #expect(await coordinator.cachedHistoricalRates().isEmpty)
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
    }
}

private final class StartedWaiters {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
