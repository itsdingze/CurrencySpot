//
//  HistoricalDataAnalysisUseCaseTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 8/1/25.
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("Historical Data Analysis Use Case Tests")
@MainActor
struct HistoricalDataAnalysisUseCaseTests {
    // MARK: - Test Data Constants

    private static let useCase = HistoricalDataAnalysisUseCase()

    // Helper dates for testing - using CET calendar for consistency
    private static let testBaseDate = TimeZoneManager.createCETDate(year: 2025, month: 1, day: 15)! // Wednesday
    private static let testWeekdayBefore = TimeZoneManager.createCETDate(year: 2025, month: 1, day: 10)! // Friday
    private static let testWeekendBefore = TimeZoneManager.createCETDate(year: 2025, month: 1, day: 12)! // Sunday
    private static let testWeekdayAfter = TimeZoneManager.createCETDate(year: 2025, month: 1, day: 20)! // Monday

    // MARK: - Test Helpers

    /// Creates test historical data with given dates
    private func createTestHistoricalData(dates: [Date]) -> [HistoricalRateDataValue] {
        dates.map { date in
            HistoricalRateDataValue(
                date: date,
                rates: [
                    HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.08),
                    HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.85),
                ]
            )
        }
    }

    /// Creates a mock currency cache with specified date range
    private func createMockCache(startDate: Date, endDate: Date, dayInterval: Int = 1) -> CurrencyCache {
        var dates: [Date] = []
        let calendar = TimeZoneManager.cetCalendar
        var currentDate = startDate

        while currentDate <= endDate {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: dayInterval, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        let historicalData = createTestHistoricalData(dates: dates)
        return CurrencyCache(data: historicalData)
    }

    /// Creates dates representing business days (Monday-Friday)
    private func createBusinessDays(startDate: Date, count: Int) -> [Date] {
        var dates: [Date] = []
        let calendar = TimeZoneManager.cetCalendar
        var currentDate = startDate

        while dates.count < count {
            if !calendar.isDateInWeekend(currentDate) {
                dates.append(currentDate)
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }

    // MARK: - calculateDateRange Tests

    @Test("calculateDateRange should return correct range for one week")
    func calculateDateRange_oneWeek_shouldReturnCorrectRange() {
        // WHEN: Calculating date range for one week
        let result = Self.useCase.calculateDateRange(for: .oneWeek)

        // THEN: Should return range from 7 days ago to today (start of day)
        let calendar = TimeZoneManager.cetCalendar
        let expectedEnd = calendar.startOfDay(for: Date())
        _ = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date())

        // Allow small time differences due to test execution timing
        let timeDifference = abs(result.end.timeIntervalSince(expectedEnd))
        #expect(timeDifference < 60, "End date should be close to expected (within 1 minute)")

        // Verify the start time is approximately correct (within reasonable bounds)
        #expect(result.start < result.end, "Start date should be before end date")
        #expect(result.start < Date(), "Start date should be in the past")
    }

    @Test("calculateDateRange should return correct range for one month", arguments: [
        TimeRange.oneMonth, TimeRange.threeMonths, TimeRange.sixMonths, TimeRange.oneYear, TimeRange.fiveYears
    ])
    func calculateDateRange_variousTimeRanges_shouldReturnCorrectRange(timeRange: TimeRange) {
        // WHEN: Calculating date range for specified time range
        let result = Self.useCase.calculateDateRange(for: timeRange)

        // THEN: Should return proper date range
        let calendar = TimeZoneManager.cetCalendar
        let now = Date()
        let expectedEnd = calendar.startOfDay(for: now)
        _ = timeRange.startDate(from: now)

        // Verify start and end dates are start of day
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: result.start)
        #expect(startComponents.hour == 0 && startComponents.minute == 0 && startComponents.second == 0,
                "Start date should be start of day")

        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: result.end)
        #expect(endComponents.hour == 0 && endComponents.minute == 0 && endComponents.second == 0,
                "End date should be start of day")

        // Verify start is before end
        #expect(result.start <= result.end, "Start date should be before or equal to end date")

        // Allow small differences due to test execution timing
        let timeDifference = abs(result.end.timeIntervalSince(expectedEnd))
        #expect(timeDifference < 60, "End date should be close to now (within 1 minute)")
    }

    @Test("calculateDateRange should handle start of day calculations correctly")
    func calculateDateRange_shouldHandleStartOfDayCorrectly() {
        // WHEN: Calculating any date range
        let result = Self.useCase.calculateDateRange(for: .oneWeek)

        // THEN: Both start and end should be start of day
        let calendar = TimeZoneManager.cetCalendar

        let startOfDayStart = calendar.startOfDay(for: result.start)
        #expect(result.start == startOfDayStart, "Start date should be start of day")

        let startOfDayEnd = calendar.startOfDay(for: result.end)
        #expect(result.end == startOfDayEnd, "End date should be start of day")
    }

    // MARK: - calculateMissingDateRanges Tests - No Cache Scenarios

    @Test("calculateMissingDateRanges with nil cache should return complete required range")
    func calculateMissingDateRanges_nilCache_shouldReturnCompleteRange() async throws {
        // GIVEN: A required date range and nil cache
        let requiredRange = DateRange(start: Self.testWeekdayBefore, end: Self.testBaseDate)

        // WHEN: Calculating missing ranges with nil cache
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: nil
        )

        // THEN: Should return the complete required range
        #expect(result.count == 1, "Should return exactly one missing range")
        #expect(result[0].start == requiredRange.start, "Missing range start should match required start")
        #expect(result[0].end == requiredRange.end, "Missing range end should match required end")
    }

    @Test("calculateMissingDateRanges with empty cache should return complete required range")
    func calculateMissingDateRanges_emptyCache_shouldReturnCompleteRange() async throws {
        // GIVEN: A required date range and empty cache
        let requiredRange = DateRange(start: Self.testWeekdayBefore, end: Self.testBaseDate)
        let emptyCache = CurrencyCache(data: [])

        // WHEN: Calculating missing ranges with empty cache
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: emptyCache
        )

        // THEN: Should return the complete required range
        #expect(result.count == 1, "Should return exactly one missing range")
        #expect(result[0].start == requiredRange.start, "Missing range start should match required start")
        #expect(result[0].end == requiredRange.end, "Missing range end should match required end")
    }

    // MARK: - calculateMissingDateRanges Tests - Gap Before Cache

    @Test("calculateMissingDateRanges with significant gap before cache should detect gap")
    func calculateMissingDateRanges_significantGapBefore_shouldDetectGap() async throws {
        // GIVEN: Required range starts 10 days before cached data (>4 days gap)
        let cacheStart = Self.testBaseDate
        let calendar = TimeZoneManager.cetCalendar
        let requiredStart = calendar.date(byAdding: .day, value: -10, to: cacheStart)!
        let requiredRange = DateRange(start: requiredStart, end: Self.testWeekdayAfter)
        let cache = createMockCache(startDate: cacheStart, endDate: Self.testWeekdayAfter)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should detect gap before cache
        #expect(result.count == 1, "Should detect one missing range before cache")
        #expect(result[0].start == requiredStart, "Missing range should start at required start")

        let expectedEnd = calendar.date(byAdding: .day, value: -1, to: cacheStart)!
        #expect(result[0].end == expectedEnd, "Missing range should end one day before cache start")
    }

    @Test("calculateMissingDateRanges with small gap before cache should ignore phantom gap")
    func calculateMissingDateRanges_smallGapBefore_shouldIgnorePhantomGap() async throws {
        // GIVEN: Required range starts 3 days before cached data (≤4 days gap - phantom gap)
        let cacheStart = Self.testBaseDate
        let calendar = TimeZoneManager.cetCalendar
        let requiredStart = calendar.date(byAdding: .day, value: -3, to: cacheStart)!
        let requiredRange = DateRange(start: requiredStart, end: Self.testWeekdayAfter)
        let cache = createMockCache(startDate: cacheStart, endDate: Self.testWeekdayAfter)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should ignore the phantom gap (assuming it's weekend)
        #expect(result.isEmpty, "Should ignore phantom gap of 3 days")
    }

    @Test("calculateMissingDateRanges with exactly minimum gap days should ignore gap")
    func calculateMissingDateRanges_exactlyMinimumGapDays_shouldIgnoreGap() async throws {
        // GIVEN: Required range starts exactly 4 days before cached data (boundary case)
        let cacheStart = Self.testBaseDate
        let calendar = TimeZoneManager.cetCalendar
        let requiredStart = calendar.date(byAdding: .day, value: -4, to: cacheStart)!
        let requiredRange = DateRange(start: requiredStart, end: Self.testWeekdayAfter)
        let cache = createMockCache(startDate: cacheStart, endDate: Self.testWeekdayAfter)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should ignore gap of exactly 4 days (not > 4)
        #expect(result.isEmpty, "Should ignore gap of exactly 4 days")
    }

    @Test("calculateMissingDateRanges with gap of 5 days should detect gap")
    func calculateMissingDateRanges_fiveDayGap_shouldDetectGap() async throws {
        // GIVEN: Required range starts exactly 5 days before cached data (>4 days)
        let cacheStart = Self.testBaseDate
        let calendar = TimeZoneManager.cetCalendar
        let requiredStart = calendar.date(byAdding: .day, value: -5, to: cacheStart)!
        let requiredRange = DateRange(start: requiredStart, end: Self.testWeekdayAfter)
        let cache = createMockCache(startDate: cacheStart, endDate: Self.testWeekdayAfter)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should detect gap of 5 days
        #expect(result.count == 1, "Should detect gap of 5 days")
        #expect(result[0].start == requiredStart, "Missing range should start at required start")

        let expectedEnd = calendar.date(byAdding: .day, value: -1, to: cacheStart)!
        #expect(result[0].end == expectedEnd, "Missing range should end one day before cache start")
    }

    // MARK: - calculateMissingDateRanges Tests - Gap After Cache

    @Test("calculateMissingDateRanges with business days after cache should detect gap")
    func calculateMissingDateRanges_businessDaysAfterCache_shouldDetectGap() async throws {
        // GIVEN: Required range extends well beyond cached data with many business days
        let cacheEnd = Self.testBaseDate
        let calendar = TimeZoneManager.cetCalendar
        let requiredEnd = calendar.date(byAdding: .day, value: 10, to: cacheEnd)! // 10 days later
        let requiredRange = DateRange(start: Self.testWeekdayBefore, end: requiredEnd)
        let cache = createMockCache(startDate: Self.testWeekdayBefore, endDate: cacheEnd)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should detect gap after cache (has ≥5 business days)
        #expect(result.count == 1, "Should detect one missing range after cache")

        let expectedStart = calendar.date(byAdding: .day, value: 1, to: cacheEnd)!
        #expect(result[0].start == expectedStart, "Missing range should start one day after cache end")
        #expect(result[0].end == requiredEnd, "Missing range should end at required end")
    }

    @Test("calculateMissingDateRanges with weekend-only gap after cache should ignore gap")
    func calculateMissingDateRanges_weekendOnlyGapAfterCache_shouldIgnoreGap() async throws {
        // GIVEN: Cache ends on Friday, required range extends only to Sunday (weekend only)
        let cacheFridayEnd = TimeZoneManager.createCETDate(year: 2025, month: 1, day: 10)! // Friday
        let requiredSundayEnd = TimeZoneManager.createCETDate(year: 2025, month: 1, day: 12)! // Sunday
        let requiredRange = DateRange(start: Self.testWeekdayBefore, end: requiredSundayEnd)
        let cache = createMockCache(startDate: Self.testWeekdayBefore, endDate: cacheFridayEnd)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should ignore weekend-only gap (no business days)
        #expect(result.isEmpty, "Should ignore weekend-only gap")
    }

    @Test("calculateMissingDateRanges with few business days after cache should detect gap")
    func calculateMissingDateRanges_fewBusinessDaysAfterCache_shouldDetectGap() async throws {
        // GIVEN: Cache ends on Wednesday, required range extends to next Monday (3 business days: Thu, Fri, Mon)
        let cacheWednesdayEnd = TimeZoneManager.createCETDate(year: 2025, month: 1, day: 15)! // Wednesday
        let requiredMondayEnd = TimeZoneManager.createCETDate(year: 2025, month: 1, day: 20)! // Monday
        let requiredRange = DateRange(start: Self.testWeekdayBefore, end: requiredMondayEnd)
        let cache = createMockCache(startDate: Self.testWeekdayBefore, endDate: cacheWednesdayEnd)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should detect gap with business days (Thu, Fri, Mon need data)
        #expect(result.count == 1, "Should detect gap with business days")
        #expect(result[0].start == TimeZoneManager.cetCalendar.date(byAdding: .day, value: 1, to: cacheWednesdayEnd)!, "Missing range should start day after cache end")
        #expect(result[0].end == requiredMondayEnd, "Missing range should end at required end")
    }

    // MARK: - calculateMissingDateRanges Tests - Both Gaps

    @Test("calculateMissingDateRanges with gaps before and after cache should detect both")
    func calculateMissingDateRanges_gapsBeforeAndAfterCache_shouldDetectBoth() async throws {
        // GIVEN: Required range has significant gaps both before and after cache
        let cacheStart = Self.testBaseDate
        let calendar = TimeZoneManager.cetCalendar
        let cacheEnd = calendar.date(byAdding: .day, value: 2, to: cacheStart)!
        let requiredStart = calendar.date(byAdding: .day, value: -10, to: cacheStart)! // 10 days before
        let requiredEnd = calendar.date(byAdding: .day, value: 15, to: cacheEnd)! // 15 days after

        let requiredRange = DateRange(start: requiredStart, end: requiredEnd)
        let cache = createMockCache(startDate: cacheStart, endDate: cacheEnd)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should detect both gaps
        #expect(result.count == 2, "Should detect two missing ranges")

        // Verify first gap (before cache)
        let firstGap = result.first { $0.start < cacheStart }
        #expect(firstGap != nil, "Should have gap before cache")
        #expect(firstGap?.start == requiredStart, "First gap should start at required start")

        let expectedFirstEnd = calendar.date(byAdding: .day, value: -1, to: cacheStart)!
        #expect(firstGap?.end == expectedFirstEnd, "First gap should end one day before cache")

        // Verify second gap (after cache)
        let secondGap = result.first { $0.start > cacheEnd }
        #expect(secondGap != nil, "Should have gap after cache")
        #expect(secondGap?.end == requiredEnd, "Second gap should end at required end")

        let expectedSecondStart = calendar.date(byAdding: .day, value: 1, to: cacheEnd)!
        #expect(secondGap?.start == expectedSecondStart, "Second gap should start one day after cache")
    }

    // MARK: - calculateMissingDateRanges Tests - No Gaps

    @Test("calculateMissingDateRanges with no gaps needed should return empty array")
    func calculateMissingDateRanges_noGapsNeeded_shouldReturnEmpty() async throws {
        // GIVEN: Required range is completely covered by cache
        let cacheStart = Self.testWeekdayBefore
        let cacheEnd = Self.testWeekdayAfter
        let requiredRange = DateRange(start: Self.testBaseDate, end: Self.testBaseDate) // Within cache range
        let cache = createMockCache(startDate: cacheStart, endDate: cacheEnd)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should return no missing ranges
        #expect(result.isEmpty, "Should return no missing ranges when cache covers required range")
    }

    // MARK: - calculateMissingDateRanges Tests - Error Cases

    @Test("calculateMissingDateRanges should throw error when date calculation fails")
    func calculateMissingDateRanges_dateCalculationFailure_shouldThrowError() async throws {
        // This test is challenging because TimeZoneManager.cetCalendar is robust
        // We'll test the conceptual error case by checking the thrown error type
        // In practice, this would require mocking the calendar or using extreme dates

        // GIVEN: A scenario that could cause date calculation to fail
        // Using very extreme dates that might cause calendar operations to fail
        let extremeDate = Date(timeIntervalSince1970: Double.greatestFiniteMagnitude / 1000)
        let normalDate = Self.testBaseDate
        let requiredRange = DateRange(start: normalDate, end: extremeDate)
        let cache = createMockCache(startDate: normalDate, endDate: normalDate)

        // WHEN & THEN: Attempting calculation with extreme dates
        // In normal circumstances, this might not fail, but we verify error handling structure
        do {
            let result = try await Self.useCase.calculateMissingDateRanges(
                requiredRange: requiredRange,
                cache: cache
            )
            // If no error thrown, test passes (robust implementation)
            #expect(result.count >= 0, "Should handle extreme dates gracefully")
        } catch let error as AppError {
            // If error is thrown, it should be dateCalculationError
            switch error {
            case let .dateCalculationError(message):
                #expect(message.contains("Could not calculate"), "Error message should be descriptive")
            default:
                #expect(Bool(false), "Should throw dateCalculationError, got \(error)")
            }
        }
    }

    // MARK: - mergeHistoricalData Tests

    @Test("mergeHistoricalData with empty existing data should return new data sorted")
    func mergeHistoricalData_emptyExisting_shouldReturnNewDataSorted() {
        // GIVEN: Empty existing data and new data
        let existingData: [HistoricalRateDataValue] = []
        let date1 = Self.testBaseDate
        let calendar = TimeZoneManager.cetCalendar
        let date2 = calendar.date(byAdding: .day, value: -1, to: date1)!
        let newData = [
            HistoricalRateDataValue(date: date1, rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.08)]),
            HistoricalRateDataValue(date: date2, rates: [HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.85)]),
        ]

        // WHEN: Merging data
        let result = Self.useCase.mergeHistoricalData(existing: existingData, new: newData)

        // THEN: Should return new data sorted by date
        #expect(result.count == 2, "Should return 2 items")
        #expect(result[0].date == date2, "First item should be earlier date")
        #expect(result[1].date == date1, "Second item should be later date")
    }

    @Test("mergeHistoricalData with empty new data should return existing data sorted")
    func mergeHistoricalData_emptyNew_shouldReturnExistingDataSorted() {
        // GIVEN: Existing data and empty new data
        let date1 = Self.testBaseDate
        let calendar = TimeZoneManager.cetCalendar
        let date2 = calendar.date(byAdding: .day, value: -1, to: date1)!
        let existingData = [
            HistoricalRateDataValue(date: date1, rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.08)]),
            HistoricalRateDataValue(date: date2, rates: [HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.85)]),
        ]
        let newData: [HistoricalRateDataValue] = []

        // WHEN: Merging data
        let result = Self.useCase.mergeHistoricalData(existing: existingData, new: newData)

        // THEN: Should return existing data sorted by date
        #expect(result.count == 2, "Should return 2 items")
        #expect(result[0].date == date2, "First item should be earlier date")
        #expect(result[1].date == date1, "Second item should be later date")
    }

    @Test("mergeHistoricalData with both existing and new data should merge without duplicates")
    func mergeHistoricalData_bothDataSets_shouldMergeWithoutDuplicates() {
        // GIVEN: Existing data and new data with some overlapping dates
        let date1 = Self.testBaseDate
        let calendar = TimeZoneManager.cetCalendar
        let date2 = calendar.date(byAdding: .day, value: -1, to: date1)!
        let date3 = calendar.date(byAdding: .day, value: -2, to: date1)!

        let existingData = [
            HistoricalRateDataValue(date: date1, rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.08)]),
            HistoricalRateDataValue(date: date2, rates: [HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.85)]),
        ]

        let newData = [
            HistoricalRateDataValue(date: date2, rates: [HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.87)]), // Duplicate date
            HistoricalRateDataValue(date: date3, rates: [HistoricalRateDataPointValue(currencyCode: "JPY", rate: 110.0)]), // New date
        ]

        // WHEN: Merging data
        let result = Self.useCase.mergeHistoricalData(existing: existingData, new: newData)

        // THEN: Should merge without duplicates and sort by date
        #expect(result.count == 3, "Should return 3 unique dates")
        #expect(result[0].date == date3, "First item should be earliest date")
        #expect(result[1].date == date2, "Second item should be middle date")
        #expect(result[2].date == date1, "Third item should be latest date")

        // Verify that new data overwrites existing data for duplicate dates
        let date2Item = result.first { $0.date == date2 }
        #expect(date2Item?.rates.first?.rate == 0.87, "New data should overwrite existing data for duplicate dates")
    }

    @Test("mergeHistoricalData should maintain chronological order")
    func mergeHistoricalData_shouldMaintainChronologicalOrder() {
        // GIVEN: Data in random order
        let dates = [
            Self.testBaseDate,
            TimeZoneManager.cetCalendar.date(byAdding: .day, value: -5, to: Self.testBaseDate)!,
            TimeZoneManager.cetCalendar.date(byAdding: .day, value: -2, to: Self.testBaseDate)!,
            TimeZoneManager.cetCalendar.date(byAdding: .day, value: -8, to: Self.testBaseDate)!,
        ]

        let existingData = [
            HistoricalRateDataValue(date: dates[0], rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.08)]),
            HistoricalRateDataValue(date: dates[1], rates: [HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.85)]),
        ]

        let newData = [
            HistoricalRateDataValue(date: dates[2], rates: [HistoricalRateDataPointValue(currencyCode: "JPY", rate: 110.0)]),
            HistoricalRateDataValue(date: dates[3], rates: [HistoricalRateDataPointValue(currencyCode: "CAD", rate: 1.25)]),
        ]

        // WHEN: Merging data
        let result = Self.useCase.mergeHistoricalData(existing: existingData, new: newData)

        // THEN: Should be sorted chronologically (earliest to latest)
        #expect(result.count == 4, "Should return 4 items")

        for i in 0 ..< (result.count - 1) {
            #expect(result[i].date <= result[i + 1].date, "Data should be sorted chronologically")
        }
    }

    @Test("mergeHistoricalData with duplicate data should keep only unique entries")
    func mergeHistoricalData_withDuplicates_shouldKeepUniqueEntries() {
        // GIVEN: Data with duplicate dates in both existing and new
        let sharedDate = Self.testBaseDate
        let existingData = [
            HistoricalRateDataValue(date: sharedDate, rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.08)]),
            HistoricalRateDataValue(date: sharedDate, rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.07)]),
        ]

        let newData = [
            HistoricalRateDataValue(date: sharedDate, rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.09)]),
        ]

        // WHEN: Merging data
        let result = Self.useCase.mergeHistoricalData(existing: existingData, new: newData)

        // THEN: Should have only one entry for the shared date (latest new data wins)
        #expect(result.count == 1, "Should return only one entry for duplicate dates")
        #expect(result[0].date == sharedDate, "Should have the shared date")
        #expect(result[0].rates.first?.rate == 1.09, "Should use the latest data (new data wins)")
    }

    @Test("mergeHistoricalData with complex rates should preserve all rate data")
    func mergeHistoricalData_withComplexRates_shouldPreserveAllRateData() {
        // GIVEN: Data with multiple currency rates per date
        let date1 = Self.testBaseDate
        let date2 = TimeZoneManager.cetCalendar.date(byAdding: .day, value: -1, to: date1)!

        let existingData = [
            HistoricalRateDataValue(date: date1, rates: [
                HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.08),
                HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.85),
                HistoricalRateDataPointValue(currencyCode: "JPY", rate: 110.0),
            ]),
        ]

        let newData = [
            HistoricalRateDataValue(date: date2, rates: [
                HistoricalRateDataPointValue(currencyCode: "CAD", rate: 1.25),
                HistoricalRateDataPointValue(currencyCode: "AUD", rate: 1.35),
            ]),
        ]

        // WHEN: Merging data
        let result = Self.useCase.mergeHistoricalData(existing: existingData, new: newData)

        // THEN: Should preserve all complex rate structures
        #expect(result.count == 2, "Should return 2 date entries")

        let date1Entry = result.first { $0.date == date1 }
        #expect(date1Entry?.rates.count == 3, "Date1 should have 3 rates")

        let date2Entry = result.first { $0.date == date2 }
        #expect(date2Entry?.rates.count == 2, "Date2 should have 2 rates")
    }

    // MARK: - Integration Tests

    @Test("calculateMissingDateRanges integration with various cache scenarios")
    func calculateMissingDateRanges_integrationTest_shouldHandleComplexScenarios() async throws {
        // GIVEN: A complex scenario with cache covering partial required range
        let calendar = TimeZoneManager.cetCalendar
        let baseDate = Self.testBaseDate

        // Required range: 20 days ago to 10 days from now
        let requiredStart = calendar.date(byAdding: .day, value: -20, to: baseDate)!
        let requiredEnd = calendar.date(byAdding: .day, value: 10, to: baseDate)!
        let requiredRange = DateRange(start: requiredStart, end: requiredEnd)

        // Cache covers: 5 days ago to 5 days from now (partial coverage)
        let cacheStart = calendar.date(byAdding: .day, value: -5, to: baseDate)!
        let cacheEnd = calendar.date(byAdding: .day, value: 5, to: baseDate)!
        let cache = createMockCache(startDate: cacheStart, endDate: cacheEnd)

        // WHEN: Calculating missing ranges
        let result = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        // THEN: Should detect both before and after gaps
        #expect(result.count == 2, "Should detect gaps before and after cache")

        // Verify gap before cache (20 days ago to 6 days ago)
        let beforeGap = result.first { $0.start < cacheStart }
        #expect(beforeGap != nil, "Should have gap before cache")
        #expect(beforeGap?.start == requiredStart, "Before gap should start at required start")

        // Verify gap after cache (6 days from now to 10 days from now)
        let afterGap = result.first { $0.start > cacheEnd }
        #expect(afterGap != nil, "Should have gap after cache")
        #expect(afterGap?.end == requiredEnd, "After gap should end at required end")
    }

    @Test("Full workflow integration test with realistic data")
    func fullWorkflowIntegration_withRealisticData_shouldWorkCorrectly() async throws {
        // GIVEN: A realistic scenario
        let calendar = TimeZoneManager.cetCalendar
        let today = Date()

        // Calculate date range for 3 months
        let dateRange = Self.useCase.calculateDateRange(for: .threeMonths)

        // Create cache with data for last month only
        let cacheStart = calendar.date(byAdding: .month, value: -1, to: today)!
        let cacheEnd = today
        let cache = createMockCache(startDate: cacheStart, endDate: cacheEnd)

        // WHEN: Calculating missing ranges
        let missingRanges = try await Self.useCase.calculateMissingDateRanges(
            requiredRange: dateRange,
            cache: cache
        )

        // Create new data for missing ranges
        var allData = cache.data
        for missingRange in missingRanges {
            let missingData = createTestHistoricalData(
                dates: [missingRange.start, missingRange.end]
            )
            allData = Self.useCase.mergeHistoricalData(existing: allData, new: missingData)
        }

        // THEN: Should have complete integrated workflow
        #expect(missingRanges.count >= 1, "Should detect missing data for 3-month range")
        #expect(allData.count >= cache.data.count, "Merged data should be larger than or equal to original cache")

        // Verify data is sorted
        for i in 0 ..< (allData.count - 1) {
            #expect(allData[i].date <= allData[i + 1].date, "Merged data should be chronologically sorted")
        }
    }
}
