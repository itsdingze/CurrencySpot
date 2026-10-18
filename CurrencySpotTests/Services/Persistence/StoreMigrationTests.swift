import CoreData
@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Store migration")
struct StoreMigrationTests {
    private let store: TemporaryStoreDirectory

    init() throws {
        store = try TemporaryStoreDirectory()
    }

    @Test("each versioned schema hashes exactly like the stores v1.0.x and v1.1.x shipped")
    func versionHashesMatchShippedStores() throws {
        #expect(try entityVersionHashes(of: CurrencySpotSchemaV1.models) == [
            "ExchangeRateData": "TxB2Decy7MTqsYv1n9uk3XYEjpkE81Hd3vuX4MuyBFw=",
            "HistoricalRateData": "umuO5yCzXdNd4HOjX8E/1rMZ2a3ZBf0PtgbqpHLt7UU=",
            "HistoricalRateDataPoint": "cjP2PqcoAoMydOHJ6zCKboyKgHzqK7hnNZ13RYKt0lo=",
            "TrendData": "iC8DiW2UHiF/oHKGDOEwkoOf5ZNNV/bmyiudZFblduw=",
        ])
        #expect(try entityVersionHashes(of: CurrencySpotSchemaV2.models) == [
            "ExchangeRateData": "TxB2Decy7MTqsYv1n9uk3XYEjpkE81Hd3vuX4MuyBFw=",
            "HistoricalRateData": "JZUYsA9o2PSx6SnwDWur/6QUqd12IipjXCawTlpiVZk=",
            "TrendData": "iC8DiW2UHiF/oHKGDOEwkoOf5ZNNV/bmyiudZFblduw=",
        ])
    }

    @Test("a v1.0.x relational store opens under the migration plan with its history and trends purged")
    func legacyRelationalStoreMigrates() throws {
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

        let context = ModelContext(try ModelContainer.currencySpot(storeURL: store.storeURL))

        #expect(try context.fetch(FetchDescriptor<HistoricalRateData>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TrendData>()).isEmpty)
    }

    @Test("a v1.1.x blob store opens under the migration plan with every row intact")
    func currentUnversionedStoreKeepsItsData() throws {
        let day = try #require(createCETDate(year: 2025, month: 3, day: 15))
        try writeStore(schema: Schema(CurrencySpotSchemaV2.models)) { context in
            context.insert(try HistoricalRateData(date: day, rates: ["EUR": 1.21]))
            context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.86))
            context.insert(TrendData(currencyCode: "EUR", weeklyChange: 1.2, miniChartData: [1, 2, 3]))
        }

        let context = ModelContext(try ModelContainer.currencySpot(storeURL: store.storeURL))

        let history = try context.fetch(FetchDescriptor<HistoricalRateData>())
        #expect(try history.map { try $0.toDomain().rates.map(\.rate) } == [[1.21]])
        #expect(try context.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<TrendData>()).count == 1)
    }

    private func entityVersionHashes(of models: [any PersistentModel.Type]) throws -> [String: String] {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: models))
        return model.entityVersionHashesByName.mapValues { $0.base64EncodedString() }
    }

    private func writeStore(schema: Schema, populate: (ModelContext) throws -> Void) throws {
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(url: store.storeURL))
        let context = ModelContext(container)
        try populate(context)
        try context.save()
    }
}
