@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

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

        try writeLegacyStore(at: storeURL)

        let container = try ModelContainer(
            for: ModelContainer.currencySpotSchema,
            configurations: ModelConfiguration(url: storeURL)
        )

        let migratedContext = ModelContext(container)
        #expect(try migratedContext.fetch(FetchDescriptor<HistoricalRateData>()).count == 1)
        #expect(try migratedContext.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
        #expect(try migratedContext.fetch(FetchDescriptor<TrendData>()).count == 1)

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
