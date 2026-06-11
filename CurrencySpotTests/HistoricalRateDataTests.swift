//
//  HistoricalRateDataTests.swift
//  CurrencySpotTests
//
//  Validation tests for the HistoricalRateData model and its value-type counterpart.
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("HistoricalRateData Validation Tests")
struct HistoricalRateDataTests {
    /// Asserts the value's date is exactly midnight 2025-03-15 in the CET (Europe/Paris) calendar,
    /// decomposed from the value itself rather than re-running the parser the init uses.
    private func assertIsMarch15CET(_ date: Date) {
        let components = TimeZoneManager.cetCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        #expect(components.year == 2025)
        #expect(components.month == 3)
        #expect(components.day == 15)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }

    @Test("HistoricalRateDataValue rejects invalid dates and parses valid ones")
    func historicalRateDataValueHandlesInvalidDates() throws {
        let rates = [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21)]

        let error = try #require(throws: AppError.self) {
            try HistoricalRateDataValue(dateString: "invalid-date", rates: rates)
        }
        guard case .dataValidationError = error else {
            Issue.record("Expected .dataValidationError, got \(error)")
            return
        }

        let validValue = try HistoricalRateDataValue(dateString: "2025-03-15", rates: rates)
        assertIsMarch15CET(validValue.date)
    }

    @Test("SwiftData model rejects invalid dates and parses valid ones")
    func swiftDataModelHandlesInvalidDates() throws {
        let rates = [HistoricalRateDataPoint(currencyCode: "EUR", rate: 1.21)]

        let error = try #require(throws: AppError.self) {
            try HistoricalRateData(dateString: "invalid-date", rates: rates)
        }
        guard case .dataValidationError = error else {
            Issue.record("Expected .dataValidationError, got \(error)")
            return
        }

        let validData = try HistoricalRateData(dateString: "2025-03-15", rates: rates)
        assertIsMarch15CET(validData.date)
    }
}
