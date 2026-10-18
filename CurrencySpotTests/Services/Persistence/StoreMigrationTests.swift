@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Store migration")
struct StoreMigrationTests {
    private let directory: URL
    private let storeURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "StoreMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appending(path: "default.store")
    }

    private func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("a v1.0.x relational store opens under the migration plan with its history and trends purged")
    func legacyRelationalStoreMigrates() throws {
        defer { removeDirectory() }
        try writeStore(schema: Schema(versionedSchema: CurrencySpotSchemaV1.self)) { context in
            let day = try #require(createCETDate(year: 2025, month: 3, day: 15))
            context.insert(CurrencySpotSchemaV1.HistoricalRateData(
                date: day,
                rates: [
                    CurrencySpotSchemaV1.HistoricalRateDataPoint(currencyCode: "EUR", rate: 1.21),
                    CurrencySpotSchemaV1.HistoricalRateDataPoint(currencyCode: "GBP", rate: 1.38),
                ]
            ))
            context.insert(CurrencySpotSchemaV1.TrendData(currencyCode: "EUR", weeklyChange: 1.2, miniChartData: [1, 2, 3]))
        }

        let context = ModelContext(try ModelContainer.currencySpot(storeURL: storeURL))

        #expect(try context.fetch(FetchDescriptor<HistoricalRateData>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TrendData>()).isEmpty)
    }

    @Test("a v1.1.x blob store opens under the migration plan with every row intact")
    func currentUnversionedStoreKeepsItsData() throws {
        defer { removeDirectory() }
        let day = try #require(createCETDate(year: 2025, month: 3, day: 15))
        try writeStore(schema: Schema(CurrencySpotSchemaV2.models)) { context in
            context.insert(try HistoricalRateData(date: day, rates: ["EUR": 1.21]))
            context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
            context.insert(TrendData(currencyCode: "EUR", weeklyChange: 1.2, miniChartData: [1, 2, 3]))
        }

        let context = ModelContext(try ModelContainer.currencySpot(storeURL: storeURL))

        let history = try context.fetch(FetchDescriptor<HistoricalRateData>())
        #expect(try history.map { try $0.toDomain().rates.map(\.rate) } == [[1.21]])
        #expect(try context.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<TrendData>()).count == 1)
    }

    private func writeStore(schema: Schema, populate: (ModelContext) throws -> Void) throws {
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(url: storeURL))
        let context = ModelContext(container)
        try populate(context)
        try context.save()
    }
}
