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

    var displayName: LocalizedStringResource {
        switch self {
        case .veryLow: .volatilityLevelVeryLowName
        case .low: .volatilityLevelLowName
        case .moderate: .volatilityLevelModerateName
        case .high: .volatilityLevelHighName
        case .veryHigh: .volatilityLevelVeryHighName
        }
    }

    var rangeDescription: LocalizedStringResource {
        switch self {
        case .veryLow: .volatilityLevelRangeBelow(limit: 5.formatted(.percent))
        case .low: .volatilityLevelRangeBetween(lower: 5, upper: 10.formatted(.percent))
        case .moderate: .volatilityLevelRangeBetween(lower: 10, upper: 15.formatted(.percent))
        case .high: .volatilityLevelRangeBetween(lower: 15, upper: 25.formatted(.percent))
        case .veryHigh: .volatilityLevelRangeAbove(limit: 25.formatted(.percent))
        }
    }
}
