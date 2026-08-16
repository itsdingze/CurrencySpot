import Foundation

// MARK: - HistoricalDataAnalysisUseCase

final class HistoricalDataAnalysisUseCase {
    // MARK: - Dependencies

    private let syncCoverage: SyncCoverageRepository
    private let dateProvider: DateProvider
    private let logger: LoggerService

    init(
        syncCoverage: SyncCoverageRepository,
        dateProvider: DateProvider = SystemDateProvider(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.syncCoverage = syncCoverage
        self.dateProvider = dateProvider
        self.logger = logger
    }

    // MARK: - Date Range Calculations

    func calculateDateRange(for timeRange: TimeRange) -> DateRange {
        let now = dateProvider.now()
        let calendar = TimeZoneManager.cetCalendar

        let endDate = calendar.startOfDay(for: now)
        let rawStartDate = timeRange.startDate(from: now)
        let startDate = calendar.startOfDay(for: rawStartDate)

        return DateRange.spanning(startDate, endDate)
    }

    // MARK: - Data Gap Detection

    func calculateMissingDateRanges(
        requiredRange: DateRange,
        cache: CurrencyCache?
    ) async throws -> [DateRange] {
        guard let cache, !cache.isEmpty,
              let earliestDate = cache.earliestDate,
              let latestDate = cache.latestDate
        else {
            return [requiredRange]
        }

        let calendar = TimeZoneManager.cetCalendar
        let cachedEarliest = calendar.startOfDay(for: earliestDate)
        let cachedLatest = calendar.startOfDay(for: latestDate)

        var missingRanges: [DateRange] = []

        if requiredRange.start < cachedEarliest {
            guard let endDate = calendar.date(byAdding: .day, value: -1, to: cachedEarliest) else {
                throw AppError.dateCalculationError("Could not calculate end date for gap detection. Failed to subtract 1 day from \(cachedEarliest)")
            }
            missingRanges.append(try DateRange.make(start: requiredRange.start, end: endDate))
            logger.warning("Gap BEFORE cache: need \(TimeZoneManager.formatForAPI(requiredRange.start)) to \(TimeZoneManager.formatForAPI(endDate))", category: .useCase)
        }

        if requiredRange.end > cachedLatest {
            guard let startDate = calendar.date(byAdding: .day, value: 1, to: cachedLatest) else {
                throw AppError.dateCalculationError("Could not calculate start date for gap detection. Failed to add 1 day to \(cachedLatest)")
            }
            missingRanges.append(try DateRange.make(start: startDate, end: requiredRange.end))
            logger.warning("Gap AFTER cache: need \(TimeZoneManager.formatForAPI(startDate)) to \(TimeZoneManager.formatForAPI(requiredRange.end))", category: .useCase)
        }
        return missingRanges
    }

    func shouldFetchGap(_ gap: DateRange, now: Date) -> Bool {
        let calendar = TimeZoneManager.cetCalendar

        guard let from = syncCoverage.coveredFrom, let through = syncCoverage.coveredThrough else {
            return true
        }

        let from0 = calendar.startOfDay(for: from)
        let through0 = calendar.startOfDay(for: through)
        let start0 = calendar.startOfDay(for: gap.start)
        let end0 = calendar.startOfDay(for: gap.end)

        if start0 < from0 { return true }
        if end0 > through0 { return true }

        let today0 = calendar.startOfDay(for: now)
        guard end0 == through0, through0 == today0 else { return false }
        return RateRefreshPolicy.shouldRefetch(now: now, lastFetch: syncCoverage.coverageCheckedAt)
    }

    func repairCoverage(from: Date, through: Date) {
        syncCoverage.recordCoverage(from: from, through: through, at: dateProvider.now())
    }

    func isRangeCovered(_ range: DateRange) -> Bool {
        guard let from = syncCoverage.coveredFrom, let through = syncCoverage.coveredThrough else { return false }
        let calendar = TimeZoneManager.cetCalendar
        return calendar.startOfDay(for: from) <= calendar.startOfDay(for: range.start)
            && calendar.startOfDay(for: through) >= calendar.startOfDay(for: range.end)
    }

    // MARK: - Data Merging

    func mergeHistoricalData(
        existing: [HistoricalRateSnapshot],
        new: [HistoricalRateSnapshot]
    ) -> [HistoricalRateSnapshot] {
        HistoricalRateSnapshot.merge(existing: existing, new: new)
    }
}
