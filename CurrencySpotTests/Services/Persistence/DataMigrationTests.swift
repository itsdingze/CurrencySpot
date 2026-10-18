import Foundation
import SwiftData
import Testing
@testable import CurrencySpot

@Suite("DataMigration")
struct DataMigrationTests {
    private let suiteName = "DataMigrationTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let container: ModelContainer

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        container = try ModelContainer.inMemoryCurrencySpot()
    }

    private func removeDefaults() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("first run purges v1 cached rate data")
    func purgesCachedDataOnFirstRun() throws {
        defer { removeDefaults() }
        let context = container.mainContext
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        try context.save()

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(try context.fetch(FetchDescriptor<ExchangeRateData>()).isEmpty)
    }

    @Test("first run clears the last-fetch date so rates refetch immediately")
    func clearsLastFetchDate() throws {
        defer { removeDefaults() }
        defaults.set(Date(timeIntervalSince1970: 1), forKey: UserDefaultsKeys.lastFetchDate)

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(defaults.object(forKey: UserDefaultsKeys.lastFetchDate) == nil)
    }

    @Test("first run resets the historical sync coverage window")
    func resetsHistoricalSyncCoverage() throws {
        defer { removeDefaults() }
        let store = UserDefaultsHistoricalSyncStore(defaults: defaults)
        store.record(
            from: Date(timeIntervalSince1970: 1),
            through: Date(timeIntervalSince1970: 2),
            at: Date(timeIntervalSince1970: 3)
        )

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(store.from == nil)
        #expect(store.through == nil)
        #expect(store.checkedAt == nil)
    }

    @Test("repairs partial historical rows on an already migrated store")
    func repairsPartialHistoricalRows() throws {
        defer { removeDefaults() }
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")
        let context = container.mainContext
        for (day, rates) in [("2026-10-05", ["KPW": 130.02]), ("2026-10-06", ["EUR": 0.86, "GBP": 0.75])] {
            context.insert(try HistoricalRateData(date: try #require(CETCalendar.date(fromDayString: day)), rates: rates))
        }
        try context.save()

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        let remaining = try context.fetch(FetchDescriptor<HistoricalRateData>()).map { CETCalendar.dayString(for: $0.date) }
        #expect(remaining == ["2026-10-06"])
    }

    @Test("does nothing once migration has already run")
    func skipsWhenAlreadyMigrated() throws {
        defer { removeDefaults() }
        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        let context = container.mainContext
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        try context.save()

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(try context.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
    }
}
