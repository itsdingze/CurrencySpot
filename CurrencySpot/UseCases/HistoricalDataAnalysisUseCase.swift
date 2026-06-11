//
//  HistoricalDataAnalysisUseCase.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation

// MARK: - HistoricalDataAnalysisUseCase

/// Use case responsible for historical data analysis business logic
/// Extracted from HistoryViewModel to separate concerns
final class HistoricalDataAnalysisUseCase {
    // MARK: - Dependencies

    private let syncStore: HistoricalSyncStore
    private let dateProvider: DateProvider
    private let logger: LoggerService

    /// - Parameter syncStore: Records the date window already fetched from the API.
    ///   Wired explicitly by `DependencyContainer`; tests inject an isolated store.
    init(
        syncStore: HistoricalSyncStore,
        dateProvider: DateProvider = SystemDateProvider(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.syncStore = syncStore
        self.dateProvider = dateProvider
        self.logger = logger
    }

    // MARK: - Date Range Calculations

    /// Calculates the date range based on selected time range
    func calculateDateRange(for timeRange: TimeRange) -> DateRange {
        let now = dateProvider.now()
        let calendar = TimeZoneManager.cetCalendar

        // Safe date calculations with fallback
        let endDate = calendar.startOfDay(for: now)
        let rawStartDate = timeRange.startDate(from: now)
        let startDate = calendar.startOfDay(for: rawStartDate)

        return DateRange(start: startDate, end: endDate)
    }

    // MARK: - Data Gap Detection

    /// Calculate the missing date ranges given a required range and existing cache
    func calculateMissingDateRanges(
        requiredRange: DateRange,
        cache: CurrencyCache?
    ) async throws -> [DateRange] {
        guard let cache, !cache.isEmpty,
              let earliestDate = cache.earliestDate,
              let latestDate = cache.latestDate
        else {
            return [requiredRange] // No data at all, need everything
        }

        // Use cached metadata instead of expensive operations - O(1) instead of O(n log n)
        let calendar = TimeZoneManager.cetCalendar
        let cachedEarliest = calendar.startOfDay(for: earliestDate)
        let cachedLatest = calendar.startOfDay(for: latestDate)

        var missingRanges: [DateRange] = []

        // Emit every gap versus the in-memory cache. Whether a gap is actually fetched from the API
        // is decided later by `shouldFetchGap` (coverage-based), not by ECB calendar guesses — v2 is
        // multi-source and may publish on any day, so suppressing "weekend" gaps would lose real data.
        if requiredRange.start < cachedEarliest {
            guard let endDate = calendar.date(byAdding: .day, value: -1, to: cachedEarliest) else {
                throw AppError.dateCalculationError("Could not calculate end date for gap detection. Failed to subtract 1 day from \(cachedEarliest)")
            }
            missingRanges.append(DateRange(start: requiredRange.start, end: endDate))
            logger.warning("Gap BEFORE cache: need \(TimeZoneManager.formatForAPI(requiredRange.start)) to \(TimeZoneManager.formatForAPI(endDate))", category: .useCase)
        }

        if requiredRange.end > cachedLatest {
            guard let startDate = calendar.date(byAdding: .day, value: 1, to: cachedLatest) else {
                throw AppError.dateCalculationError("Could not calculate start date for gap detection. Failed to add 1 day to \(cachedLatest)")
            }
            missingRanges.append(DateRange(start: startDate, end: requiredRange.end))
            logger.warning("Gap AFTER cache: need \(TimeZoneManager.formatForAPI(startDate)) to \(TimeZoneManager.formatForAPI(requiredRange.end))", category: .useCase)
        }
        return missingRanges
    }

    /// Decides whether a gap is worth an API fetch, based on what we've already fetched/checked.
    ///
    /// Replaces the old ECB calendar prediction. A gap is worth fetching when it reaches outside the
    /// covered `[from, through]` window. Inside the window, dates were already checked, so an absent
    /// rate means v2 has no data — don't refetch — EXCEPT the live edge (today), which is rechecked
    /// once the freshness window (`RateRefreshPolicy`) lapses so late-arriving data is still caught.
    func shouldFetchGap(gapStart: Date, gapEnd: Date, now: Date) -> Bool {
        let calendar = TimeZoneManager.cetCalendar

        guard let from = syncStore.from, let through = syncStore.through else {
            return true // never synced anything
        }

        let from0 = calendar.startOfDay(for: from)
        let through0 = calendar.startOfDay(for: through)
        let start0 = calendar.startOfDay(for: gapStart)
        let end0 = calendar.startOfDay(for: gapEnd)

        if start0 < from0 { return true } // older than anything fetched → back-fill
        if end0 > through0 { return true } // newer than anything fetched

        // Fully inside the checked window. Only today's still-moving edge may be rechecked.
        let today0 = calendar.startOfDay(for: now)
        guard end0 == through0, through0 == today0 else { return false }
        return RateRefreshPolicy.shouldRefetch(now: now, lastFetch: syncStore.checkedAt)
    }

    /// Records that `[from, through]` has now been fetched/checked. Called after every successful
    /// fetch — including ones that return no rows — so empty days count as checked.
    func recordSync(from: Date, through: Date, now: Date) {
        syncStore.record(from: from, through: through, at: now)
    }

    // MARK: - Data Merging

    /// Merges existing and new historical data, removing duplicates and maintaining sort order
    func mergeHistoricalData(
        existing: [HistoricalRateDataValue],
        new: [HistoricalRateDataValue]
    ) -> [HistoricalRateDataValue] {
        // Create a dictionary for fast lookup of existing dates
        var existingByDate: [String: HistoricalRateDataValue] = [:]
        for item in existing {
            existingByDate[TimeZoneManager.formatForAPI(item.date)] = item
        }

        // Add new items, overwriting any duplicates
        for item in new {
            existingByDate[TimeZoneManager.formatForAPI(item.date)] = item
        }

        // Convert back to array and sort by date
        return existingByDate.values.sorted { first, second in
            first.date < second.date
        }
    }
}
