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

nonisolated extension HistoricalRateData {
    convenience init(date: Date, rates: [String: Double]) throws {
        self.init(date: date, ratesData: try JSONEncoder().encode(rates))
    }

    convenience init(dateString: String, rates: [String: Double]) throws {
        guard let date = TimeZoneManager.parseAPIDate(dateString) else {
            throw AppError.dataValidationError("Invalid date string: \(dateString)")
        }
        try self.init(date: date, rates: rates)
    }
}

// MARK: - Entity -> Domain Mapping

nonisolated extension HistoricalRateData {
    func toDomain() throws -> HistoricalRateSnapshot {
        let rates = try JSONDecoder().decode([String: Double].self, from: ratesData)
        return HistoricalRateSnapshot(
            date: date,
            rates: try rates.map {
                HistoricalRatePoint(currencyCode: try CurrencyCode(validating: $0.key), rate: $0.value)
            }
        )
    }
}
