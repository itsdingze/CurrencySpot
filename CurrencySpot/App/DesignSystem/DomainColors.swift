import SwiftUI
import UIKit

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

private nonisolated extension ShapeStyle where Self == Color {
    static var volatilityLow: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 141 / 255, green: 207 / 255, blue: 116 / 255, alpha: 1)
                : UIColor(red: 143 / 255, green: 197 / 255, blue: 112 / 255, alpha: 1)
        })
    }
}
