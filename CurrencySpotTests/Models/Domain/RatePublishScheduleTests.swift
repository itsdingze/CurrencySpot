@testable import CurrencySpot
import Foundation
import Testing

@Suite("RatePublishSchedule")
struct RatePublishScheduleTests {
    private func cet(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) throws -> Date {
        let components = DateComponents(timeZone: CETCalendar.timeZone, year: 2026, month: month, day: day, hour: hour, minute: minute)
        return try #require(CETCalendar.calendar.date(from: components))
    }

    @Test("fresh rates on a weekday morning refresh at that afternoon's publish")
    func weekdayMorningWaitsForAfternoon() throws {
        let next = RatePublishSchedule.nextRefresh(after: try cet(27, 10), latestRateDay: try cet(26, 0))

        #expect(next == (try cet(27, 16, 15)))
    }

    @Test("fresh rates on a Friday evening refresh at Monday's publish")
    func fridayEveningWaitsForMonday() throws {
        let next = RatePublishSchedule.nextRefresh(after: try cet(30, 17), latestRateDay: try cet(30, 0))

        #expect(next == (try cet(2, 16, 15, month: 11)))
    }

    @Test("fresh rates on a Saturday refresh at Monday's publish")
    func weekendWaitsForMonday() throws {
        let next = RatePublishSchedule.nextRefresh(after: try cet(31, 10), latestRateDay: try cet(30, 0))

        #expect(next == (try cet(2, 16, 15, month: 11)))
    }

    @Test("rates still missing today's publish retry within the hour")
    func lateRatesRetrySoon() throws {
        let now = try cet(27, 17)

        let next = RatePublishSchedule.nextRefresh(after: now, latestRateDay: try cet(26, 0))

        #expect(next > now)
        #expect(next <= now.addingTimeInterval(60 * 60))
    }

    @Test("no rates at all retry within the hour")
    func missingRatesRetrySoon() throws {
        let now = try cet(27, 10)

        let next = RatePublishSchedule.nextRefresh(after: now, latestRateDay: nil)

        #expect(next > now)
        #expect(next <= now.addingTimeInterval(60 * 60))
    }
}
