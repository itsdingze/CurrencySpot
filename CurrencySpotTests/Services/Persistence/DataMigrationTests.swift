import Foundation
import SwiftData
import Testing
@testable import CurrencySpot

@Suite("DataMigration")
struct DataMigrationTests {
    private let suiteName = "DataMigrationTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let container: ModelContainer
    private let legacyStore: TemporaryStoreDirectory

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        container = try ModelContainer.inMemoryCurrencySpot()
        legacyStore = try TemporaryStoreDirectory()
    }

    private func removeDefaults() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func runMigration() {
        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults, legacyStoreURL: legacyStore.storeURL)
    }

    private var legacyFolder: URL {
        legacyStore.storeURL.deletingLastPathComponent()
    }

    private func legacyFolderContents() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: legacyFolder.path(percentEncoded: false)).sorted()
    }

    private func writeLegacyFiles(_ names: [String]) throws {
        for name in names {
            try Data("saved".utf8).write(to: legacyFolder.appending(path: name))
        }
    }

    @Test("first run purges v1 cached rate data")
    func purgesCachedDataOnFirstRun() throws {
        defer { removeDefaults() }
        let context = container.mainContext
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        try context.save()

        runMigration()

        #expect(try context.fetch(FetchDescriptor<ExchangeRateData>()).isEmpty)
    }

    @Test("first run clears the last-fetch date so rates refetch immediately")
    func clearsLastFetchDate() throws {
        defer { removeDefaults() }
        defaults.set(Date(timeIntervalSince1970: 1), forKey: UserDefaultsKeys.lastFetchDate)

        runMigration()

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

        runMigration()

        #expect(store.from == nil)
        #expect(store.through == nil)
        #expect(store.checkedAt == nil)
    }

    @Test("repairs partial historical rows on an already migrated store")
    func repairsPartialHistoricalRows() throws {
        defer { removeDefaults() }
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")
        defaults.set(true, forKey: "DidClearHistoryForArchiveBackfill")
        let context = container.mainContext
        for (day, rates) in [("2026-10-05", ["KPW": 130.02]), ("2026-10-06", ["EUR": 0.86, "GBP": 0.75])] {
            context.insert(try HistoricalRateData(date: try #require(CETCalendar.date(fromDayString: day)), rates: rates))
        }
        try context.save()

        runMigration()

        let remaining = try context.fetch(FetchDescriptor<HistoricalRateData>()).map { CETCalendar.dayString(for: $0.date) }
        #expect(remaining == ["2026-10-06"])
    }

    @Test("an update from an earlier version clears saved history and its sync note once, keeping current rates")
    func clearsHistoryAndItsNoteOnceOnUpdate() throws {
        defer { removeDefaults() }
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")
        let context = container.mainContext
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        context.insert(try HistoricalRateData(date: try #require(CETCalendar.date(fromDayString: "2026-10-06")), rates: ["EUR": 0.86]))
        try context.save()
        let note = UserDefaultsHistoricalSyncStore(defaults: defaults)
        note.record(from: Date(timeIntervalSince1970: 1), through: Date(timeIntervalSince1970: 2), at: Date(timeIntervalSince1970: 3))

        runMigration()

        #expect(try context.fetch(FetchDescriptor<HistoricalRateData>()).isEmpty)
        #expect(note.from == nil)
        #expect(note.through == nil)
        #expect(try context.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
    }

    @Test("an update deletes the earlier version's store files and leaves the rest of that folder")
    func deletesTheEarlierVersionsStoreOnUpdate() throws {
        defer { removeDefaults() }
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")
        try writeLegacyFiles(["default.store", "default.store-wal", "default.store-shm", "other.file"])

        runMigration()

        #expect(try legacyFolderContents() == ["other.file"])
    }

    @Test("a failed delete of the earlier version's store is tried again on the next launch")
    func retriesDeletingTheEarlierStore() throws {
        defer { removeDefaults() }
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")
        try writeLegacyFiles(["default.store"])
        let folder = legacyFolder.path(percentEncoded: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder) }
        runMigration()
        #expect(try legacyFolderContents() == ["default.store"])
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder)

        runMigration()

        #expect(try legacyFolderContents().isEmpty)
    }

    @Test("an update keeps the earlier version's store when the app is still using it")
    func keepsTheEarlierStoreWhileItIsInUse() throws {
        defer { removeDefaults() }

        let savedRates = try savedRatesAfterUpdatingStoreInUse(earlierLocation: legacyStore.storeURL)

        #expect(savedRates == 1)
    }

    @Test("an update keeps the store in use when the earlier location reaches it through a link")
    func keepsTheStoreInUseReachedThroughALink() throws {
        defer { removeDefaults() }
        let link = FileManager.default.temporaryDirectory.appending(path: "DataMigrationLink-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: legacyFolder)
        defer { try? FileManager.default.removeItem(at: link) }

        let savedRates = try savedRatesAfterUpdatingStoreInUse(earlierLocation: link.appending(path: "default.store"))

        #expect(savedRates == 1)
    }

    private func savedRatesAfterUpdatingStoreInUse(earlierLocation: URL) throws -> Int {
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")
        let storeInUse = try ModelContainer.currencySpot(storeURL: legacyStore.storeURL)
        storeInUse.mainContext.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        try storeInUse.mainContext.save()

        DataMigration.runIfNeeded(modelContainer: storeInUse, defaults: defaults, legacyStoreURL: earlierLocation)

        let reopened = try ModelContainer.currencySpot(storeURL: legacyStore.storeURL)
        return try reopened.mainContext.fetchCount(FetchDescriptor<ExchangeRateData>())
    }

    @Test("history downloaded after the one-time clear survives later launches")
    func keepsHistoryDownloadedAfterTheClear() throws {
        defer { removeDefaults() }
        runMigration()
        let context = container.mainContext
        context.insert(try HistoricalRateData(date: try #require(CETCalendar.date(fromDayString: "2026-10-06")), rates: ["EUR": 0.86]))
        try context.save()
        let note = UserDefaultsHistoricalSyncStore(defaults: defaults)
        note.record(from: Date(timeIntervalSince1970: 1), through: Date(timeIntervalSince1970: 2), at: Date(timeIntervalSince1970: 3))

        runMigration()

        #expect(try context.fetch(FetchDescriptor<HistoricalRateData>()).count == 1)
        #expect(note.from == Date(timeIntervalSince1970: 1))
    }

    @Test("a later launch leaves files at the earlier store location alone")
    func laterLaunchKeepsFilesAtTheEarlierLocation() throws {
        defer { removeDefaults() }
        runMigration()
        try writeLegacyFiles(["default.store"])

        runMigration()

        #expect(try legacyFolderContents() == ["default.store"])
    }

    @Test("does nothing once migration has already run")
    func skipsWhenAlreadyMigrated() throws {
        defer { removeDefaults() }
        runMigration()

        let context = container.mainContext
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        try context.save()

        runMigration()

        #expect(try context.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
    }
}
