@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("ModelContainerFactory")
struct ModelContainerFactoryTests {
    private let store: TemporaryStoreDirectory
    private let legacyStore: TemporaryStoreDirectory
    private let isolatedDefaults = IsolatedDefaults()

    init() throws {
        store = try TemporaryStoreDirectory()
        legacyStore = try TemporaryStoreDirectory()
    }

    private func makeContainer(storeURL: URL, defaults: UserDefaults, errorHandler: ErrorHandler = ErrorHandler()) -> ModelContainer {
        ModelContainerFactory.persistentContainer(
            storeURL: storeURL,
            legacyStoreURL: legacyStore.storeURL,
            defaults: defaults,
            errorHandler: errorHandler
        )
    }

    @Test("opening the store after an update deletes the earlier version's store")
    func updateDeletesTheEarlierStore() throws {
        try Data("saved".utf8).write(to: legacyStore.storeURL)

        _ = makeContainer(storeURL: store.storeURL, defaults: try isolatedDefaults.make())

        #expect(!FileManager.default.fileExists(atPath: legacyStore.storeURL.path(percentEncoded: false)))
    }

    @Test("an update from 1.1.2 moves its store into place, keeping saved rates and clearing saved history")
    func updateMovesTheEarlierStore() throws {
        let defaults = try isolatedDefaults.make()
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")
        try writeEarlierVersionStore()
        let storeURL = store.storeURL.deletingLastPathComponent().appending(path: "Library/Application Support/default.store")

        let container = makeContainer(storeURL: storeURL, defaults: defaults)

        let context = ModelContext(container)
        let savedRates = try context.fetchCount(FetchDescriptor<ExchangeRateData>())
        let savedDays = try context.fetchCount(FetchDescriptor<HistoricalRateData>())
        #expect(savedRates == 1)
        #expect(savedDays == 0)
        #expect(try legacyStoreFiles().isEmpty)
    }

    @Test("when both versions' stores exist, the current one opens with its rows and the earlier one is deleted")
    func bothStoresKeepTheCurrentOne() throws {
        let defaults = try isolatedDefaults.make()
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")
        try writeEarlierVersionStore()
        let current = ModelContext(try ModelContainer.currencySpot(storeURL: store.storeURL))
        current.insert(ExchangeRateData(currencyCode: "GBP", rate: 0.75))
        current.insert(ExchangeRateData(currencyCode: "JPY", rate: 150))
        try current.save()

        let container = makeContainer(storeURL: store.storeURL, defaults: defaults)

        let savedRates = try ModelContext(container).fetchCount(FetchDescriptor<ExchangeRateData>())
        #expect(savedRates == 2)
        #expect(try legacyStoreFiles().isEmpty)
    }

    @Test("an earlier store that can't be moved leaves the app on a new store, as before the move existed")
    func unmovableEarlierStoreFallsBackToANewStore() throws {
        let defaults = try isolatedDefaults.make()
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")
        try writeEarlierVersionStore()
        let legacyFolder = legacyStore.storeURL.deletingLastPathComponent().path(percentEncoded: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: legacyFolder)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: legacyFolder) }

        let container = makeContainer(storeURL: store.storeURL, defaults: defaults)

        let configuration = try #require(container.configurations.first)
        #expect(!configuration.isStoredInMemoryOnly)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExchangeRateData>()) == 0)
        #expect(try legacyStoreFiles().contains("default.store"))
    }

    @Test("rebuilding an unreadable store clears the sync coverage and the rates fetch date")
    func rebuiltStoreClearsSyncState() throws {
        let defaults = try isolatedDefaults.make()
        try completeDataMigration(in: defaults)
        Self.recordSyncState(in: defaults)
        try Data("not a database".utf8).write(to: store.storeURL)

        _ = makeContainer(storeURL: store.storeURL, defaults: defaults)

        let syncStore = UserDefaultsHistoricalSyncStore(defaults: defaults)
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
        #expect(UserDefaultsRatesFetchDateStore(defaults: defaults).lastFetchDate == nil)
    }

    @Test("a healthy store keeps the sync coverage and the rates fetch date")
    func healthyStoreKeepsSyncState() throws {
        let defaults = try isolatedDefaults.make()
        try completeDataMigration(in: defaults)
        Self.recordSyncState(in: defaults)

        _ = makeContainer(storeURL: store.storeURL, defaults: defaults)

        let syncStore = UserDefaultsHistoricalSyncStore(defaults: defaults)
        #expect(syncStore.from == Self.coveredFrom)
        #expect(syncStore.through == Self.coveredThrough)
        #expect(UserDefaultsRatesFetchDateStore(defaults: defaults).lastFetchDate == Self.coveredThrough)
    }

    @Test("a store the app can't read right now runs this launch from memory and keeps the sync coverage and the rates fetch date")
    func unreadableStoreRunsFromMemory() throws {
        let defaults = try isolatedDefaults.make()
        try completeDataMigration(in: defaults)
        Self.recordSyncState(in: defaults)
        _ = try ModelContainer.currencySpot(storeURL: store.storeURL)
        let storePath = store.storeURL.path(percentEncoded: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: storePath)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: storePath) }

        let container = makeContainer(storeURL: store.storeURL, defaults: defaults)

        let configuration = try #require(container.configurations.first)
        #expect(configuration.isStoredInMemoryOnly)
        #expect(UserDefaultsHistoricalSyncStore(defaults: defaults).through == Self.coveredThrough)
        #expect(UserDefaultsRatesFetchDateStore(defaults: defaults).lastFetchDate == Self.coveredThrough)
    }

    @Test("a store that can't be opened even after a rebuild falls back to memory and reports storage unavailable")
    func unopenableStoreFallsBackToMemory() throws {
        let blocker = store.storeURL.deletingLastPathComponent().appending(path: "blocker")
        try Data().write(to: blocker)
        let errorHandler = ErrorHandler()

        let container = makeContainer(
            storeURL: blocker.appending(path: "default.store"),
            defaults: try isolatedDefaults.make(),
            errorHandler: errorHandler
        )

        #expect(errorHandler.currentError == .initializationFailed("Persistent storage failed"))
        let configuration = try #require(container.configurations.first)
        #expect(configuration.isStoredInMemoryOnly)
    }

    // MARK: - Fixtures

    private static let coveredFrom = Date(timeIntervalSince1970: 1_700_000_000)
    private static let coveredThrough = Date(timeIntervalSince1970: 1_730_000_000)

    private func writeEarlierVersionStore() throws {
        let context = ModelContext(try ModelContainer.currencySpot(storeURL: legacyStore.storeURL))
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        context.insert(try HistoricalRateData(date: try #require(CETCalendar.date(fromDayString: "2026-09-24")), rates: ["EUR": 0.86]))
        try context.save()
    }

    private func legacyStoreFiles() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: legacyStore.storeURL.deletingLastPathComponent().path(percentEncoded: false))
    }

    private func completeDataMigration(in defaults: UserDefaults) throws {
        DataMigration.runIfNeeded(modelContainer: try .inMemoryCurrencySpot(), defaults: defaults, legacyStoreURL: legacyStore.storeURL)
    }

    private static func recordSyncState(in defaults: UserDefaults) {
        UserDefaultsHistoricalSyncStore(defaults: defaults).record(from: coveredFrom, through: coveredThrough, at: coveredThrough)
        UserDefaultsRatesFetchDateStore(defaults: defaults).lastFetchDate = coveredThrough
    }
}
