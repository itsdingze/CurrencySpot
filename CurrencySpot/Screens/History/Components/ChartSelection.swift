import Foundation
import SwiftUI

nonisolated struct ChartSelection: Equatable {
    var date: Date?
    private(set) var accessibilityIndex: Int?

    var isActive: Bool { date != nil }

    mutating func step(_ direction: AccessibilityAdjustmentDirection, through points: [ChartDataPoint]) {
        guard !points.isEmpty else { return }

        let current = accessibilityIndex ?? points.count - 1
        let next: Int
        switch direction {
        case .increment:
            next = min(current + 1, points.count - 1)
        case .decrement:
            next = max(current - 1, 0)
        @unknown default:
            next = current
        }

        accessibilityIndex = next
        date = points[next].date
    }

    mutating func endAccessibilitySelection() {
        guard accessibilityIndex != nil else { return }
        clear()
    }

    mutating func clear() {
        date = nil
        accessibilityIndex = nil
    }
}
