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
    // MARK: - Constants

    /// Minimum number of days required to consider a gap as significant
    private static let minimumGapDays = 4

    // MARK: - Date Range Calculations

    /// Calculates the date range based on selected time range
    func calculateDateRange(for timeRange: TimeRange) -> DateRange {
        let now = Date()
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

        if requiredRange.start < cachedEarliest {
            let daysBetween = calendar.dateComponents([.day], from: requiredRange.start, to: cachedEarliest).day ?? 0
            if daysBetween > Self.minimumGapDays {
                // The gap is more than minimumGapDays, so we assume it's a real gap
                guard let endDate = calendar.date(byAdding: .day, value: -1, to: cachedEarliest) else {
                    throw AppError.dateCalculationError("Could not calculate end date for gap detection. Failed to subtract 1 day from \(cachedEarliest)")
                }
                missingRanges.append(DateRange(start: requiredRange.start, end: endDate))
                AppLogger.warning("Gap BEFORE cache: need \(TimeZoneManager.formatForAPI(requiredRange.start)) to \(TimeZoneManager.formatForAPI(endDate))", category: .useCase)
            } else {
                // The gap is less than minimumGapDays, so we ignore it, assuming it's a weekend.
                AppLogger.debug("Phantom gap detected (\(daysBetween) days). Ignoring.", category: .useCase)
            }
        }

        if requiredRange.end > cachedLatest {
            // Use business day logic to determine if this is a real gap
            if await hasActualDataGap(from: cachedLatest, to: requiredRange.end) {
                guard let startDate = calendar.date(byAdding: .day, value: 1, to: cachedLatest) else {
                    throw AppError.dateCalculationError("Could not calculate start date for gap detection. Failed to add 1 day to \(cachedLatest)")
                }
                missingRanges.append(DateRange(start: startDate, end: requiredRange.end))
                AppLogger.warning("Gap AFTER cache: need \(TimeZoneManager.formatForAPI(startDate)) to \(TimeZoneManager.formatForAPI(requiredRange.end))", category: .useCase)
            } else {
                AppLogger.debug("No actual business days missing after cache. Ignoring gap.", category: .useCase)
            }
        }
        return missingRanges
    }

    /// Determines if there's an actual data gap by checking business days
    /// Runs on background thread to avoid blocking UI for large date ranges
    func hasActualDataGap(from startDate: Date, to endDate: Date) async -> Bool {
        // Move expensive calendar operations to background task
        await Task.detached {
            let calendar = TimeZoneManager.cetCalendar
            let now = Date()
            guard var current = calendar.date(byAdding: .day, value: 1, to: startDate) else {
                return false // Handle date calculation failure gracefully
            }

            // Update time constants (same as NetworkService)
            let updateHourCET = 17
            let updateMinuteCET = 0

            while current <= endDate {
                // Skip weekends entirely
                if calendar.isDateInWeekend(current) {
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: current) else {
                        return false // Handle date calculation failure gracefully
                    }
                    current = nextDate
                    continue
                }

                // Check if this is today
                if calendar.isDate(current, inSameDayAs: now) {
                    // For today, only count as business day if past update time
                    var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
                    todayComponents.hour = updateHourCET
                    todayComponents.minute = updateMinuteCET

                    if let todayUpdateTime = calendar.date(from: todayComponents), now >= todayUpdateTime {
                        return true // Found a business day gap
                    }
                } else {
                    // Not today - this is a business day gap
                    return true
                }

                // Move to next day
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: current) else {
                    return false
                }
                current = nextDate
            }

            return false // No business days found in the range
        }.value
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
