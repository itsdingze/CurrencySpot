@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("ModelContainerFactory")
struct ModelContainerFactoryTests {
    private let store: TemporaryStoreDirectory
    private let isolatedDefaults = IsolatedDefaults()

    init() throws {
        store = try TemporaryStoreDirectory()
    }

    @Test("rebuilding an unreadable store clears the sync coverage and the rates fetch date")
    func rebuiltStoreClearsSyncState() throws {
        let defaults = try isolatedDefaults.make()
        try Self.completeDataMigration(in: defaults)
        Self.recordSyncState(in: defaults)
        try Data("not a database".utf8).write(to: store.storeURL)

        _ = ModelContainerFactory.persistentContainer(storeURL: store.storeURL, defaults: defaults, errorHandler: ErrorHandler())

        let syncStore = UserDefaultsHistoricalSyncStore(defaults: defaults)
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
        #expect(UserDefaultsRatesFetchDateStore(defaults: defaults).lastFetchDate == nil)
    }

    @Test("a healthy store keeps the sync coverage and the rates fetch date")
    func healthyStoreKeepsSyncState() throws {
        let defaults = try isolatedDefaults.make()
        try Self.completeDataMigration(in: defaults)
        Self.recordSyncState(in: defaults)

        _ = ModelContainerFactory.persistentContainer(storeURL: store.storeURL, defaults: defaults, errorHandler: ErrorHandler())

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

        let container = ModelContainerFactory.persistentContainer(
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

    private static func completeDataMigration(in defaults: UserDefaults) throws {
        DataMigration.runIfNeeded(modelContainer: try .inMemoryCurrencySpot(), defaults: defaults)
    }

    private static func recordSyncState(in defaults: UserDefaults) {
        UserDefaultsHistoricalSyncStore(defaults: defaults).record(from: coveredFrom, through: coveredThrough, at: coveredThrough)
        UserDefaultsRatesFetchDateStore(defaults: defaults).lastFetchDate = coveredThrough
    }
}
