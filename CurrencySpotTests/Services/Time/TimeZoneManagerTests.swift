@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("TimeZoneManager Tests")
struct TimeZoneManagerTests {
    @Test("Parse API date strings correctly")
    func parseAPIDateStrings() async throws {
        let validDate = TimeZoneManager.parseAPIDate("2025-03-15")
        #expect(validDate != nil)

        let invalidDate1 = TimeZoneManager.parseAPIDate("invalid-date")
        let invalidDate2 = TimeZoneManager.parseAPIDate("2025-13-45")
        let invalidDate3 = TimeZoneManager.parseAPIDate("2025-3-15")

        #expect(invalidDate1 == nil)
        #expect(invalidDate2 == nil)
        #expect(invalidDate3 == nil)
    }

    @Test("Format dates for API consistently")
    func formatDatesForAPI() async throws {
        let testDate = try #require(createCETDate(year: 2025, month: 3, day: 15))
        let formatted = TimeZoneManager.formatForAPI(testDate)

        #expect(formatted == "2025-03-15")

        let parsed = try #require(TimeZoneManager.parseAPIDate(formatted))
        let reformatted = TimeZoneManager.formatForAPI(parsed)
        #expect(reformatted == formatted)
    }

    @Test("Handle timezone transitions correctly")
    func handleTimezoneTransitions() async throws {
        let beforeDST = try #require(createCETDate(year: 2025, month: 3, day: 29))
        let afterDST = try #require(createCETDate(year: 2025, month: 3, day: 31))

        let beforeFormatted = TimeZoneManager.formatForAPI(beforeDST)
        let afterFormatted = TimeZoneManager.formatForAPI(afterDST)

        #expect(beforeFormatted == "2025-03-29")
        #expect(afterFormatted == "2025-03-31")
    }

    @Test("API date handling is Gregorian and ASCII regardless of the device calendar")
    func apiDatesAreGregorian() {
        let reference = Date(timeIntervalSince1970: 1_741_993_200)

        #expect(TimeZoneManager.formatForAPI(reference) == "2025-03-15")
        #expect(TimeZoneManager.parseAPIDate("2025-03-15") == reference)
        #expect(TimeZoneManager.cetCalendar.identifier == .gregorian)
    }

    @Test("Display formatters render in the user's locale and local timezone")
    func displayFormatters() throws {
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 15
        components.hour = 14
        components.minute = 30
        let date = try #require(Calendar.current.date(from: components))

        #expect(TimeZoneManager.formatForChartDisplay(date) == "Mar 15, 2025")

        let lastUpdated = TimeZoneManager.formatLastUpdated(date)
        #expect(lastUpdated.contains("Mar 15, 2025"))
        #expect(lastUpdated.contains("2:30"))
    }
}
