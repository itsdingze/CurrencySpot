import SwiftUI

extension TrendDirection {
    var color: Color {
        switch self {
        case .up: .success
        case .down: .failure
        case .stable: .warning
        }
    }
}

extension VolatilityLevel {
    var color: Color {
        switch self {
        case .veryLow: .success
        case .low: .volatilityLow
        case .moderate: .yellow
        case .high: .warning
        case .veryHigh: .failure
        }
    }
}

private nonisolated extension Color {
    static let volatilityLow = Color(red: 143 / 255, green: 197 / 255, blue: 112 / 255)
}
