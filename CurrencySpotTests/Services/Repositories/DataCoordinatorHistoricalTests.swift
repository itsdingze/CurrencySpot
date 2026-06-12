//
//  DataCoordinatorHistoricalTests.swift
//  CurrencySpotTests
//
//  Render-first historical pipeline: fetches return decoded snapshots immediately,
//  persistence runs behind them, and the coverage watermark is recorded only after
//  the save commits.
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("DataCoordinator historical render-first pipeline")
struct DataCoordinatorHistoricalTests {
    // MARK: - Fixtures

    private static let calendar = TimeZoneManager.cetCalendar
    private static let now = createCETDate(year: 2025, month: 1, day: 15)!
    private static let startDate = calendar.date(byAdding: .day, value: -7, to: now)!
    private static let endDate = now

    private static func response(rates: [String: [String: Double]]) -> HistoricalRatesResponse {
        HistoricalRatesResponse(
            base: "USD",
            startDate: TimeZoneManager.formatForAPI(startDate),
            endDate: TimeZoneManager.formatForAPI(endDate),
            rates: rates
        )
    }

    private static func makeCoordinator(
        network: MockNetworkService,
        persistence: MockPersistenceService,
        syncStore: MockHistoricalSyncStore,
        cache: InMemoryCacheService = InMemoryCacheService()
    ) -> DataCoordinator {
        DataCoordinator(
            networkService: network,
            persistenceService: persistence,
            cacheService: cache,
            syncStore: syncStore,
            dateProvider: FixedDateProvider(now)
        )
    }

    // MARK: - Render-first contract

    @Test("fetchHistoricalRates returns decoded snapshots without waiting for the save")
    func fetchReturnsSnapshotsImmediately() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.response(rates: [
            "2025-01-14": ["EUR": 0.85, "GBP": 0.75],
            "2025-01-13": ["EUR": 0.84],
        ]))
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(
            network: network,
            persistence: MockPersistenceService(),
            syncStore: syncStore
        )

        let snapshots = try await coordinator.fetchHistoricalRates(from: Self.startDate, to: Self.endDate)

        #expect(snapshots.count == 2)
        #expect(snapshots.map(\.date) == snapshots.map(\.date).sorted())
        let firstDay = try #require(snapshots.first)
        #expect(firstDay.rates.first { $0.currencyCode == "EUR" }?.rate == 0.84)
        // Deferred save: at the moment data is returned, nothing has been recorded yet.
        #expect(syncStore.recordCallCount == 0)
    }

    @Test("the coverage watermark is recorded only after the deferred save commits")
    func watermarkRecordedAfterPersist() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.response(rates: [
            "2025-01-14": ["EUR": 0.85],
        ]))
        let persistence = MockPersistenceService()
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        _ = try await coordinator.fetchHistoricalRates(from: Self.startDate, to: Self.endDate)
        #expect(syncStore.recordCallCount == 0)

        await coordinator.waitForPendingHistoricalWrites()

        #expect(await persistence.savedHistoricalRates.count == 1)
        #expect(syncStore.recordCallCount == 1)
        #expect(syncStore.from == Self.startDate)
        #expect(syncStore.through == Self.endDate)
    }

    @Test("a failed save leaves the watermark unrecorded so the range is refetched later")
    func failedPersistDoesNotRecordCoverage() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.response(rates: [
            "2025-01-14": ["EUR": 0.85],
        ]))
        let persistence = MockPersistenceService()
        await persistence.stubSaveHistoricalError(AppError.unknownError("disk full"))
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        let snapshots = try await coordinator.fetchHistoricalRates(from: Self.startDate, to: Self.endDate)
        await coordinator.waitForPendingHistoricalWrites()

        // The render path still got its data, but coverage was not claimed.
        #expect(snapshots.count == 1)
        #expect(syncStore.recordCallCount == 0)
    }

    @Test("an empty response still records coverage so empty days are not refetched")
    func emptyResponseRecordsCoverage() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.response(rates: [:]))
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(
            network: network,
            persistence: MockPersistenceService(),
            syncStore: syncStore
        )

        let snapshots = try await coordinator.fetchHistoricalRates(from: Self.startDate, to: Self.endDate)
        await coordinator.waitForPendingHistoricalWrites()

        #expect(snapshots.isEmpty)
        #expect(syncStore.recordCallCount == 1)
    }

    @Test("a failed save evicts the un-persisted window from the shared series")
    func failedPersistEvictsWindowFromCache() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.response(rates: [
            "2025-01-14": ["EUR": 0.85],
        ]))
        let persistence = MockPersistenceService()
        await persistence.stubSaveHistoricalError(AppError.unknownError("disk full"))
        let cache = InMemoryCacheService()
        let coordinator = Self.makeCoordinator(
            network: network,
            persistence: persistence,
            syncStore: MockHistoricalSyncStore(),
            cache: cache
        )

        // The shared series already holds a row inside the fetch window (as the
        // orchestrator's merge would produce) and one outside it.
        let inWindow = HistoricalRateSnapshot(
            date: Self.calendar.date(byAdding: .day, value: -1, to: Self.endDate)!,
            rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 0.85)]
        )
        let outside = HistoricalRateSnapshot(
            date: Self.calendar.date(byAdding: .day, value: 1, to: Self.endDate)!,
            rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 0.86)]
        )
        await cache.cacheHistoricalData([inWindow, outside])

        _ = try await coordinator.fetchHistoricalRates(from: Self.startDate, to: Self.endDate)
        await coordinator.waitForPendingHistoricalWrites()

        // Only the failed window is evicted; unrelated rows survive.
        let remaining = await cache.getCachedHistoricalData() ?? []
        #expect(remaining.map(\.date) == [outside.date])
    }

    // MARK: - clearAllData barrier

    @Test("clearAllData settles pending writes; nothing is saved or recorded after the wipe")
    func clearAllDataSettlesPendingWrites() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.response(rates: [
            "2025-01-14": ["EUR": 0.85],
        ]))
        let persistence = MockPersistenceService()
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        _ = try await coordinator.fetchHistoricalRates(from: Self.startDate, to: Self.endDate)
        try await coordinator.clearAllData()

        #expect(await persistence.clearAllDataCallCount == 1)
        #expect(await persistence.savedHistoricalAfterClear == false)
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)

        // A late settle must not resurrect the watermark either.
        await coordinator.waitForPendingHistoricalWrites()
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
    }

    @Test("a fetch in flight when clearAllData runs cannot persist, record, or surface data", .timeLimit(.minutes(1)))
    func clearAllDataFencesInFlightFetches() async throws {
        let network = MockNetworkService()
        network.historicalRatesResult = .success(Self.response(rates: [
            "2025-01-14": ["EUR": 0.85],
        ]))
        var releaseFetch: (() -> Void)!
        let gate = AsyncStream<Void> { continuation in
            releaseFetch = { continuation.finish() }
        }
        network.historicalFetchBarrier = { for await _ in gate {} }

        let persistence = MockPersistenceService()
        let syncStore = MockHistoricalSyncStore()
        let coordinator = Self.makeCoordinator(network: network, persistence: persistence, syncStore: syncStore)

        // Park a fetch inside the network call, then clear while it is in flight.
        let fetchTask = Task { try await coordinator.fetchHistoricalRates(from: Self.startDate, to: Self.endDate) }
        while network.fetchHistoricalRatesCalls.isEmpty {
            await Task.yield()
        }
        try await coordinator.clearAllData()
        releaseFetch()

        // The stale fetch must fail rather than hand back pre-wipe data…
        await #expect(throws: CancellationError.self) {
            _ = try await fetchTask.value
        }

        // …and nothing it carried may reach persistence or the watermark.
        await coordinator.waitForPendingHistoricalWrites()
        #expect(await persistence.savedHistoricalRates.isEmpty)
        #expect(await persistence.savedHistoricalAfterClear == false)
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
    }
}
