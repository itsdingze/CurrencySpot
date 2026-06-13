//
//  DataOrchestrationUseCase.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation

// MARK: - DataOrchestrationUseCase

/// Use case responsible for orchestrating historical data loading: gap detection,
/// fetch decisions, and merging. Cache mechanics live behind HistoricalRateRepository.
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

    /// Normalized day-range key for an in-flight network fetch.
    private struct FetchKey: Hashable {
        let start: Date
        let end: Date
    }

    /// In-flight network fetches. A load whose gap is covered by one of these joins it
    /// instead of issuing a duplicate request — otherwise the launch prefetch and a
    /// user's first chart tap would download the same window twice. MainActor isolation
    /// keeps check-and-insert atomic (no suspension between them).
    private var inFlightFetches: [FetchKey: Task<[HistoricalRateSnapshot], Error>] = [:]

    /// Bumped when the registry is dropped wholesale; an originator from an older
    /// generation must not evict a fresh fetch registered under its key.
    private var fetchGeneration = 0

    /// Empties the in-flight registry. Run after a data wipe: fetches that started
    /// before the wipe are epoch-doomed in the coordinator, and post-wipe loads
    /// joining them would inherit that failure while online.
    func dropInFlightFetches() {
        fetchGeneration += 1
        inFlightFetches.removeAll()
        // The backfill belongs to the doomed pre-wipe world too: a post-wipe warm-up
        // joining it would silently skip its archive tier. Cancel it, forget it, and
        // start the new world with a fresh retry budget.
        backfillGeneration += 1
        backfillTask?.cancel()
        backfillTask = nil
        backfillRetriesRemaining = Self.backfillRetryBudget
        backfillExhausted = false
    }

    /// Fetches a range, joining a covering in-flight fetch when one exists. A covering
    /// fetch's result is a superset of the requested range; it is clamped to the
    /// requested days so a joiner never carries more into the resident merge than its
    /// own gap asked for (the originating load still merges its full result).
    private func fetchJoiningInFlight(_ range: DateRange) async throws -> [HistoricalRateSnapshot] {
        let calendar = TimeZoneManager.cetCalendar
        let key = FetchKey(start: calendar.startOfDay(for: range.start), end: calendar.startOfDay(for: range.end))

        if let covering = inFlightFetches.first(where: { $0.key.start <= key.start && $0.key.end >= key.end })?.value {
            logger.debug("Joining in-flight fetch covering \(TimeZoneManager.formatForAPI(range.start)) to \(TimeZoneManager.formatForAPI(range.end))", category: .network)
            let superset = try await covering.value
            return superset.filter { $0.date >= key.start && $0.date <= key.end }
        }

        // Unstructured on purpose: the fetch must survive its originating load's
        // cancellation so joiners (and the shared cache) still receive the data.
        let fetch = Task { [repository] in
            try await repository.fetchHistoricalRates(from: range.start, to: range.end)
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

    /// Days a range may span and still be served by (and merged into) the resident
    /// in-memory series. Anything longer is archive territory: five years of every
    /// currency held resident would cost 20+ MB, so those ranges read from the blob
    /// store on demand instead.
    private static let residentWindowDays = 370

    /// Internal (not private) so the ViewModel's failure fallback can refuse to
    /// render the resident series for a range it can never legitimately cover.
    static func isArchiveRange(_ range: DateRange) -> Bool {
        let days = TimeZoneManager.cetCalendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        return days > residentWindowDays
    }

    /// Loads historical data for the specified currency and date range
    /// Returns the loaded data points and whether any new data was actually fetched from API
    func loadHistoricalData(
        for currency: CurrencyCode,
        dateRange: DateRange
    ) async throws -> (dataPoints: [HistoricalRateSnapshot], newDataFetched: Bool, fetchedRanges: [DateRange]) {
        try await loadHistoricalData(for: currency, base: .usd, dateRange: dateRange)
    }

    /// Loads historical data for the specified pair and date range. The base currency
    /// only matters on the archive bridge path, where a pair-scoped fetch needs both
    /// sides of the conversion.
    func loadHistoricalData(
        for currency: CurrencyCode,
        base: CurrencyCode,
        dateRange: DateRange
    ) async throws -> (dataPoints: [HistoricalRateSnapshot], newDataFetched: Bool, fetchedRanges: [DateRange]) {
        if Self.isArchiveRange(dateRange) {
            return try await loadArchiveData(for: currency, base: base, dateRange: dateRange)
        }
        return try await loadResidentData(for: currency, dateRange: dateRange)
    }

    /// Archive ranges never touch the resident series: covered ranges read from the
    /// blob store (milliseconds since the schema change); uncovered ones bridge with
    /// a one-off pair-scoped fetch until the background backfill lands.
    private func loadArchiveData(
        for currency: CurrencyCode,
        base: CurrencyCode,
        dateRange: DateRange
    ) async throws -> (dataPoints: [HistoricalRateSnapshot], newDataFetched: Bool, fetchedRanges: [DateRange]) {
        // Coverage is checked through yesterday: the watermark only reaches today
        // after the day's first live-edge fetch, and an archive chart doesn't need
        // today's still-moving row — requiring it would bypass (and offline, lose)
        // the entire local archive every new day.
        let calendar = TimeZoneManager.cetCalendar
        let coverageEnd = calendar.date(byAdding: .day, value: -1, to: dateRange.end) ?? dateRange.end
        if historicalDataAnalysisUseCase.isRangeCovered(DateRange(start: dateRange.start, end: coverageEnd)) {
            do {
                let rows = try await repository.loadHistoricalRates(in: dateRange)
                if !rows.isEmpty {
                    logger.infoPrivate("Archive range served from the blob store for \(currency)", category: .persistence)
                    return (dataPoints: rows, newDataFetched: false, fetchedRanges: [])
                }
            } catch {
                logger.warning("Archive store read failed: \(error.localizedDescription)", category: .persistence)
            }
        }

        // Backfill hasn't landed (or the read failed): bridge with a transient
        // pair-scoped fetch — and heal in the background so the session stops
        // degrading instead of bridging until the next launch. Unstructured so the
        // user's chart load never waits; single-flight and the bounded retry
        // budget keep repeat kicks cheap.
        Task { await backfillArchive() }

        let pair = Array(Set([currency, base]).subtracting([CurrencyCode.usd]))
        guard !pair.isEmpty else {
            // USD against USD is 1.0 by definition; synthesize the day grid instead
            // of claiming no data exists (the rate table treats absent USD as 1.0).
            return (dataPoints: Self.emptyDayGrid(for: dateRange), newDataFetched: false, fetchedRanges: [])
        }

        do {
            let snapshots = try await repository.fetchTransientHistoricalRates(
                for: pair,
                from: dateRange.start,
                to: dateRange.end
            )
            logger.infoPrivate("Archive range bridged with a transient pair fetch for \(currency)", category: .network)
            // newDataFetched stays false: nothing entered persistence, so trends must
            // not recalculate from this.
            return (dataPoints: snapshots, newDataFetched: false, fetchedRanges: [])
        } catch {
            // Bridge unreachable (offline): the stored archive beats an error — but
            // only when it actually reaches the requested start. Serving a partial
            // archive (say, just the resident year) as a loaded 5Y chart would mask
            // the failure the ViewModel is supposed to surface. ~7 days of tolerance
            // absorbs sparse publishing at the range start.
            guard let earliest = try? await repository.earliestStoredDate(),
                  let coverageFloor = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: dateRange.start)),
                  calendar.startOfDay(for: earliest) <= coverageFloor,
                  let rows = try? await repository.loadHistoricalRates(in: dateRange),
                  !rows.isEmpty
            else { throw error }
            logger.info("Archive bridge failed; serving the stored archive instead: \(error.localizedDescription)", category: .persistence)
            return (dataPoints: rows, newDataFetched: false, fetchedRanges: [])
        }
    }

    /// One snapshot per day with no rates — the USD/USD series, where every value
    /// is the rate table's implicit 1.0.
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

    /// Resident-window loads: gap-detect against the shared series, fetch what is
    /// missing, and merge the result back into the series.
    private func loadResidentData(
        for currency: CurrencyCode,
        dateRange: DateRange
    ) async throws -> (dataPoints: [HistoricalRateSnapshot], newDataFetched: Bool, fetchedRanges: [DateRange]) {
        // Step 1: Check the shared in-memory series first (one fetch covers every
        // currency, so any chart's load warms the cache for all of them)
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
            // If we can't calculate missing ranges, return what we have in cache
            return (dataPoints: cachedData, newDataFetched: false, fetchedRanges: [])
        }

        if missingRanges.isEmpty {
            // Cache covers everything we need
            logger.infoPrivate("Cache hit: Using complete cached data for \(currency)", category: .cache)
            let cachedData = cache?.data ?? []
            return (dataPoints: cachedData, newDataFetched: false, fetchedRanges: [])
        }

        // Step 2: Look at SwiftData and fetch missing data
        var newDataPoints: [HistoricalRateSnapshot] = []
        var actuallyFetchedRanges: [DateRange] = []

        for missingRange in missingRanges {
            do {
                // Only fetch the sub-range persistence doesn't already cover
                if let gap = try await fetchableGap(for: missingRange) {
                    do {
                        // Render-first: the fetch returns decoded snapshots directly. Reading
                        // them back from persistence would block on the deferred save.
                        let fetched = try await fetchJoiningInFlight(gap)
                        actuallyFetchedRanges.append(gap)
                        newDataPoints.append(contentsOf: fetched)
                        logger.info("Fetched new data from API for range: \(TimeZoneManager.formatForAPI(gap.start)) to \(TimeZoneManager.formatForAPI(gap.end))", category: .network)
                        // When the gap was the whole missing range there is nothing
                        // persisted left to read back.
                        if gap.start <= missingRange.start, gap.end >= missingRange.end {
                            continue
                        }
                    } catch {
                        logger.warning("Failed to fetch from API: \(error.localizedDescription)", category: .network)
                        // Fall through to whatever persistence already has for this range.
                    }
                } else {
                    logger.debug("Loading existing data from SwiftData for range: \(TimeZoneManager.formatForAPI(missingRange.start)) to \(TimeZoneManager.formatForAPI(missingRange.end))", category: .persistence)
                }

                let rangeData = try await repository.loadHistoricalRates(in: missingRange)
                newDataPoints.append(contentsOf: rangeData)
            } catch {
                logger.warning("Error loading data for range: \(error.localizedDescription)", category: .useCase)
                // Continue with next range
            }
        }

        // Step 3: Merge into the shared series. The merge is atomic inside the cache
        // actor, so loads that ran concurrently with this one union their rows
        // instead of last-writer-wins overwriting each other.
        let mergedData = await repository.mergeCachedHistoricalRates(newDataPoints)

        logger.infoPrivate("Cache updated: Loaded \(newDataPoints.count) new points for \(currency)", category: .cache)

        return (dataPoints: mergedData, newDataFetched: !actuallyFetchedRanges.isEmpty, fetchedRanges: actuallyFetchedRanges)
    }

    /// In-flight archive backfill; concurrent callers (launch warm-up overlapping a
    /// user-initiated refresh) join it instead of starting a second multi-MB download.
    private var backfillTask: Task<Bool, Never>?

    /// Half a year per request: a cold origin generates a multi-year series at
    /// ~15 KB/s (~90s for four years), far beyond the session's 30s resource
    /// timeout, while a six-month slice arrives in ~10s. Chunking also makes the
    /// backfill resumable — every landed chunk records coverage the next run skips.
    private static let archiveChunkDays = 183

    /// The CDN edge finishes pulling a slow series from origin roughly 90 seconds
    /// after a failed cold attempt and caches it for a day, so one late re-run
    /// nearly guarantees cache hits where fast backoff retries cannot.
    private static let backfillRetryDelay: Duration = .seconds(90)

    /// Delayed re-runs allowed per session (and per post-wipe world); bounded so a
    /// persistently offline session doesn't poll forever.
    private static let backfillRetryBudget = 2
    private var backfillRetriesRemaining = backfillRetryBudget

    /// Set once the retry budget is spent on failures: bridge kicks then stop
    /// re-running full chunk sweeps on every 5Y tap. Reset by the next wipe/launch.
    private var backfillExhausted = false

    /// Bumped by `dropInFlightFetches` so a doomed pre-wipe backfill can neither
    /// clobber a fresh run's registration nor burn the reset retry budget.
    private var backfillGeneration = 0

    /// Backfills the five-year archive into persistence without touching the resident
    /// in-memory series. Once its watermark records, every archive view reads from
    /// the blob store in milliseconds. An incomplete run schedules one delayed
    /// re-run; until coverage lands, archive views stay on the transient-fetch bridge.
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

    /// One late re-run, timed for the CDN's warm-up rather than a network blip.
    /// Unstructured on purpose: it must outlive the warm-up that spawned it.
    private func scheduleBackfillRetry() {
        backfillRetriesRemaining -= 1
        logger.info("Archive backfill re-run scheduled (\(backfillRetriesRemaining) retries remaining)", category: .network)
        Task {
            try? await clock.sleep(for: Self.backfillRetryDelay)
            await backfillArchive()
        }
    }

    /// - Returns: true when the archive needs no further work (covered, repaired,
    ///   or fully fetched with coverage committed); false when a re-run is needed.
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

            // Fetch-to-disk, deliberately OUTSIDE the in-flight registry: a resident
            // load joining a multi-year fetch would flood the resident series, and
            // mapping ~300k snapshots only to discard them is wasted work.
            //
            // Newest-first so every chunk lands adjacent to existing coverage and
            // the watermark grows contiguously; a failure below leaves the landed
            // chunks recorded for the re-run to skip.
            let calendar = TimeZoneManager.cetCalendar
            var chunkEnd = gap.end
            while chunkEnd >= gap.start {
                let chunkStart = Swift.max(
                    gap.start,
                    calendar.date(byAdding: .day, value: -(Self.archiveChunkDays - 1), to: chunkEnd) ?? gap.start
                )
                try await repository.fetchAndPersistHistoricalRates(from: chunkStart, to: chunkEnd)

                // The persist is deferred: confirm it committed (its coverage record
                // landed) before anchoring the next chunk past it. Persisting older
                // chunks beyond a silently failed save would leave an interior hole
                // that the re-run's coverage repair would then claim as covered —
                // permanently, since stored bounds would span the hole.
                await repository.waitForPendingHistoricalWrites()
                guard historicalDataAnalysisUseCase.isRangeCovered(DateRange(start: chunkStart, end: chunkEnd)) else {
                    logger.warning("Archive chunk's persist did not land; aborting this run", category: .persistence)
                    return false
                }

                guard let nextEnd = calendar.date(byAdding: .day, value: -1, to: chunkStart) else { break }
                chunkEnd = nextEnd
            }

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

    /// Heals a watermark that under-claims persisted rows (the store's contiguity
    /// guard can drop a record). Persistence grows contiguously — every fetched gap
    /// anchors at the stored edge — so claiming the stored bounds never spans
    /// unchecked dates, and it un-wedges archive reads that would otherwise bridge
    /// over the network forever.
    private func repairCoverageIfUnderClaiming(for archiveRange: DateRange) async {
        guard !historicalDataAnalysisUseCase.isRangeCovered(archiveRange),
              let earliest = try? await repository.earliestStoredDate(),
              let latest = try? await repository.latestStoredDate()
        else { return }
        historicalDataAnalysisUseCase.repairCoverage(from: earliest, through: latest)
        logger.info("Coverage watermark repaired from stored bounds", category: .persistence)
    }

    /// Gets cached data within the given date range. The shared series carries every
    /// currency, so the caller's pair selection happens downstream in chart preparation.
    func getCachedData(dateRange: DateRange) async -> [HistoricalRateSnapshot] {
        let cachedData = await repository.cachedHistoricalRates()

        // Filter cached data by current time range
        return cachedData.filter { entry in
            entry.date >= dateRange.start && entry.date <= dateRange.end
        }
    }

    /// The sub-range of `missingRange` actually worth a network fetch, or nil when stored
    /// data plus the coverage watermark show nothing new would come back. Scoping the
    /// fetch to the gap — instead of the whole missing range — keeps a new day's warm-up
    /// at a day or two of payload rather than re-downloading the full window; the
    /// persisted remainder is read back locally.
    private func fetchableGap(for missingRange: DateRange) async throws -> DateRange? {
        // Get both earliest and latest dates in single batch
        guard let earliestStoredDate = try await repository.earliestStoredDate(),
              let latestStoredDate = try await repository.latestStoredDate()
        else {
            // No stored data - fetch unless the coverage watermark says we already checked it
            let shouldFetch = historicalDataAnalysisUseCase.shouldFetchGap(
                gapStart: missingRange.start,
                gapEnd: missingRange.end,
                now: dateProvider.now()
            )
            return shouldFetch ? missingRange : nil
        }

        let calendar = TimeZoneManager.cetCalendar
        let requiredStart = calendar.startOfDay(for: missingRange.start)
        let requiredEnd = calendar.startOfDay(for: missingRange.end)
        let storedStart = calendar.startOfDay(for: earliestStoredDate)
        let storedEnd = calendar.startOfDay(for: latestStoredDate)

        // Determine the actual gap range that needs fetching
        let gapStart: Date
        let gapEnd: Date

        if requiredStart < storedStart, requiredEnd > storedEnd {
            // Required range spans beyond both ends - check entire missing range
            gapStart = requiredStart
            gapEnd = requiredEnd
        } else if requiredStart < storedStart {
            // Need data before earliest stored
            gapStart = requiredStart
            gapEnd = storedStart
        } else if requiredEnd > storedEnd {
            // Need data after latest stored
            gapStart = storedEnd
            gapEnd = requiredEnd
        } else {
            // Required range is within stored range — every day we need is already persisted.
            // This includes today once its data has landed: we deliberately don't re-poll it within
            // the day (intraday revisions are cosmetic, and refetching the whole window would
            // reintroduce over-fetching). The empty-today case takes the `requiredEnd > storedEnd`
            // branch above, where shouldFetchGap's TTL governs the live-edge recheck.
            return nil
        }

        // Fetch the consolidated gap unless the coverage watermark already covers it.
        // Anchoring at the stored bounds keeps recorded ranges adjacent to existing
        // coverage, preserving the contiguous-watermark invariant.
        let shouldFetch = historicalDataAnalysisUseCase.shouldFetchGap(
            gapStart: gapStart,
            gapEnd: gapEnd,
            now: dateProvider.now()
        )
        return shouldFetch ? DateRange(start: gapStart, end: gapEnd) : nil
    }
}
