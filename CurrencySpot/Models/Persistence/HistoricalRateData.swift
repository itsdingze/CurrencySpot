import Foundation
import SwiftData

@Model
nonisolated final class HistoricalRateData {
    @Attribute(.unique) var date: Date

    var ratesData: Data = Data()

    init(date: Date, ratesData: Data) {
        self.date = date
        self.ratesData = ratesData
    }
}

private nonisolated let ratesEncoder = JSONEncoder()
private nonisolated let ratesDecoder = JSONDecoder()

nonisolated extension HistoricalRateData {
    convenience init(date: Date, rates: [String: Double]) throws {
        self.init(date: date, ratesData: try ratesEncoder.encode(rates))
    }
}

// MARK: - Entity -> Domain Mapping

nonisolated extension HistoricalRateData {
    func toDomain() throws -> HistoricalRateSnapshot {
        let rates = try ratesDecoder.decode([String: Double].self, from: ratesData)
        return HistoricalRateSnapshot(
            date: date,
            rates: try rates.map {
                HistoricalRatePoint(currencyCode: try CurrencyCode(validating: $0.key), rate: $0.value)
            }
        )
    }
}
