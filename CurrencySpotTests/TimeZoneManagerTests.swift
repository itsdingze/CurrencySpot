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
        let testDate = TimeZoneManager.createCETDate(year: 2025, month: 3, day: 15)!
        let formatted = TimeZoneManager.formatForAPI(testDate)

        #expect(formatted == "2025-03-15")

        // Test round-trip conversion
        let parsed = TimeZoneManager.parseAPIDate(formatted)
        #expect(parsed != nil)

        let reformatted = TimeZoneManager.formatForAPI(parsed!)
        #expect(reformatted == formatted)
    }

    @Test("Create CET dates correctly")
    func createCETDates() async throws {
        let cetDate = TimeZoneManager.createCETDate(year: 2025, month: 3, day: 15)
        #expect(cetDate != nil)

        // Test invalid dates
        let invalidDate = TimeZoneManager.createCETDate(year: 2025, month: 13, day: 45)
        #expect(invalidDate == nil)
    }

    @Test("Add days in CET context")
    func addDaysInCET() async throws {
        let startDate = TimeZoneManager.createCETDate(year: 2025, month: 3, day: 15)!
        let futureDate = TimeZoneManager.addDays(5, to: startDate)

        #expect(futureDate != nil)

        let daysBetween = TimeZoneManager.daysBetween(startDate, futureDate!)
        #expect(daysBetween == 5)
    }

    @Test("Calculate days between dates")
    func calculateDaysBetween() async throws {
        let startDate = TimeZoneManager.createCETDate(year: 2025, month: 3, day: 1)!
        let endDate = TimeZoneManager.createCETDate(year: 2025, month: 3, day: 15)!

        let days = TimeZoneManager.daysBetween(startDate, endDate)
        #expect(days == 14)

        // Test reverse calculation
        let reverseDays = TimeZoneManager.daysBetween(endDate, startDate)
        #expect(reverseDays == -14)
    }

    @Test("Handle timezone transitions correctly")
    func handleTimezoneTransitions() async throws {
        // Test around DST transition (spring forward)
        let beforeDST = TimeZoneManager.createCETDate(year: 2025, month: 3, day: 29)! // CET
        let afterDST = TimeZoneManager.createCETDate(year: 2025, month: 3, day: 31)! // CEST

        let daysBetween = TimeZoneManager.daysBetween(beforeDST, afterDST)
        #expect(daysBetween == 2)

        // Format should be consistent across DST
        let beforeFormatted = TimeZoneManager.formatForAPI(beforeDST)
        let afterFormatted = TimeZoneManager.formatForAPI(afterDST)

        #expect(beforeFormatted == "2025-03-29")
        #expect(afterFormatted == "2025-03-31")
    }

    @Test("Format display strings consistently")
    func formatDisplayStrings() async throws {
        let testDate = TimeZoneManager.createCETDate(year: 2025, month: 3, day: 15)!

        // Test different format methods don't crash
        let display = TimeZoneManager.formatForDisplay(testDate)
        let chart = TimeZoneManager.formatForChartDisplay(testDate)
        let detail = TimeZoneManager.formatForDetailDisplay(testDate)
        let time = TimeZoneManager.formatTimeDisplay(testDate)
        let lastUpdated = TimeZoneManager.formatLastUpdated(testDate)

        #expect(!display.isEmpty)
        #expect(!chart.isEmpty)
        #expect(!detail.isEmpty)
        #expect(!time.isEmpty)
        #expect(!lastUpdated.isEmpty)
    }
}
