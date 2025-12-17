//
//  TrendData.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/18/25.
//

import Foundation
import SwiftData
import SwiftUI

enum TrendDirection {
    case up
    case down
    case stable

    /// Threshold for determining stable vs trending (±0.1%)
    static let stableChangeThreshold: Double = 0.1

    var color: Color {
        switch self {
        case .up: .green
        case .down: .red
        case .stable: .orange
        }
    }

    var systemImage: String {
        switch self {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .stable: "equal"
        }
    }

    /// String description for accessibility
    var description: String {
        switch self {
        case .up: "up"
        case .down: "down"
        case .stable: "stable"
        }
    }
}

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
        // Validate and sanitize currency code
        let sanitizedCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if sanitizedCode.isEmpty {
            AppLogger.warning("Empty currency code provided, using 'XXX' as placeholder", category: .data)
            self.currencyCode = "XXX"
        } else if sanitizedCode.count != 3 {
            AppLogger.warningPrivate("Invalid currency code '\(sanitizedCode)' (expected 3 characters), truncating/padding to 3", category: .data)
            // Truncate or pad to exactly 3 characters
            if sanitizedCode.count > 3 {
                self.currencyCode = String(sanitizedCode.prefix(3))
            } else {
                // Pad with X if too short
                self.currencyCode = sanitizedCode.padding(toLength: 3, withPad: "X", startingAt: 0)
            }
        } else {
            self.currencyCode = sanitizedCode
        }

        self.weeklyChange = weeklyChange
        self.miniChartDataStorage = (try? JSONEncoder().encode(miniChartData)) ?? Data()
    }
}
