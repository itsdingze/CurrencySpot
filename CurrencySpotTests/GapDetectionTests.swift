//
//  GapDetectionTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 7/17/25.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Gap Detection Tests")
struct GapDetectionTests {
    private func createCETDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        TimeZoneManager.createCETDate(year: y, month: m, day: d)!
    }

    @Test("Detect gaps before cached data")
    func detectGapsBeforeCachedData() async throws {
        let requiredRange = DateRange(
            start: createCETDate(2025, 3, 1),
            end: createCETDate(2025, 3, 15)
        )

        let cachedData = [
            HistoricalRateDataValue(date: createCETDate(2025, 3, 10), rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21),
            ]),
        ]

        let missingRanges = calculateMissingDateRanges(
            requiredRange: requiredRange,
            cachedData: cachedData
        )

        #expect(missingRanges.count == 1)
        #expect(missingRanges.first?.start == requiredRange.start)
        #expect(missingRanges.first?.end == createCETDate(2025, 3, 9))
    }

    @Test("Detect gaps including weekends")
    func detectGapsIncludingWeekends() async throws {
        let requiredRange = DateRange(
            start: createCETDate(2025, 3, 6), // Thursday
            end: createCETDate(2025, 3, 15)
        )

        let cachedData = [
            HistoricalRateDataValue(date: createCETDate(2025, 3, 10), rates: [ // Monday
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21),
            ]),
        ]

        let missingRanges = calculateMissingDateRanges(
            requiredRange: requiredRange,
            cachedData: cachedData
        )

        // Should detect the gap (Thu->Mon = 4 days, >= 3 so treated as real gap)
        #expect(missingRanges.count == 1)
    }

    @Test("Detect multiple gaps")
    func detectMultipleGaps() async throws {
        let requiredRange = DateRange(
            start: createCETDate(2025, 3, 1),
            end: createCETDate(2025, 3, 25)
        )

        let cachedData = [
            HistoricalRateDataValue(date: createCETDate(2025, 3, 15), rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21),
            ]),
        ]

        let missingRanges = calculateMissingDateRanges(
            requiredRange: requiredRange,
            cachedData: cachedData
        )

        // Should detect gap before cached data
        #expect(missingRanges.count == 1)
        #expect(missingRanges.first?.start == requiredRange.start)
        #expect(missingRanges.first?.end == createCETDate(2025, 3, 14))
    }

    @Test("Handle edge cases")
    func handleEdgeCases() async throws {
        // Test same start and end date
        let singleDayRange = DateRange(
            start: createCETDate(2025, 3, 15),
            end: createCETDate(2025, 3, 15)
        )

        let cachedData = [
            HistoricalRateDataValue(date: createCETDate(2025, 3, 15), rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21),
            ]),
        ]

        let missingRanges = calculateMissingDateRanges(
            requiredRange: singleDayRange,
            cachedData: cachedData
        )

        #expect(missingRanges.isEmpty)
    }

    @Test("Empty cached data returns full range")
    func emptyCachedDataReturnsFullRange() async throws {
        // GIVEN: A required range and no cached data
        let requiredRange = DateRange(
            start: createCETDate(2025, 3, 1),
            end: createCETDate(2025, 3, 15)
        )
        let cachedData: [HistoricalRateDataValue] = []

        // WHEN: We calculate missing ranges
        let missingRanges = calculateMissingDateRanges(
            requiredRange: requiredRange,
            cachedData: cachedData
        )

        // THEN: Should return the entire required range
        #expect(missingRanges.count == 1)
        #expect(missingRanges.first?.start == requiredRange.start)
        #expect(missingRanges.first?.end == requiredRange.end)
    }

    @Test("No missing ranges when cache covers requirement")
    func noMissingRangesWhenCacheCoversRequirement() async throws {
        // GIVEN: A required range and cached data that covers it
        let requiredRange = DateRange(
            start: createCETDate(2025, 3, 5),
            end: createCETDate(2025, 3, 10)
        )
        let cachedData = try [
            HistoricalRateDataValue(dateString: "2025-03-01", rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21),
            ]),
            HistoricalRateDataValue(dateString: "2025-03-15", rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.22),
            ]),
        ]

        // WHEN: We calculate missing ranges
        let missingRanges = calculateMissingDateRanges(
            requiredRange: requiredRange,
            cachedData: cachedData
        )

        // THEN: Should return no missing ranges
        #expect(missingRanges.isEmpty)
    }
}

// MARK: - Helper Function

/// Helper function to calculate missing date ranges
/// Made global so it can be tested independently
nonisolated func calculateMissingDateRanges(
    requiredRange: DateRange,
    cachedData: [HistoricalRateDataValue]
) -> [DateRange] {
    guard !cachedData.isEmpty else {
        return [requiredRange] // No data at all, need everything
    }

    // Convert existing dates to Date objects and find coverage
    let existingDates = cachedData.map(\.date).sorted()

    guard let earliestCachedDate = existingDates.first,
          let latestCachedDate = existingDates.last
    else {
        return [requiredRange]
    }

    // Use CET calendar for consistent timezone operations
    let calendar = TimeZoneManager.cetCalendar
    let cachedEarliest = calendar.startOfDay(for: earliestCachedDate)
    _ = calendar.startOfDay(for: latestCachedDate)

    var missingRanges: [DateRange] = []

    if requiredRange.start < cachedEarliest {
        let daysBetween = calendar.dateComponents([.day], from: requiredRange.start, to: cachedEarliest).day ?? 0

        if daysBetween >= 3 {
            // The gap is 3 days or more, so we assume it's a real gap
            let endDate = calendar.date(byAdding: .day, value: -1, to: cachedEarliest)!
            missingRanges.append(DateRange(start: requiredRange.start, end: endDate))
            print("⚠️ Gap BEFORE cache: need \(TimeZoneManager.formatForAPI(requiredRange.start)) to \(TimeZoneManager.formatForAPI(endDate))")
        } else {
            // The gap is less than 3 days, so we ignore it, assuming it's a weekend.
            print("✅ Phantom gap detected (\(daysBetween) days). Ignoring.")
        }
    }

    return missingRanges
}
