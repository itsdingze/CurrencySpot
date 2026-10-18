@testable import CurrencySpot
import Foundation
import Testing

@Suite("Historical Data Analysis Use Case Tests")
struct HistoricalDataAnalysisUseCaseTests {
    // MARK: - Test Data Constants

    private static let testBaseDate = createCETDate(year: 2025, month: 1, day: 15)!
    private static let testNow = testBaseDate.addingTimeInterval(14.5 * 3600)

    private let useCase = HistoricalDataAnalysisUseCase(
        syncCoverage: MockHistoricalSyncStore(),
        dateProvider: FixedDateProvider(testNow)
    )
    private static let testWeekdayBefore = createCETDate(year: 2025, month: 1, day: 10)!
    private static let testWeekendBefore = createCETDate(year: 2025, month: 1, day: 12)!
    private static let testWeekdayAfter = createCETDate(year: 2025, month: 1, day: 20)!

    // MARK: - Test Helpers

    private func createTestHistoricalData(dates: [Date]) -> [HistoricalRateSnapshot] {
        dates.map { date in
            HistoricalRateSnapshot(
                date: date,
                rates: [
                    HistoricalRatePoint(currencyCode: "EUR", rate: 1.08),
                    HistoricalRatePoint(currencyCode: "GBP", rate: 0.85),
                ]
            )
        }
    }

    private func createMockCache(startDate: Date, endDate: Date, dayInterval: Int = 1) -> CurrencyCache {
        var dates: [Date] = []
        let calendar = CETCalendar.calendar
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

    private func createBusinessDays(startDate: Date, count: Int) -> [Date] {
        var dates: [Date] = []
        let calendar = CETCalendar.calendar
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
        let result = useCase.calculateDateRange(for: .oneWeek)

        #expect(result.end == Self.testBaseDate, "End date should be the start of today")
        #expect(result.start < result.end, "Start date should be before end date")
    }

    @Test("calculateDateRange should return correct range for one month", arguments: [
        TimeRange.oneMonth, TimeRange.threeMonths, TimeRange.sixMonths, TimeRange.oneYear, TimeRange.fiveYears
    ])
    func calculateDateRange_variousTimeRanges_shouldReturnCorrectRange(timeRange: TimeRange) {
        let result = useCase.calculateDateRange(for: timeRange)

        let calendar = CETCalendar.calendar

        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: result.start)
        #expect(startComponents.hour == 0 && startComponents.minute == 0 && startComponents.second == 0,
                "Start date should be start of day")

        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: result.end)
        #expect(endComponents.hour == 0 && endComponents.minute == 0 && endComponents.second == 0,
                "End date should be start of day")

        #expect(result.start <= result.end, "Start date should be before or equal to end date")
        #expect(result.end == Self.testBaseDate, "End date should be the start of today")
    }

    @Test("calculateDateRange should handle start of day calculations correctly")
    func calculateDateRange_shouldHandleStartOfDayCorrectly() {
        let result = useCase.calculateDateRange(for: .oneWeek)

        let calendar = CETCalendar.calendar

        let startOfDayStart = calendar.startOfDay(for: result.start)
        #expect(result.start == startOfDayStart, "Start date should be start of day")

        let startOfDayEnd = calendar.startOfDay(for: result.end)
        #expect(result.end == startOfDayEnd, "End date should be start of day")
    }

    // MARK: - calculateMissingDateRanges Tests - No Cache Scenarios

    @Test("calculateMissingDateRanges with nil cache should return complete required range")
    func calculateMissingDateRanges_nilCache_shouldReturnCompleteRange() async throws {
        let requiredRange = DateRange.spanning(Self.testWeekdayBefore, Self.testBaseDate)

        let result = try await useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: nil
        )

        #expect(result.count == 1, "Should return exactly one missing range")
        #expect(result[0].start == requiredRange.start, "Missing range start should match required start")
        #expect(result[0].end == requiredRange.end, "Missing range end should match required end")
    }

    @Test("calculateMissingDateRanges with empty cache should return complete required range")
    func calculateMissingDateRanges_emptyCache_shouldReturnCompleteRange() async throws {
        let requiredRange = DateRange.spanning(Self.testWeekdayBefore, Self.testBaseDate)
        let emptyCache = CurrencyCache(data: [])

        let result = try await useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: emptyCache
        )

        #expect(result.count == 1, "Should return exactly one missing range")
        #expect(result[0].start == requiredRange.start, "Missing range start should match required start")
        #expect(result[0].end == requiredRange.end, "Missing range end should match required end")
    }

    // MARK: - calculateMissingDateRanges Tests - Gap Before Cache

    @Test("calculateMissingDateRanges with significant gap before cache should detect gap")
    func calculateMissingDateRanges_significantGapBefore_shouldDetectGap() async throws {
        let cacheStart = Self.testBaseDate
        let calendar = CETCalendar.calendar
        let requiredStart = try #require(calendar.date(byAdding: .day, value: -10, to: cacheStart))
        let requiredRange = DateRange.spanning(requiredStart, Self.testWeekdayAfter)
        let cache = createMockCache(startDate: cacheStart, endDate: Self.testWeekdayAfter)

        let result = try await useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        #expect(result.count == 1, "Should detect one missing range before cache")
        #expect(result[0].start == requiredStart, "Missing range should start at required start")

        let expectedEnd = try #require(calendar.date(byAdding: .day, value: -1, to: cacheStart))
        #expect(result[0].end == expectedEnd, "Missing range should end one day before cache start")
    }

    @Test("calculateMissingDateRanges with gap of 5 days should detect gap")
    func calculateMissingDateRanges_fiveDayGap_shouldDetectGap() async throws {
        let cacheStart = Self.testBaseDate
        let calendar = CETCalendar.calendar
        let requiredStart = try #require(calendar.date(byAdding: .day, value: -5, to: cacheStart))
        let requiredRange = DateRange.spanning(requiredStart, Self.testWeekdayAfter)
        let cache = createMockCache(startDate: cacheStart, endDate: Self.testWeekdayAfter)

        let result = try await useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        #expect(result.count == 1, "Should detect gap of 5 days")
        #expect(result[0].start == requiredStart, "Missing range should start at required start")

        let expectedEnd = try #require(calendar.date(byAdding: .day, value: -1, to: cacheStart))
        #expect(result[0].end == expectedEnd, "Missing range should end one day before cache start")
    }

    // MARK: - calculateMissingDateRanges Tests - Gap After Cache

    @Test("calculateMissingDateRanges with business days after cache should detect gap")
    func calculateMissingDateRanges_businessDaysAfterCache_shouldDetectGap() async throws {
        let cacheEnd = Self.testBaseDate
        let calendar = CETCalendar.calendar
        let requiredEnd = try #require(calendar.date(byAdding: .day, value: 10, to: cacheEnd))
        let requiredRange = DateRange.spanning(Self.testWeekdayBefore, requiredEnd)
        let cache = createMockCache(startDate: Self.testWeekdayBefore, endDate: cacheEnd)

        let result = try await useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        #expect(result.count == 1, "Should detect one missing range after cache")

        let expectedStart = try #require(calendar.date(byAdding: .day, value: 1, to: cacheEnd))
        #expect(result[0].start == expectedStart, "Missing range should start one day after cache end")
        #expect(result[0].end == requiredEnd, "Missing range should end at required end")
    }

    @Test("calculateMissingDateRanges with few business days after cache should detect gap")
    func calculateMissingDateRanges_fewBusinessDaysAfterCache_shouldDetectGap() async throws {
        let cacheWednesdayEnd = Self.testBaseDate
        let requiredMondayEnd = Self.testWeekdayAfter
        let requiredRange = DateRange.spanning(Self.testWeekdayBefore, requiredMondayEnd)
        let cache = createMockCache(startDate: Self.testWeekdayBefore, endDate: cacheWednesdayEnd)

        let result = try await useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        let expectedGapStart = try #require(CETCalendar.calendar.date(byAdding: .day, value: 1, to: cacheWednesdayEnd))
        #expect(result.count == 1, "Should detect gap with business days")
        #expect(result[0].start == expectedGapStart, "Missing range should start day after cache end")
        #expect(result[0].end == requiredMondayEnd, "Missing range should end at required end")
    }

    // MARK: - calculateMissingDateRanges Tests - Both Gaps

    @Test("calculateMissingDateRanges with gaps before and after cache should detect both")
    func calculateMissingDateRanges_gapsBeforeAndAfterCache_shouldDetectBoth() async throws {
        let cacheStart = Self.testBaseDate
        let calendar = CETCalendar.calendar
        let cacheEnd = try #require(calendar.date(byAdding: .day, value: 2, to: cacheStart))
        let requiredStart = try #require(calendar.date(byAdding: .day, value: -10, to: cacheStart))
        let requiredEnd = try #require(calendar.date(byAdding: .day, value: 15, to: cacheEnd))

        let requiredRange = DateRange.spanning(requiredStart, requiredEnd)
        let cache = createMockCache(startDate: cacheStart, endDate: cacheEnd)

        let result = try await useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        #expect(result.count == 2, "Should detect two missing ranges")

        let firstGap = result.first { $0.start < cacheStart }
        #expect(firstGap != nil, "Should have gap before cache")
        #expect(firstGap?.start == requiredStart, "First gap should start at required start")

        let expectedFirstEnd = try #require(calendar.date(byAdding: .day, value: -1, to: cacheStart))
        #expect(firstGap?.end == expectedFirstEnd, "First gap should end one day before cache")

        let secondGap = result.first { $0.start > cacheEnd }
        #expect(secondGap != nil, "Should have gap after cache")
        #expect(secondGap?.end == requiredEnd, "Second gap should end at required end")

        let expectedSecondStart = try #require(calendar.date(byAdding: .day, value: 1, to: cacheEnd))
        #expect(secondGap?.start == expectedSecondStart, "Second gap should start one day after cache")
    }

    // MARK: - calculateMissingDateRanges Tests - No Gaps

    @Test("calculateMissingDateRanges with no gaps needed should return empty array")
    func calculateMissingDateRanges_noGapsNeeded_shouldReturnEmpty() async throws {
        let cacheStart = Self.testWeekdayBefore
        let cacheEnd = Self.testWeekdayAfter
        let requiredRange = DateRange.spanning(Self.testBaseDate, Self.testBaseDate)
        let cache = createMockCache(startDate: cacheStart, endDate: cacheEnd)

        let result = try await useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        #expect(result.isEmpty, "Should return no missing ranges when cache covers required range")
    }

    // MARK: - Integration Tests

    @Test("calculateMissingDateRanges integration with various cache scenarios")
    func calculateMissingDateRanges_integrationTest_shouldHandleComplexScenarios() async throws {
        let calendar = CETCalendar.calendar
        let baseDate = Self.testBaseDate

        let requiredStart = try #require(calendar.date(byAdding: .day, value: -20, to: baseDate))
        let requiredEnd = try #require(calendar.date(byAdding: .day, value: 10, to: baseDate))
        let requiredRange = DateRange.spanning(requiredStart, requiredEnd)

        let cacheStart = try #require(calendar.date(byAdding: .day, value: -5, to: baseDate))
        let cacheEnd = try #require(calendar.date(byAdding: .day, value: 5, to: baseDate))
        let cache = createMockCache(startDate: cacheStart, endDate: cacheEnd)

        let result = try await useCase.calculateMissingDateRanges(
            requiredRange: requiredRange,
            cache: cache
        )

        #expect(result.count == 2, "Should detect gaps before and after cache")

        let beforeGap = result.first { $0.start < cacheStart }
        #expect(beforeGap != nil, "Should have gap before cache")
        #expect(beforeGap?.start == requiredStart, "Before gap should start at required start")

        let afterGap = result.first { $0.start > cacheEnd }
        #expect(afterGap != nil, "Should have gap after cache")
        #expect(afterGap?.end == requiredEnd, "After gap should end at required end")
    }

    @Test("Full workflow integration test with realistic data")
    func fullWorkflowIntegration_withRealisticData_shouldWorkCorrectly() async throws {
        let calendar = CETCalendar.calendar
        let today = Self.testBaseDate

        let dateRange = useCase.calculateDateRange(for: .threeMonths)

        let cacheStart = try #require(calendar.date(byAdding: .month, value: -1, to: today))
        let cacheEnd = today
        let cache = createMockCache(startDate: cacheStart, endDate: cacheEnd)

        let missingRanges = try await useCase.calculateMissingDateRanges(
            requiredRange: dateRange,
            cache: cache
        )

        var allData = cache.data
        for missingRange in missingRanges {
            let missingData = createTestHistoricalData(
                dates: [missingRange.start, missingRange.end]
            )
            allData = HistoricalRateSnapshot.merge(existing: allData, new: missingData)
        }

        #expect(missingRanges.count >= 1, "Should detect missing data for 3-month range")
        #expect(allData.count >= cache.data.count, "Merged data should be larger than or equal to original cache")

        for i in 0 ..< (allData.count - 1) {
            #expect(allData[i].date <= allData[i + 1].date, "Merged data should be chronologically sorted")
        }
    }
}
