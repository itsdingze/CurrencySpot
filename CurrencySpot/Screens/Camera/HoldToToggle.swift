import CoreGraphics
import Foundation

nonisolated struct HoldToToggle: Equatable {
    enum Phase: Equatable {
        case idle
        case holding
        case armed
        case cancelled
    }

    static let holdDuration: TimeInterval = 0.5

    private(set) var phase = Phase.idle

    var isHeld: Bool {
        phase == .holding || phase == .armed
    }

    mutating func touch(at point: CGPoint, in bounds: CGRect) {
        if phase == .idle { phase = .holding }
        if !Self.isInsideRound(point, filling: bounds) {
            phase = .cancelled
        }
    }

    private static func isInsideRound(_ point: CGPoint, filling bounds: CGRect) -> Bool {
        guard bounds.width > 0, bounds.height > 0 else { return false }
        let x = (point.x - bounds.midX) / (bounds.width / 2)
        let y = (point.y - bounds.midY) / (bounds.height / 2)
        return x * x + y * y <= 1
    }

    mutating func holdElapsed() -> Bool {
        guard phase == .holding else { return false }
        phase = .armed
        return true
    }

    mutating func release() -> Bool {
        defer { phase = .idle }
        return phase == .armed
    }
}
