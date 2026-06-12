//
//  TimeZoneManagerTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 7/17/25.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("TimeZoneManager Tests")
struct TimeZoneManagerTests {
    @Test("Parse API date strings correctly")
    func parseAPIDateStrings() async throws {
        // Test valid date strings
        let validDate = TimeZoneManager.parseAPIDate("2025-03-15")
        #expect(validDate != nil)

        // Test invalid date strings
        let invalidDate1 = TimeZoneManager.parseAPIDate("invalid-date")
        let invalidDate2 = TimeZoneManager.parseAPIDate("2025-13-45")
        let invalidDate3 = TimeZoneManager.parseAPIDate("2025-3-15") // No zero padding

        #expect(invalidDate1 == nil)
        #expect(invalidDate2 == nil)
        #expect(invalidDate3 == nil)
    }

    @Test("Format dates for API consistently")
    func formatDatesForAPI() async throws {
        // Create a known date in CET
        let testDate = try #require(createCETDate(year: 2025, month: 3, day: 15))
        let formatted = TimeZoneManager.formatForAPI(testDate)

        #expect(formatted == "2025-03-15")

        // Test round-trip conversion
        let parsed = try #require(TimeZoneManager.parseAPIDate(formatted))
        let reformatted = TimeZoneManager.formatForAPI(parsed)
        #expect(reformatted == formatted)
    }

    @Test("Handle timezone transitions correctly")
    func handleTimezoneTransitions() async throws {
        // Test around DST transition (spring forward)
        let beforeDST = try #require(createCETDate(year: 2025, month: 3, day: 29)) // CET
        let afterDST = try #require(createCETDate(year: 2025, month: 3, day: 31)) // CEST

        // Format should be consistent across DST
        let beforeFormatted = TimeZoneManager.formatForAPI(beforeDST)
        let afterFormatted = TimeZoneManager.formatForAPI(afterDST)

        #expect(beforeFormatted == "2025-03-29")
        #expect(afterFormatted == "2025-03-31")
    }

    @Test("Display formatters render in the user's locale and local timezone")
    func displayFormatters() throws {
        // Built with the local calendar so the rendered day is host-timezone
        // independent; the test plan pins the locale to en_US.
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
