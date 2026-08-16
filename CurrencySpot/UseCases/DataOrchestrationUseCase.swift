import Foundation

// MARK: - DataOrchestrationUseCase

final class DataOrchestrationUseCase {
    // MARK: - Dependencies

    private let repository: HistoricalRateRepository
    private let historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase
    private let dateProvider: DateProvider
    private let logger: LoggerService
    private let clock: ClockService

    // MARK: - Initialization

    init(
        repository: HistoricalRateRepository,
        historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase,
        dateProvider: DateProvider = SystemDateProvider(),
        logger: LoggerService = OSLogLoggerService(),
        clock: ClockService = ContinuousClockService()
    ) {
        self.repository = repository
        self.historicalDataAnalysisUseCase = historicalDataAnalysisUseCase
        self.dateProvider = dateProvider
        self.logger = logger
        self.clock = clock
    }

    // MARK: - Single-Flight Fetch

    private struct FetchKey: Hashable {
        let start: Date
        let end: Date
    }

    private var inFlightFetches: [FetchKey: Task<[HistoricalRateSnapshot], Error>] = [:]

    private var fetchGeneration = 0

    func dropInFlightFetches() {
        fetchGeneration += 1
        for fetch in inFlightFetches.values {
            fetch.cancel()
        }
        inFlightFetches.removeAll()
        backfillGeneration += 1
        backfillTask?.cancel()
        backfillTask = nil
        backfillRetryTask?.cancel()
        backfillRetryTask = nil
        backfillRetriesRemaining = Self.backfillRetryBudget
        backfillExhausted = false
    }

    private func fetchJoiningInFlight(_ range: DateRange) async throws -> [HistoricalRateSnapshot] {
        let calendar = TimeZoneManager.cetCalendar
        let key = FetchKey(start: calendar.startOfDay(for: range.start), end: calendar.startOfDay(for: range.end))

        if let covering = inFlightFetches.first(where: { $0.key.start <= key.start && $0.key.end >= key.end })?.value {
            logger.debug("Joining in-flight fetch covering \(TimeZoneManager.formatForAPI(range.start)) to \(TimeZoneManager.formatForAPI(range.end))", category: .network)
            let superset = try await covering.value
            return superset.filter { $0.date >= key.start && $0.date <= key.end }
        }

        let fetch = Task { [repository] in
            try await repository.fetchHistoricalRates(in: range)
        }
        let generation = fetchGeneration
        inFlightFetches[key] = fetch
        defer {
            if generation == fetchGeneration {
                inFlightFetches[key] = nil
            }
        }
        return try await fetch.value
    }

    // MARK: - Public Interface

    private static let residentWindowDays = 370

    static func isArchiveRange(_ range: DateRange) -> Bool {
        let days = TimeZoneManager.cetCalendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        return days > residentWindowDays
    }

    func loadHistoricalData(
        for currency: CurrencyCode,
        dateRange: DateRange
    ) async throws -> HistoricalLoadResult {
        try await loadHistoricalData(for: currency, base: .usd, dateRange: dateRange)
    }

    func loadHistoricalData(
        for currency: CurrencyCode,
        base: CurrencyCode,
        dateRange: DateRange
    ) async throws -> HistoricalLoadResult {
        if Self.isArchiveRange(dateRange) {
            return try await loadArchiveData(for: currency, base: base, dateRange: dateRange)
        }
        return try await loadResidentData(for: currency, dateRange: dateRange)
    }

    private func loadArchiveData(
        for currency: CurrencyCode,
        base: CurrencyCode,
        dateRange: DateRange
    ) async throws -> HistoricalLoadResult {
        let calendar = TimeZoneManager.cetCalendar
        let coverageEnd = calendar.date(byAdding: .day, value: -1, to: dateRange.end) ?? dateRange.end
        if historicalDataAnalysisUseCase.isRangeCovered(try DateRange.make(start: dateRange.start, end: coverageEnd)) {
            do {
                let rows = try await repository.loadHistoricalRates(in: dateRange)
                if !rows.isEmpty {
                    logger.infoPrivate("Archive range served from the blob store for \(currency)", category: .persistence)
                    return .cached(rows)
                }
            } catch {
                logger.warning("Archive store read failed: \(error.localizedDescription)", category: .persistence)
            }
        }

        Task { await backfillArchive() }

        let pair = Array(Set([currency, base]).subtracting([CurrencyCode.usd]))
        guard !pair.isEmpty else {
            return .cached(Self.emptyDayGrid(for: dateRange))
        }

        do {
            let snapshots = try await repository.fetchTransientHistoricalRates(for: pair, in: dateRange)
            logger.infoPrivate("Archive range bridged with a transient pair fetch for \(currency)", category: .network)
            return .cached(snapshots)
        } catch {
            guard let earliest = try? await repository.earliestStoredDate(),
                  let coverageFloor = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: dateRange.start)),
                  calendar.startOfDay(for: earliest) <= coverageFloor,
                  let rows = try? await repository.loadHistoricalRates(in: dateRange),
                  !rows.isEmpty
            else { throw error }
            logger.info("Archive bridge failed; serving the stored archive instead: \(error.localizedDescription)", category: .persistence)
            return .cached(rows)
        }
    }

    private static func emptyDayGrid(for range: DateRange) -> [HistoricalRateSnapshot] {
        let calendar = TimeZoneManager.cetCalendar
        var snapshots: [HistoricalRateSnapshot] = []
        var date = calendar.startOfDay(for: range.start)
        let end = calendar.startOfDay(for: range.end)
        while date <= end {
            snapshots.append(HistoricalRateSnapshot(date: date, rates: []))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return snapshots
    }

    private func loadResidentData(
        for currency: CurrencyCode,
        dateRange: DateRange
    ) async throws -> HistoricalLoadResult {
        let cachedData = await repository.cachedHistoricalRates()
        let cache = cachedData.isEmpty ? nil : CurrencyCache(data: cachedData)

        let missingRanges: [DateRange]
        do {
            missingRanges = try await historicalDataAnalysisUseCase.calculateMissingDateRanges(
                requiredRange: dateRange,
                cache: cache
            )
        } catch {
            logger.warning("Error calculating missing ranges: \(error.localizedDescription)", category: .useCase)
            return .cached(cachedData)
        }

        if missingRanges.isEmpty {
            logger.infoPrivate("Cache hit: Using complete cached data for \(currency)", category: .cache)
            let cachedData = cache?.data ?? []
            return .cached(cachedData)
        }

        let (newDataPoints, actuallyFetchedRanges) = await fetchMissingRanges(missingRanges)

        let mergedData = await repository.mergeCachedHistoricalRates(newDataPoints)

        logger.infoPrivate("Cache updated: Loaded \(newDataPoints.count) new points for \(currency)", category: .cache)

        return HistoricalLoadResult(
            snapshots: mergedData,
            newDataFetched: !actuallyFetchedRanges.isEmpty,
            fetchedRanges: actuallyFetchedRanges
        )
    }

    private func fetchMissingRanges(
        _ missingRanges: [DateRange]
    ) async -> (points: [HistoricalRateSnapshot], fetchedRanges: [DateRange]) {
        var newDataPoints: [HistoricalRateSnapshot] = []
        var actuallyFetchedRanges: [DateRange] = []

        for missingRange in missingRanges {
            do {
                if let gap = try await fetchableGap(for: missingRange) {
                    do {
                        let fetched = try await fetchJoiningInFlight(gap)
                        actuallyFetchedRanges.append(gap)
                        newDataPoints.append(contentsOf: fetched)
                        logger.info("Fetched new data from API for range: \(TimeZoneManager.formatForAPI(gap.start)) to \(TimeZoneManager.formatForAPI(gap.end))", category: .network)
                        if gap.start <= missingRange.start, gap.end >= missingRange.end {
                            continue
                        }
                    } catch {
                        logger.warning("Failed to fetch from API: \(error.localizedDescription)", category: .network)
                    }
                } else {
                    logger.debug("Loading existing data from SwiftData for range: \(TimeZoneManager.formatForAPI(missingRange.start)) to \(TimeZoneManager.formatForAPI(missingRange.end))", category: .persistence)
                }

                let rangeData = try await repository.loadHistoricalRates(in: missingRange)
                newDataPoints.append(contentsOf: rangeData)
            } catch {
                logger.warning("Error loading data for range: \(error.localizedDescription)", category: .useCase)
            }
        }

        return (newDataPoints, actuallyFetchedRanges)
    }

    private var backfillTask: Task<Bool, Never>?

    private static let archiveChunkDays = 183

    private static let backfillRetryDelay: Duration = .seconds(90)

    private static let backfillRetryBudget = 2
    private var backfillRetriesRemaining = backfillRetryBudget

    private var backfillExhausted = false

    private var backfillGeneration = 0

    func backfillArchive() async {
        if let backfillTask {
            _ = await backfillTask.value
            return
        }
        guard !backfillExhausted else { return }

        let generation = backfillGeneration
        let task = Task { await runArchiveBackfill() }
        backfillTask = task
        defer {
            if generation == backfillGeneration {
                backfillTask = nil
            }
        }
        if await task.value == false, generation == backfillGeneration {
            if backfillRetriesRemaining > 0 {
                scheduleBackfillRetry()
            } else {
                backfillExhausted = true
                logger.warning("Backfill retry budget exhausted; archive views bridge until the next launch or refresh", category: .network)
            }
        }
    }

    private var backfillRetryTask: Task<Void, Never>?

    private func scheduleBackfillRetry() {
        backfillRetriesRemaining -= 1
        logger.info("Archive backfill re-run scheduled (\(backfillRetriesRemaining) retries remaining)", category: .network)
        backfillRetryTask?.cancel()
        backfillRetryTask = Task {
            try? await clock.sleep(for: Self.backfillRetryDelay)
            guard !Task.isCancelled else { return }
            await backfillArchive()
        }
    }

    private func runArchiveBackfill() async -> Bool {
        // A bridge kick can race the resident warm-up: wait for registered fetches
        // (results discarded — nothing merges resident-ward here) and their deferred
        // persists, so the gap below anchors at stored data instead of re-downloading
        // the resident year.
        for fetch in Array(inFlightFetches.values) {
            _ = try? await fetch.value
        }
        await repository.waitForPendingHistoricalWrites()

        let archiveRange = historicalDataAnalysisUseCase.calculateDateRange(for: .fiveYears)
        do {
            guard let gap = try await fetchableGap(for: archiveRange) else {
                await repairCoverageIfUnderClaiming(for: archiveRange)
                return true
            }

            guard try await fetchArchiveInChunks(gap) else { return false }

            guard historicalDataAnalysisUseCase.isRangeCovered(archiveRange) else {
                logger.warning("Archive backfill fetched but coverage did not land; re-run needed", category: .network)
                return false
            }
            logger.info("Archive backfill complete: \(TimeZoneManager.formatForAPI(gap.start)) to \(TimeZoneManager.formatForAPI(gap.end))", category: .network)
            return true
        } catch {
            logger.warning("Archive backfill did not complete: \(error.localizedDescription)", category: .network)
            return false
        }
    }

    private func fetchArchiveInChunks(_ gap: DateRange) async throws -> Bool {
        let calendar = TimeZoneManager.cetCalendar
        var chunkEnd = gap.end
        while chunkEnd >= gap.start {
            let chunkStart = Swift.max(
                gap.start,
                calendar.date(byAdding: .day, value: -(Self.archiveChunkDays - 1), to: chunkEnd) ?? gap.start
            )
            let chunk = try DateRange.make(start: chunkStart, end: chunkEnd)
            try await repository.fetchAndPersistHistoricalRates(in: chunk)

            await repository.waitForPendingHistoricalWrites()
            guard historicalDataAnalysisUseCase.isRangeCovered(chunk) else {
                logger.warning("Archive chunk's persist did not land; aborting this run", category: .persistence)
                return false
            }

            guard let nextEnd = calendar.date(byAdding: .day, value: -1, to: chunkStart) else { break }
            chunkEnd = nextEnd
        }
        return true
    }

    private func repairCoverageIfUnderClaiming(for archiveRange: DateRange) async {
        guard !historicalDataAnalysisUseCase.isRangeCovered(archiveRange),
              let earliest = try? await repository.earliestStoredDate(),
              let latest = try? await repository.latestStoredDate()
        else { return }
        historicalDataAnalysisUseCase.repairCoverage(from: earliest, through: latest)
        logger.info("Coverage watermark repaired from stored bounds", category: .persistence)
    }

    func getCachedData(dateRange: DateRange) async -> [HistoricalRateSnapshot] {
        let cachedData = await repository.cachedHistoricalRates()

        return cachedData.filter { entry in
            entry.date >= dateRange.start && entry.date <= dateRange.end
        }
    }

    private func fetchableGap(for missingRange: DateRange) async throws -> DateRange? {
        guard let earliestStoredDate = try await repository.earliestStoredDate(),
              let latestStoredDate = try await repository.latestStoredDate()
        else {
            let shouldFetch = historicalDataAnalysisUseCase.shouldFetchGap(missingRange, now: dateProvider.now())
            return shouldFetch ? missingRange : nil
        }

        let calendar = TimeZoneManager.cetCalendar
        guard let gap = Self.unstoredGap(
            required: DateRange.spanning(calendar.startOfDay(for: missingRange.start), calendar.startOfDay(for: missingRange.end)),
            stored: DateRange.spanning(calendar.startOfDay(for: earliestStoredDate), calendar.startOfDay(for: latestStoredDate))
        ) else {
            return nil
        }

        return historicalDataAnalysisUseCase.shouldFetchGap(gap, now: dateProvider.now()) ? gap : nil
    }

    private static func unstoredGap(required: DateRange, stored: DateRange) -> DateRange? {
        if required.start < stored.start, required.end > stored.end {
            return required
        } else if required.start < stored.start {
            return DateRange.spanning(required.start, stored.start)
        } else if required.end > stored.end {
            return DateRange.spanning(stored.end, required.end)
        } else {
            return nil
        }
    }
}
