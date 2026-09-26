@testable import CurrencySpot
import Foundation
import Testing

@Suite("HistoricalRateData Validation Tests")
struct HistoricalRateDataTests {
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

    @Test("rates round-trip through the blob into validated domain points")
    func blobRoundTripsToDomain() throws {
        let date = try #require(TimeZoneManager.parseAPIDate("2025-03-15"))
        let model = try HistoricalRateData(date: date, rates: ["EUR": 1.21, "GBP": 0.85])

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
