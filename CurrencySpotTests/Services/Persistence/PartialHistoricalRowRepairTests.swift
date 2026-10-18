import Foundation
import SwiftData
import Testing
@testable import CurrencySpot

@Suite("PartialHistoricalRowRepair")
struct PartialHistoricalRowRepairTests {
    private static let fullQuotes = ["EUR": 0.86, "GBP": 0.75, "JPY": 150.1, "CHF": 0.80, "CAD": 1.37]
    private static let partialQuotes = ["KPW": 130.02]

    private let isolatedDefaults = IsolatedDefaults()
    private let defaults: UserDefaults
    private let container: ModelContainer

    init() throws {
        defaults = try isolatedDefaults.make()
        container = try ModelContainer.inMemoryCurrencySpot()
    }

    private func insertRows(_ rows: [(day: String, rates: [String: Double])]) throws {
        let context = container.mainContext
        for row in rows {
            let date = try #require(CETCalendar.date(fromDayString: row.day))
            context.insert(try HistoricalRateData(date: date, rates: row.rates))
        }
        try context.save()
    }

    private func storedDays() throws -> [String] {
        let descriptor = FetchDescriptor<HistoricalRateData>(sortBy: [SortDescriptor(\.date)])
        return try container.mainContext.fetch(descriptor).map { CETCalendar.dayString(for: $0.date) }
    }

    @Test("leaves a store without partial rows and its coverage untouched")
    func leavesHealthyStoreUntouched() throws {
        try insertRows([
            ("2026-10-05", Self.fullQuotes),
            ("2026-10-06", Self.fullQuotes),
            ("2026-10-07", Self.fullQuotes),
        ])
        let syncStore = UserDefaultsHistoricalSyncStore(defaults: defaults)
        let from = try #require(CETCalendar.date(fromDayString: "2026-10-01"))
        let through = try #require(CETCalendar.date(fromDayString: "2026-10-09"))
        let checkedAt = Date(timeIntervalSince1970: 1_791_000_000)
        syncStore.record(from: from, through: through, at: checkedAt)

        PartialHistoricalRowRepair.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(try storedDays() == ["2026-10-05", "2026-10-06", "2026-10-07"])
        #expect(syncStore.from == from)
        #expect(syncStore.through == through)
        #expect(syncStore.checkedAt == checkedAt)
    }

    @Test("runs only once per install")
    func runsOnlyOnce() throws {
        PartialHistoricalRowRepair.runIfNeeded(modelContainer: container, defaults: defaults)
        try insertRows([
            ("2026-10-05", Self.partialQuotes),
            ("2026-10-06", Self.fullQuotes),
            ("2026-10-07", Self.fullQuotes),
        ])

        PartialHistoricalRowRepair.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(try storedDays() == ["2026-10-05", "2026-10-06", "2026-10-07"])
    }

    @Test("deletes every row on or before the newest partial day and keeps the newer rows")
    func deletesRowsThroughNewestPartialDay() throws {
        try insertRows([
            ("2026-10-03", Self.partialQuotes),
            ("2026-10-04", Self.fullQuotes),
            ("2026-10-05", Self.partialQuotes),
            ("2026-10-06", Self.fullQuotes),
            ("2026-10-07", Self.fullQuotes),
        ])

        PartialHistoricalRowRepair.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(try storedDays() == ["2026-10-06", "2026-10-07"])
    }

    @Test("treats an undecodable row as partial")
    func treatsUndecodableRowAsPartial() throws {
        try insertRows([
            ("2026-10-04", Self.fullQuotes),
            ("2026-10-06", Self.fullQuotes),
            ("2026-10-07", Self.fullQuotes),
        ])
        let undecodableDay = try #require(CETCalendar.date(fromDayString: "2026-10-05"))
        container.mainContext.insert(HistoricalRateData(date: undecodableDay, ratesData: Data("not json".utf8)))
        try container.mainContext.save()

        PartialHistoricalRowRepair.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(try storedDays() == ["2026-10-06", "2026-10-07"])
    }

    @Test("narrows coverage to where it overlaps the kept rows and keeps the check time")
    func narrowsCoverageToKeptRows() throws {
        try insertRows([
            ("2026-10-03", Self.fullQuotes),
            ("2026-10-04", Self.partialQuotes),
            ("2026-10-05", Self.fullQuotes),
            ("2026-10-06", Self.fullQuotes),
            ("2026-10-07", Self.fullQuotes),
        ])
        let syncStore = UserDefaultsHistoricalSyncStore(defaults: defaults)
        let checkedAt = Date(timeIntervalSince1970: 1_791_000_000)
        syncStore.record(
            from: try #require(CETCalendar.date(fromDayString: "2026-10-01")),
            through: try #require(CETCalendar.date(fromDayString: "2026-10-06")),
            at: checkedAt
        )

        PartialHistoricalRowRepair.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(syncStore.from == CETCalendar.date(fromDayString: "2026-10-05"))
        #expect(syncStore.through == CETCalendar.date(fromDayString: "2026-10-06"))
        #expect(syncStore.checkedAt == checkedAt)
    }

    @Test("clears coverage that claimed only deleted days")
    func clearsCoverageOfDeletedDaysOnly() throws {
        try insertRows([
            ("2026-10-03", Self.fullQuotes),
            ("2026-10-04", Self.partialQuotes),
            ("2026-10-05", Self.fullQuotes),
            ("2026-10-06", Self.fullQuotes),
        ])
        let syncStore = UserDefaultsHistoricalSyncStore(defaults: defaults)
        syncStore.record(
            from: try #require(CETCalendar.date(fromDayString: "2026-10-01")),
            through: try #require(CETCalendar.date(fromDayString: "2026-10-03")),
            at: Date(timeIntervalSince1970: 1_791_000_000)
        )

        PartialHistoricalRowRepair.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
        #expect(syncStore.checkedAt == nil)
    }

    @Test("a partial newest row empties the store and clears coverage")
    func partialNewestRowEmptiesStore() throws {
        try insertRows([
            ("2026-10-05", Self.fullQuotes),
            ("2026-10-06", Self.fullQuotes),
            ("2026-10-07", Self.partialQuotes),
        ])
        let syncStore = UserDefaultsHistoricalSyncStore(defaults: defaults)
        syncStore.record(
            from: try #require(CETCalendar.date(fromDayString: "2026-10-05")),
            through: try #require(CETCalendar.date(fromDayString: "2026-10-07")),
            at: Date(timeIntervalSince1970: 1_791_000_000)
        )

        PartialHistoricalRowRepair.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(try storedDays().isEmpty)
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
        #expect(syncStore.checkedAt == nil)
    }
}
