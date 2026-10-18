@testable import CurrencySpot
import Foundation
import Testing

@Suite("BackfillArchiveUseCase Tests")
struct BackfillArchiveUseCaseTests {
    // MARK: - Fixtures

    private static let calendar = CETCalendar.calendar
    private static let baseDate = createCETDate(year: 2025, month: 1, day: 15)!

    private static func day(_ offset: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: baseDate)!)
    }

    private static let archiveRange = DateRange.spanning(day(-1827), day(0))

    private static func makeUseCase(
        repository: MockHistoricalRateRepository,
        syncStore: MockHistoricalSyncStore,
        clock: ClockService = GatedClock()
    ) -> BackfillArchiveUseCase {
        BackfillArchiveUseCase(
            archive: repository,
            analysis: HistoricalDataAnalysisUseCase(syncCoverage: syncStore, dateProvider: FixedDateProvider(baseDate)),
            clock: clock
        )
    }

    private static func residentYearStored(in repository: MockHistoricalRateRepository) -> MockHistoricalSyncStore {
        repository.earliestStoredDateResult = day(-365)
        repository.latestStoredDateResult = day(0)
        let syncStore = MockHistoricalSyncStore(from: day(-365), through: day(0), checkedAt: day(0))
        repository.syncStoreForPersist = syncStore
        return syncStore
    }

    // MARK: - Chunked download

    @Test("backfillArchive fetches the archive gap in adjacent half-year chunks, newest first")
    func fetchesGapInChunks() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = Self.residentYearStored(in: repository)
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
        #expect(repository.fetchHistoricalRatesCalls.isEmpty)
        #expect(repository.series.isEmpty)
    }

    @Test("the gap is anchored at days an in-flight merging fetch is still writing")
    func gapWaitsForInFlightMergingFetches() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = MockHistoricalSyncStore()
        repository.syncStoreForPersist = syncStore
        repository.inFlightMergingFetchesSettle = {
            repository.earliestStoredDateResult = Self.day(-365)
            repository.latestStoredDateResult = Self.day(0)
            syncStore.record(from: Self.day(-365), through: Self.day(0), at: Self.day(0))
        }
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        #expect(repository.fetchAndPersistCalls.first?.to == Self.day(-365))
        #expect(repository.fetchAndPersistCalls.count == 8)
    }

    @Test("concurrent backfills share one archive download", .timeLimit(.minutes(1)))
    func concurrentBackfillsShareOneDownload() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = Self.residentYearStored(in: repository)
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)
        let started = StartedBackfills()

        let first = Task {
            started.record()
            await useCase.backfillArchive()
        }
        let second = Task {
            started.record()
            await useCase.backfillArchive()
        }
        await waitUntil { started.count == 2 }
        openGate.finish()
        _ = await (first.value, second.value)

        #expect(repository.fetchAndPersistCalls.count == 8)
    }

    @Test("backfillArchive is a no-op once the watermark covers the archive")
    func skipsWhenCovered() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-1827)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-1827), through: Self.day(0), checkedAt: Self.day(0))
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        #expect(repository.fetchAndPersistCalls.isEmpty)
        #expect(syncStore.recordCallCount == 0)
    }

    @Test("backfillArchive repairs a watermark that under-claims persisted rows")
    func repairsUnderClaimingWatermark() async throws {
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

    // MARK: - Pruning

    @Test("a complete backfill drops stored days older than the five-year window")
    func completeBackfillPrunesOlderDays() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-2000)
        repository.latestStoredDateResult = Self.day(0)
        let syncStore = MockHistoricalSyncStore(from: Self.day(-2000), through: Self.day(0), checkedAt: Self.day(0))
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        #expect(try await repository.earliestStoredDate() == Self.archiveRange.start)
    }

    @Test("a failed backfill keeps every stored day")
    func failedBackfillKeepsOlderDays() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = Self.day(-2000)
        repository.latestStoredDateResult = Self.day(-400)
        repository.shouldThrowErrorOnFetch = true
        let syncStore = MockHistoricalSyncStore(from: Self.day(-2000), through: Self.day(-400), checkedAt: Self.day(-400))
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        await useCase.backfillArchive()

        #expect(try await repository.earliestStoredDate() == Self.day(-2000))
        useCase.reset()
    }

    // MARK: - Delayed re-runs

    @Test("a failed chunk stops the run and the delayed re-run resumes from where it left off", .timeLimit(.minutes(1)))
    func failedChunkResumes() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = Self.residentYearStored(in: repository)
        repository.fetchAndPersistFailAtCall = 3
        let clock = GatedClock()
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore, clock: clock)

        await useCase.backfillArchive()
        #expect(repository.fetchAndPersistCalls.count == 3)
        await clock.waitForSleepRequests(1)
        clock.release()
        await useCase.backfillArchive()

        #expect(repository.fetchAndPersistCalls.count == 9)
        #expect(syncStore.from == Self.archiveRange.start)
    }

    @Test("a chunk whose save leaves no coverage aborts the run; the re-run refetches instead of repairing over the hole", .timeLimit(.minutes(1)))
    func unrecordedChunkAbortsAndResumes() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = Self.residentYearStored(in: repository)
        repository.coverageSkippedAtCall = 3
        let clock = GatedClock()
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore, clock: clock)

        await useCase.backfillArchive()
        #expect(repository.fetchAndPersistCalls.count == 3)
        await clock.waitForSleepRequests(1)
        clock.release()
        await useCase.backfillArchive()

        #expect(repository.fetchAndPersistCalls.count == 9)
        #expect(syncStore.from == Self.archiveRange.start)
    }

    @Test("delayed re-runs stop after the retry budget", .timeLimit(.minutes(1)))
    func retriesAreBounded() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = Self.residentYearStored(in: repository)
        repository.shouldThrowErrorOnFetch = true
        let clock = GatedClock()
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore, clock: clock)

        await useCase.backfillArchive()
        await clock.waitForSleepRequests(1)
        clock.release()
        await clock.waitForSleepRequests(2)
        await useCase.backfillArchive()
        await useCase.backfillArchive()

        #expect(repository.fetchAndPersistCalls.count == 3)
        #expect(clock.sleepRequestCount == 2)
    }

    @Test("a second failing run replaces its delayed re-run instead of orphaning it", .timeLimit(.minutes(1)))
    func secondFailingRunReplacesTheReRun() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = Self.residentYearStored(in: repository)
        repository.shouldThrowErrorOnFetch = true
        let clock = GatedClock()
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore, clock: clock)

        await useCase.backfillArchive()
        await useCase.backfillArchive()
        await clock.waitForSleepRequests(2)

        #expect(clock.cancelledSleepCount == 1)
        useCase.reset()
    }

    @Test("reset cancels the scheduled re-run, clears exhaustion, and restores the retry budget", .timeLimit(.minutes(1)))
    func resetRestoresTheRetryBudget() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = Self.residentYearStored(in: repository)
        repository.shouldThrowErrorOnFetch = true
        let clock = GatedClock()
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore, clock: clock)

        await useCase.backfillArchive()
        await useCase.backfillArchive()
        await useCase.backfillArchive()
        await clock.waitForSleepRequests(2)

        useCase.reset()
        #expect(clock.cancelledSleepCount == 2)

        await useCase.backfillArchive()
        await clock.waitForSleepRequests(3)

        #expect(repository.fetchAndPersistCalls.count == 4)
        useCase.reset()
    }

    @Test("a backfill after reset starts a fresh run instead of joining the reset one", .timeLimit(.minutes(1)))
    func backfillAfterResetStartsAFreshRun() async throws {
        let repository = MockHistoricalRateRepository()
        let syncStore = Self.residentYearStored(in: repository)
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        let cancellationImmuneGate = Task { for await _ in gate {} }
        repository.fetchBarrier = { await cancellationImmuneGate.value }
        let useCase = Self.makeUseCase(repository: repository, syncStore: syncStore)

        let resetRun = Task { await useCase.backfillArchive() }
        await waitUntil { repository.fetchAndPersistCalls.count == 1 }
        useCase.reset()
        let freshRun = Task { await useCase.backfillArchive() }
        await waitUntil { repository.fetchAndPersistCalls.count == 2 }
        openGate.finish()
        _ = await (resetRun.value, freshRun.value)

        #expect(repository.fetchAndPersistCalls[1].to == Self.day(-365))
    }
}

private final class StartedBackfills {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
