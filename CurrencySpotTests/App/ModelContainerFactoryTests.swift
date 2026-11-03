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

    private func completeDataMigration(in defaults: UserDefaults) throws {
        DataMigration.runIfNeeded(modelContainer: try .inMemoryCurrencySpot(), defaults: defaults, legacyStoreURL: legacyStore.storeURL)
    }

    private static func recordSyncState(in defaults: UserDefaults) {
        UserDefaultsHistoricalSyncStore(defaults: defaults).record(from: coveredFrom, through: coveredThrough, at: coveredThrough)
        UserDefaultsRatesFetchDateStore(defaults: defaults).lastFetchDate = coveredThrough
    }
}
