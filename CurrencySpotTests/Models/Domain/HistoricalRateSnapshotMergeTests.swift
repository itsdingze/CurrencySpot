@testable import CurrencySpot
import Foundation
import Testing

@Suite("HistoricalRateSnapshot.merge")
struct HistoricalRateSnapshotMergeTests {
    private let today: Date
    private let yesterday: Date
    private let twoDaysAgo: Date
    private let fiveDaysAgo: Date
    private let eightDaysAgo: Date

    init() throws {
        let calendar = CETCalendar.calendar
        today = try #require(createCETDate(year: 2025, month: 1, day: 15))
        yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: today))
        fiveDaysAgo = try #require(calendar.date(byAdding: .day, value: -5, to: today))
        eightDaysAgo = try #require(calendar.date(byAdding: .day, value: -8, to: today))
    }

    private static func snapshot(_ date: Date, _ rates: [(CurrencyCode, Double)]) -> HistoricalRateSnapshot {
        HistoricalRateSnapshot(date: date, rates: rates.map { HistoricalRatePoint(currencyCode: $0.0, rate: $0.1) })
    }

    @Test("merging into an empty series returns the new days sorted")
    func emptyExistingReturnsNewSorted() {
        let newData = [
            Self.snapshot(today, [("EUR", 1.08)]),
            Self.snapshot(yesterday, [("GBP", 0.85)]),
        ]

        let result = HistoricalRateSnapshot.merge(existing: [], new: newData)

        #expect(result.map(\.date) == [yesterday, today])
    }

    @Test("merging nothing returns the existing days sorted")
    func emptyNewReturnsExistingSorted() {
        let existing = [
            Self.snapshot(today, [("EUR", 1.08)]),
            Self.snapshot(yesterday, [("GBP", 0.85)]),
        ]

        let result = HistoricalRateSnapshot.merge(existing: existing, new: [])

        #expect(result.map(\.date) == [yesterday, today])
    }

    @Test("a day present in both keeps the new rates")
    func newRatesWinForSharedDays() {
        let existing = [
            Self.snapshot(today, [("EUR", 1.08)]),
            Self.snapshot(yesterday, [("GBP", 0.85)]),
        ]
        let newData = [
            Self.snapshot(yesterday, [("GBP", 0.87)]),
            Self.snapshot(twoDaysAgo, [("JPY", 110.0)]),
        ]

        let result = HistoricalRateSnapshot.merge(existing: existing, new: newData)

        #expect(result.map(\.date) == [twoDaysAgo, yesterday, today])
        #expect(result.first { $0.date == yesterday }?.rates.first?.rate == 0.87)
    }

    @Test("interleaved days come back in chronological order")
    func interleavedDaysAreSorted() {
        let existing = [
            Self.snapshot(today, [("EUR", 1.08)]),
            Self.snapshot(fiveDaysAgo, [("GBP", 0.85)]),
        ]
        let newData = [
            Self.snapshot(twoDaysAgo, [("JPY", 110.0)]),
            Self.snapshot(eightDaysAgo, [("CAD", 1.25)]),
        ]

        let result = HistoricalRateSnapshot.merge(existing: existing, new: newData)

        #expect(result.map(\.date) == [eightDaysAgo, fiveDaysAgo, twoDaysAgo, today])
    }

    @Test("duplicate days collapse to one entry and the new one wins")
    func duplicateDaysCollapse() {
        let existing = [
            Self.snapshot(today, [("EUR", 1.08)]),
            Self.snapshot(today, [("EUR", 1.07)]),
        ]
        let newData = [Self.snapshot(today, [("EUR", 1.09)])]

        let result = HistoricalRateSnapshot.merge(existing: existing, new: newData)

        #expect(result.count == 1)
        #expect(result.first?.rates.first?.rate == 1.09)
    }

    @Test("every rate of every day survives the merge")
    func allRatesSurvive() {
        let existing = [Self.snapshot(today, [("EUR", 1.08), ("GBP", 0.85), ("JPY", 110.0)])]
        let newData = [Self.snapshot(yesterday, [("CAD", 1.25), ("AUD", 1.35)])]

        let result = HistoricalRateSnapshot.merge(existing: existing, new: newData)

        #expect(result.map(\.rates.count) == [2, 3])
    }
}
