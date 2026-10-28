@testable import CurrencySpot
import Foundation
import Testing

struct ChartDateFormattingTests {
    @Test func rateDayShowsItsOwnDayWhereverTheDeviceIs() throws {
        let rateDay = try #require(CETCalendar.date(fromDayString: "2026-10-16"))

        #expect(rateDay.rateDayDisplay.contains("16"))
    }

    @Test func axisLabelShowsTheRateDay() throws {
        let rateDay = try #require(CETCalendar.date(fromDayString: "2026-10-16"))

        #expect(rateDay.formatted(TimeRange.oneWeek.chartAxisDateFormat).contains("16"))
    }

    @Test func savedRatesTimeLeavesOutTheCurrentYear() throws {
        let savedAt = try #require(CETCalendar.date(fromDayString: "2026-10-16"))
        let now = try #require(CETCalendar.date(fromDayString: "2026-10-28"))

        #expect(!savedAt.savedRatesDisplay(relativeTo: now).contains("2026"))
    }

    @Test func savedRatesTimeShowsAnEarlierYear() throws {
        let savedAt = try #require(CETCalendar.date(fromDayString: "2025-10-16"))
        let now = try #require(CETCalendar.date(fromDayString: "2026-10-28"))

        #expect(savedAt.savedRatesDisplay(relativeTo: now).contains("2025"))
    }
}
