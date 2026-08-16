import Foundation

nonisolated enum VolatilityLevel: CaseIterable, Sendable {
    case veryLow, low, moderate, high, veryHigh

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

    var rangeDescription: String {
        switch self {
        case .veryLow: "< 5% variation"
        case .low: "5-10% variation"
        case .moderate: "10-15% variation"
        case .high: "15-25% variation"
        case .veryHigh: "> 25% variation"
        }
    }

}
