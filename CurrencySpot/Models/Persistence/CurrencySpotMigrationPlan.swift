import Foundation
import SwiftData

private nonisolated enum CurrencySpotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CurrencySpotSchemaV1.self, CurrencySpotSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [relationalHistoryToBlobs]
    }

    private static let relationalHistoryToBlobs = MigrationStage.custom(
        fromVersion: CurrencySpotSchemaV1.self,
        toVersion: CurrencySpotSchemaV2.self,
        willMigrate: { context in
            for day in try context.fetch(FetchDescriptor<CurrencySpotSchemaV1.HistoricalRateData>()) {
                context.delete(day)
            }
            try context.delete(model: CurrencySpotSchemaV1.TrendData.self)
            try context.save()
        },
        didMigrate: nil
    )
}

extension ModelContainer {
    static func currencySpot(storeURL: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: CurrencySpotSchemaV2.self),
            migrationPlan: CurrencySpotMigrationPlan.self,
            configurations: ModelConfiguration(url: storeURL)
        )
    }

    static func inMemoryCurrencySpot() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: CurrencySpotSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
