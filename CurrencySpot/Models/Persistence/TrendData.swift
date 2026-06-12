//
//  TrendData.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/18/25.
//

import Foundation
import SwiftData

@Model
final class TrendData {
    @Attribute(.unique) var currencyCode: String
    var weeklyChange: Double // % change over 7 days

    // Store as Data instead of [Double] to avoid CoreData serialization issues
    private var miniChartDataStorage: Data = Data()

    // Computed property for accessing as [Double]
    var miniChartData: [Double] {
        get {
            guard !miniChartDataStorage.isEmpty,
                  let decoded = try? JSONDecoder().decode([Double].self, from: miniChartDataStorage) else {
                return []
            }
            return decoded
        }
        set {
            miniChartDataStorage = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(currencyCode: String, weeklyChange: Double, miniChartData: [Double]) {
        self.currencyCode = currencyCode
        self.weeklyChange = weeklyChange
        self.miniChartDataStorage = (try? JSONEncoder().encode(miniChartData)) ?? Data()
    }
}

// MARK: - Entity <-> Domain Mapping

extension TrendData {
    /// Validates the stored code at the persistence → domain boundary.
    func toDomain() throws -> Trend {
        Trend(
            currencyCode: try CurrencyCode(validating: currencyCode),
            weeklyChange: weeklyChange,
            miniChartData: miniChartData
        )
    }

    convenience init(from value: Trend) {
        self.init(
            currencyCode: value.currencyCode.rawValue,
            weeklyChange: value.weeklyChange,
            miniChartData: value.miniChartData
        )
    }
}
