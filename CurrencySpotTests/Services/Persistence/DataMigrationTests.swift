//
//  DataMigrationTests.swift
//  CurrencySpotTests
//

import Foundation
import SwiftData
import Testing
@testable import CurrencySpot

@Suite("DataMigration")
struct DataMigrationTests {
    private static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            for: ExchangeRateData.self, HistoricalRateData.self, TrendData.self,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: ExchangeRateData.self, HistoricalRateData.self, TrendData.self,
            configurations: configuration
        )
    }

    private static func makeDefaults() -> UserDefaults {
        let name = "DataMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("first run purges v1 cached rate data")
    func purgesCachedDataOnFirstRun() throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        try context.save()

        DataMigration.runIfNeeded(modelContainer: container, defaults: Self.makeDefaults())

        let remaining = try context.fetch(FetchDescriptor<ExchangeRateData>())
        #expect(remaining.isEmpty)
    }

    @Test("first run clears the last-fetch date so rates refetch immediately")
    func clearsLastFetchDate() throws {
        let container = try Self.makeContainer()
        let defaults = Self.makeDefaults()
        defaults.set(Date(), forKey: UserDefaultsKeys.lastFetchDate)

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(defaults.object(forKey: UserDefaultsKeys.lastFetchDate) == nil)
    }

    @Test("first run resets the historical sync coverage window")
    func resetsHistoricalSyncCoverage() throws {
        let container = try Self.makeContainer()
        let defaults = Self.makeDefaults()
        let store = UserDefaultsHistoricalSyncStore(defaults: defaults)
        store.record(
            from: Date(timeIntervalSince1970: 1),
            through: Date(timeIntervalSince1970: 2),
            at: Date(timeIntervalSince1970: 3)
        )

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        // Otherwise the watermark would claim coverage over the just-purged store → blank charts.
        #expect(store.from == nil)
        #expect(store.through == nil)
        #expect(store.checkedAt == nil)
    }

    @Test("the blob-schema step purges historical rows even when the v2 step already ran")
    func blobMigrationPurgesHistoricalRows() throws {
        let container = try Self.makeContainer()
        let defaults = Self.makeDefaults()
        // Simulate a device that migrated to v2 long ago but predates the blob schema.
        defaults.set(true, forKey: "DidMigrateToFrankfurterV2")

        let context = container.mainContext
        context.insert(try HistoricalRateData(dateString: "2025-03-15", rates: ["EUR": 1.21]))
        try context.save()
        let store = UserDefaultsHistoricalSyncStore(defaults: defaults)
        store.record(
            from: Date(timeIntervalSince1970: 1),
            through: Date(timeIntervalSince1970: 2),
            at: Date(timeIntervalSince1970: 3)
        )

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(try context.fetch(FetchDescriptor<HistoricalRateData>()).isEmpty)
        #expect(store.from == nil)

        // A second run leaves freshly written blob rows intact.
        context.insert(try HistoricalRateData(dateString: "2025-03-16", rates: ["EUR": 1.22]))
        try context.save()
        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)
        #expect(try context.fetch(FetchDescriptor<HistoricalRateData>()).count == 1)
    }

    @Test("does nothing once migration has already run")
    func skipsWhenAlreadyMigrated() throws {
        let container = try Self.makeContainer()
        let defaults = Self.makeDefaults()

        // First run marks completion.
        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        // New data arrives post-migration; a second run must leave it intact.
        let context = container.mainContext
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        try context.save()

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        #expect(try context.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
    }
}
