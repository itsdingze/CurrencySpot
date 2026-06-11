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
        let testDate = createCETDate(year: 2025, month: 3, day: 15)!
        let formatted = TimeZoneManager.formatForAPI(testDate)

        #expect(formatted == "2025-03-15")

        // Test round-trip conversion
        let parsed = TimeZoneManager.parseAPIDate(formatted)
        #expect(parsed != nil)

        let reformatted = TimeZoneManager.formatForAPI(parsed!)
        #expect(reformatted == formatted)
    }

    @Test("Handle timezone transitions correctly")
    func handleTimezoneTransitions() async throws {
        // Test around DST transition (spring forward)
        let beforeDST = createCETDate(year: 2025, month: 3, day: 29)! // CET
        let afterDST = createCETDate(year: 2025, month: 3, day: 31)! // CEST

        // Format should be consistent across DST
        let beforeFormatted = TimeZoneManager.formatForAPI(beforeDST)
        let afterFormatted = TimeZoneManager.formatForAPI(afterDST)

        #expect(beforeFormatted == "2025-03-29")
        #expect(afterFormatted == "2025-03-31")
    }
}
