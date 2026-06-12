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

    // MARK: - Initialization

    init(
        repository: HistoricalRateRepository,
        historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase,
        dateProvider: DateProvider = SystemDateProvider(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.repository = repository
        self.historicalDataAnalysisUseCase = historicalDataAnalysisUseCase
        self.dateProvider = dateProvider
        self.logger = logger
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

    /// Fetches a range, joining a covering in-flight fetch when one exists. A joined
    /// result is a superset of the requested range; the date-keyed merge makes the
    /// extra days harmless.
    private func fetchJoiningInFlight(_ range: DateRange) async throws -> [HistoricalRateSnapshot] {
        let calendar = TimeZoneManager.cetCalendar
        let key = FetchKey(start: calendar.startOfDay(for: range.start), end: calendar.startOfDay(for: range.end))

        if let covering = inFlightFetches.first(where: { $0.key.start <= key.start && $0.key.end >= key.end })?.value {
            logger.debug("Joining in-flight fetch covering \(TimeZoneManager.formatForAPI(range.start)) to \(TimeZoneManager.formatForAPI(range.end))", category: .network)
            return try await covering.value
        }

        // Unstructured on purpose: the fetch must survive its originating load's
        // cancellation so joiners (and the shared cache) still receive the data.
        let fetch = Task { [repository] in
            try await repository.fetchHistoricalRates(from: range.start, to: range.end)
        }
        inFlightFetches[key] = fetch
        defer { inFlightFetches[key] = nil }
        return try await fetch.value
    }

    // MARK: - Public Interface

    /// Loads historical data for the specified currency and date range
    /// Returns the loaded data points and whether any new data was actually fetched from API
    func loadHistoricalData(
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
