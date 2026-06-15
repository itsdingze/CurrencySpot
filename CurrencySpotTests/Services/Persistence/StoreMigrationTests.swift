//
//  StoreMigrationTests.swift
//  CurrencySpotTests
//
//  Proves a real on-disk store written by the v1.0.x relational schema opens under
//  the current blob schema (SwiftData lightweight migration) and that DataMigration
//  then purges it cleanly. This is the one upgrade-path link the in-memory
//  DataMigrationTests cannot exercise.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

/// The historical schema as shipped through v1.0.x: one row per date with a cascade
/// relationship to per-currency child rows. Nested under an enum (Apple's
/// `VersionedSchema` pattern) so these `@Model` types keep the on-disk entity names
/// "HistoricalRateData" / "HistoricalRateDataPoint" while staying distinct Swift
/// types from the current production models — same store, different code.
enum LegacyV1Schema {
    @Model
    final class HistoricalRateDataPoint {
        var currencyCode: String
        var rate: Double
        var historicalData: HistoricalRateData?

        init(currencyCode: String, rate: Double) {
            self.currencyCode = currencyCode
            self.rate = rate
        }
    }

    @Model
    final class HistoricalRateData {
        @Attribute(.unique) var date: Date
        @Relationship(deleteRule: .cascade, inverse: \HistoricalRateDataPoint.historicalData)
        var rates: [HistoricalRateDataPoint] = []

        init(date: Date, rates: [HistoricalRateDataPoint]) {
            self.date = date
            self.rates = rates
        }
    }
}

@Suite("Store migration (v1.0.x relational → blob)")
struct StoreMigrationTests {
    /// The schema the old build registered. `ExchangeRateData` / `TrendData` are
    /// unchanged across versions, so the production types stand in for them faithfully.
    private static var legacySchema: Schema {
        Schema([
            LegacyV1Schema.HistoricalRateData.self,
            LegacyV1Schema.HistoricalRateDataPoint.self,
            ExchangeRateData.self,
            TrendData.self,
        ])
    }

    private static func makeDefaults() -> UserDefaults {
        let name = "StoreMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("a real v1.0.x on-disk store opens under the current schema, then DataMigration purges it")
    func legacyStoreOpensAndPurges() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "StoreMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")

        // 1. Write a store with the OLD relational schema, then drop the container so
        //    SwiftData checkpoints the WAL before we reopen the same file.
        try writeLegacyStore(at: storeURL)

        // 2. Opening with the current schema must NOT throw — this is the lightweight
        //    migration the upgrade depends on: drop HistoricalRateDataPoint, drop the
        //    relationship, add the defaulted `ratesData` blob.
        let container = try ModelContainer(
            for: ModelContainer.currencySpotSchema,
            configurations: ModelConfiguration(url: storeURL)
        )

        // 3. The old rows carry over (proving a migration happened, not a fresh store):
        //    the pre-blob HistoricalRateData row survives with an empty `ratesData`.
        let migratedContext = ModelContext(container)
        #expect(try migratedContext.fetch(FetchDescriptor<HistoricalRateData>()).count == 1)
        #expect(try migratedContext.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
        #expect(try migratedContext.fetch(FetchDescriptor<TrendData>()).count == 1)

        // 4. DataMigration purges the stale rows and clears the coverage watermark so
        //    the app refetches from Frankfurter v2.
        let defaults = Self.makeDefaults()
        let syncStore = UserDefaultsHistoricalSyncStore(defaults: defaults)
        syncStore.record(
            from: Date(timeIntervalSince1970: 1),
            through: Date(timeIntervalSince1970: 2),
            at: Date(timeIntervalSince1970: 3)
        )

        DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)

        let context = ModelContext(container)
        #expect(try context.fetch(FetchDescriptor<HistoricalRateData>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ExchangeRateData>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TrendData>()).isEmpty)
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
    }

    /// Builds and saves a v1.0.x-shaped store at `url`, then releases the container.
    private func writeLegacyStore(at url: URL) throws {
        let container = try ModelContainer(for: Self.legacySchema, configurations: ModelConfiguration(url: url))
        let context = ModelContext(container)

        let day = try #require(createCETDate(year: 2025, month: 3, day: 15))
        context.insert(LegacyV1Schema.HistoricalRateData(
            date: day,
            rates: [
                LegacyV1Schema.HistoricalRateDataPoint(currencyCode: "EUR", rate: 1.21),
                LegacyV1Schema.HistoricalRateDataPoint(currencyCode: "GBP", rate: 1.38),
            ]
        ))
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
        context.insert(TrendData(currencyCode: "EUR", weeklyChange: 1.2, miniChartData: [1, 2, 3]))
        try context.save()
    }
}
