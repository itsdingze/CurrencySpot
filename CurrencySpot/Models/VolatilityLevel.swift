//
//  VolatilityLevel.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/26/25.
//

import SwiftUI

/// Qualitative bucket for annualized volatility (percent), driving display text and color.
/// Computing the level from the raw value avoids matching against already-formatted strings.
enum VolatilityLevel: CaseIterable, Sendable {
    case veryLow, low, moderate, high, veryHigh

    /// Classifies an annualized volatility percentage into a level.
    init(annualizedPercent: Double) {
        switch annualizedPercent {
        case ..<5: self = .veryLow
        case 5 ..< 10: self = .low
        case 10 ..< 15: self = .moderate
        case 15 ..< 25: self = .high
        default: self = .veryHigh
        }
    }

    var displayName: String {
        switch self {
        case .veryLow: "Very Low"
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        case .veryHigh: "Very High"
        }
    }

    /// Variation-range description used in the explanatory legend.
    var rangeDescription: String {
        switch self {
        case .veryLow: "< 5% variation"
        case .low: "5-10% variation"
        case .moderate: "10-15% variation"
        case .high: "15-25% variation"
        case .veryHigh: "> 25% variation"
        }
    }

    var color: Color {
        switch self {
        case .veryLow: .green
        case .low: .volatilityLow
        case .moderate: .yellow
        case .high: .orange
        case .veryHigh: .red
        }
    }
}

private extension Color {
    /// Muted green for the "Low" volatility band.
    static let volatilityLow = Color(red: 143 / 255, green: 197 / 255, blue: 112 / 255)
}
