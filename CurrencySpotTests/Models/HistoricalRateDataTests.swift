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

    @Test("HistoricalRateSnapshot rejects invalid dates and parses valid ones")
    func historicalRateSnapshotHandlesInvalidDates() throws {
        let rates = [HistoricalRatePoint(currencyCode: "EUR", rate: 1.21)]

        let error = try #require(throws: AppError.self) {
            try HistoricalRateSnapshot(dateString: "invalid-date", rates: rates)
        }
        guard case .dataValidationError = error else {
            Issue.record("Expected .dataValidationError, got \(error)")
            return
        }

        let validValue = try HistoricalRateSnapshot(dateString: "2025-03-15", rates: rates)
        assertIsMarch15CET(validValue.date)
    }

    @Test("SwiftData model rejects invalid dates and parses valid ones")
    func swiftDataModelHandlesInvalidDates() throws {
        let error = try #require(throws: AppError.self) {
            try HistoricalRateData(dateString: "invalid-date", rates: ["EUR": 1.21])
        }
        guard case .dataValidationError = error else {
            Issue.record("Expected .dataValidationError, got \(error)")
            return
        }

        let validData = try HistoricalRateData(dateString: "2025-03-15", rates: ["EUR": 1.21])
        assertIsMarch15CET(validData.date)
    }

    @Test("rates round-trip through the blob into validated domain points")
    func blobRoundTripsToDomain() throws {
        let model = try HistoricalRateData(dateString: "2025-03-15", rates: ["EUR": 1.21, "GBP": 0.85])

        let snapshot = try model.toDomain()

        assertIsMarch15CET(snapshot.date)
        #expect(snapshot.rates.count == 2)
        #expect(snapshot.rates.first { $0.currencyCode == "EUR" }?.rate == 1.21)
        #expect(snapshot.rates.first { $0.currencyCode == "GBP" }?.rate == 0.85)
    }

    @Test("a corrupt blob fails loudly instead of yielding an empty day")
    func corruptBlobThrows() throws {
        let model = HistoricalRateData(
            date: TimeZoneManager.parseAPIDate("2025-03-15")!,
            ratesData: Data("not json".utf8)
        )

        #expect(throws: (any Error).self) {
            _ = try model.toDomain()
        }
    }
}
