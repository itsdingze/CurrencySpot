//
//  TrendDirection.swift
//  CurrencySpot
//

import SwiftUI

enum TrendDirection: Sendable {
    case up
    case down
    case stable

    /// Threshold for determining stable vs trending (±0.1%)
    static let stableChangeThreshold: Double = 0.1

    init(percentChange: Double) {
        if abs(percentChange) <= Self.stableChangeThreshold {
            self = .stable
        } else if percentChange > 0 {
            self = .up
        } else {
            self = .down
        }
    }

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
