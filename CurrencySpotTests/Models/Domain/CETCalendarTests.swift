@testable import CurrencySpot
import Foundation
import Testing

@Suite("CETCalendar Tests")
struct CETCalendarTests {
    @Test("day strings parse only in the strict yyyy-MM-dd form")
    func parsesStrictDayStrings() {
        #expect(CETCalendar.date(fromDayString: "2025-03-15") != nil)
        #expect(CETCalendar.date(fromDayString: "invalid-date") == nil)
        #expect(CETCalendar.date(fromDayString: "2025-13-45") == nil)
        #expect(CETCalendar.date(fromDayString: "2025-3-15") == nil)
    }

    @Test("day strings round-trip through a parsed date")
    func dayStringsRoundTrip() throws {
        let testDate = try #require(createCETDate(year: 2025, month: 3, day: 15))
        let formatted = CETCalendar.dayString(for: testDate)

        #expect(formatted == "2025-03-15")

        let parsed = try #require(CETCalendar.date(fromDayString: formatted))
        #expect(CETCalendar.dayString(for: parsed) == formatted)
    }

    @Test("days on either side of the DST change keep their calendar day")
    func handlesTimezoneTransitions() throws {
        let beforeDST = try #require(createCETDate(year: 2025, month: 3, day: 29))
        let afterDST = try #require(createCETDate(year: 2025, month: 3, day: 31))

        #expect(CETCalendar.dayString(for: beforeDST) == "2025-03-29")
        #expect(CETCalendar.dayString(for: afterDST) == "2025-03-31")
    }

    @Test("day strings are Gregorian and ASCII regardless of the device calendar")
    func dayStringsAreGregorian() {
        let reference = Date(timeIntervalSince1970: 1_741_993_200)

        #expect(CETCalendar.dayString(for: reference) == "2025-03-15")
        #expect(CETCalendar.date(fromDayString: "2025-03-15") == reference)
        #expect(CETCalendar.calendar.identifier == .gregorian)
    }

    @Test("display formatting renders in the user's locale and local timezone")
    func displayFormatting() throws {
        let components = DateComponents(year: 2025, month: 3, day: 15, hour: 14, minute: 30)
        let date = try #require(Calendar.current.date(from: components))

        #expect(date.chartDisplay == "Mar 15, 2025")
        #expect(date.lastUpdatedDisplay.contains("Mar 15, 2025"))
        #expect(date.lastUpdatedDisplay.contains("2:30"))
    }
}
