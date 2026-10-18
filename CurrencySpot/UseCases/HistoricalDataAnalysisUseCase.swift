import Foundation
import OSLog

// MARK: - HistoricalDataAnalysisUseCase

final class HistoricalDataAnalysisUseCase {
    // MARK: - Dependencies

    private let syncCoverage: SyncCoverageRepository
    private let dateProvider: DateProvider
    private let logger = Logger(category: .useCase)

    init(syncCoverage: SyncCoverageRepository, dateProvider: DateProvider) {
        self.syncCoverage = syncCoverage
        self.dateProvider = dateProvider
    }

    // MARK: - Date Range Calculations

    func calculateDateRange(for timeRange: TimeRange) -> DateRange {
        let now = dateProvider.now()
        let calendar = CETCalendar.calendar

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

        let calendar = CETCalendar.calendar
        let cachedEarliest = calendar.startOfDay(for: earliestDate)
        let cachedLatest = calendar.startOfDay(for: latestDate)

        var missingRanges: [DateRange] = []

        if requiredRange.start < cachedEarliest {
            guard let endDate = calendar.date(byAdding: .day, value: -1, to: cachedEarliest) else {
                throw AppError.dateCalculationError("Could not calculate end date for gap detection. Failed to subtract 1 day from \(cachedEarliest)")
            }
            missingRanges.append(try DateRange.make(start: requiredRange.start, end: endDate))
            logger.debug("Gap before cache: \(CETCalendar.dayString(for: requiredRange.start), privacy: .public) to \(CETCalendar.dayString(for: endDate), privacy: .public)")
        }

        if requiredRange.end > cachedLatest {
            guard let startDate = calendar.date(byAdding: .day, value: 1, to: cachedLatest) else {
                throw AppError.dateCalculationError("Could not calculate start date for gap detection. Failed to add 1 day to \(cachedLatest)")
            }
            missingRanges.append(try DateRange.make(start: startDate, end: requiredRange.end))
            logger.debug("Gap after cache: \(CETCalendar.dayString(for: startDate), privacy: .public) to \(CETCalendar.dayString(for: requiredRange.end), privacy: .public)")
        }
        return missingRanges
    }

    func fetchableGap(for missingRange: DateRange, storedFrom earliestStored: Date?, storedThrough latestStored: Date?) -> DateRange? {
        let now = dateProvider.now()
        guard let earliestStored, let latestStored else {
            return shouldFetchGap(missingRange, now: now) ? missingRange : nil
        }

        let calendar = CETCalendar.calendar
        guard let gap = Self.unstoredGap(
            required: DateRange.spanning(calendar.startOfDay(for: missingRange.start), calendar.startOfDay(for: missingRange.end)),
            stored: DateRange.spanning(calendar.startOfDay(for: earliestStored), calendar.startOfDay(for: latestStored))
        ) else {
            return nil
        }

        return shouldFetchGap(gap, now: now) ? gap : nil
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

    func shouldFetchGap(_ gap: DateRange, now: Date) -> Bool {
        let calendar = CETCalendar.calendar

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
        let calendar = CETCalendar.calendar
        return calendar.startOfDay(for: from) <= calendar.startOfDay(for: range.start)
            && calendar.startOfDay(for: through) >= calendar.startOfDay(for: range.end)
    }
}
