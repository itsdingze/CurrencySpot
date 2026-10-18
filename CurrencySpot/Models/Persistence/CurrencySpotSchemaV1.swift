import Foundation
import SwiftData

nonisolated enum CurrencySpotSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ExchangeRateData.self, HistoricalRateData.self, HistoricalRateDataPoint.self, TrendData.self]
    }

    @Model
    final class ExchangeRateData {
        @Attribute(.unique) var currencyCode: String
        var rate: Double

        init(currencyCode: String, rate: Double) {
            self.currencyCode = currencyCode
            self.rate = rate
        }
    }

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

    @Model
    final class TrendData {
        @Attribute(.unique) var currencyCode: String
        var weeklyChange: Double
        private var miniChartDataStorage: Data = Data()

        init(currencyCode: String, weeklyChange: Double, miniChartData: [Double]) {
            self.currencyCode = currencyCode
            self.weeklyChange = weeklyChange
            miniChartDataStorage = (try? JSONEncoder().encode(miniChartData)) ?? Data()
        }
    }
}
