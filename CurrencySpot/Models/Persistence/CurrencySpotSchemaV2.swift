import Foundation
import SwiftData

nonisolated enum CurrencySpotSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ExchangeRateData.self, HistoricalRateData.self, TrendData.self]
    }
}

typealias ExchangeRateData = CurrencySpotSchemaV2.ExchangeRateData
typealias HistoricalRateData = CurrencySpotSchemaV2.HistoricalRateData
typealias TrendData = CurrencySpotSchemaV2.TrendData
