//
//  HistoricalRateData.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import Foundation
import SwiftData

@Model
nonisolated final class HistoricalRateData {
    @Attribute(.unique) var date: Date

    /// All currencies' USD-normalized rates for the date, JSON-encoded `[String: Double]`.
    ///
    /// One blob per day instead of per-currency child rows: every reader materializes
    /// whole days anyway, and the row-per-currency shape made a year ~60k managed
    /// objects — multi-second loads and saves for data that is only ever used as one
    /// dictionary per date. The default value keeps lightweight migration of pre-blob
    /// stores possible; `DataMigration` purges those rows.
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

    // Convenience initializer for API date strings
    convenience init(dateString: String, rates: [String: Double]) throws {
        guard let date = TimeZoneManager.parseAPIDate(dateString) else {
            throw AppError.dataValidationError("Invalid date string: \(dateString)")
        }
        try self.init(date: date, rates: rates)
    }
}

// MARK: - Entity -> Domain Mapping

nonisolated extension HistoricalRateData {
    /// Validates stored codes at the persistence → domain boundary.
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
