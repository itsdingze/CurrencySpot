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
}
