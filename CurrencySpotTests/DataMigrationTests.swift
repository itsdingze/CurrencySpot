//
//  DataMigrationTests.swift
//  CurrencySpotTests
//

import Foundation
import SwiftData
import Testing
@testable import CurrencySpot

@Suite("DataMigration")
@MainActor
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
