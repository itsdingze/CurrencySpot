import CoreGraphics
@testable import CurrencySpot

nonisolated extension Quad {
    func contains(_ point: CGPoint) -> Bool {
        let corners = self.corners
        var sign: CGFloat = 0
        for index in corners.indices {
            let a = corners[index]
            let b = corners[(index + 1) % corners.count]
            let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if cross == 0 { continue }
            if sign == 0 { sign = cross } else if (sign > 0) != (cross > 0) { return false }
        }
        return true
    }
}
