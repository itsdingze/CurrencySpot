import CoreGraphics

nonisolated struct Quad: Hashable, Sendable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint

    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    init(_ rect: CGRect) {
        self.init(
            topLeft: CGPoint(x: rect.minX, y: rect.minY),
            topRight: CGPoint(x: rect.maxX, y: rect.minY),
            bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
            bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        )
    }

    var corners: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }

    var boundingBox: CGRect {
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        return CGRect(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
    }

    var center: CGPoint {
        CGPoint(
            x: (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4,
            y: (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4
        )
    }

    private var leadingMidpoint: CGPoint {
        topLeft.midpoint(to: bottomLeft)
    }

    private var trailingMidpoint: CGPoint {
        topRight.midpoint(to: bottomRight)
    }

    var width: CGFloat {
        (topLeft.distance(to: topRight) + bottomLeft.distance(to: bottomRight)) / 2
    }

    var height: CGFloat {
        (topLeft.distance(to: bottomLeft) + topRight.distance(to: bottomRight)) / 2
    }

    var angle: CGFloat {
        let axis = trailingMidpoint - leadingMidpoint
        return atan2(axis.y, axis.x)
    }

    private func fractionAlongBaseline(of point: CGPoint) -> CGFloat {
        let axis = trailingMidpoint - leadingMidpoint
        let lengthSquared = axis.x * axis.x + axis.y * axis.y
        guard lengthSquared > 0 else { return 0 }
        let offset = point - leadingMidpoint
        return (offset.x * axis.x + offset.y * axis.y) / lengthSquared
    }

    func baselineSpan(of other: Quad) -> ClosedRange<CGFloat> {
        let start = fractionAlongBaseline(of: other.leadingMidpoint)
        let end = fractionAlongBaseline(of: other.trailingMidpoint)
        return min(start, end)...max(start, end)
    }

    func slice(_ span: ClosedRange<CGFloat>) -> Quad {
        Quad(
            topLeft: topLeft.interpolated(to: topRight, by: span.lowerBound),
            topRight: topLeft.interpolated(to: topRight, by: span.upperBound),
            bottomRight: bottomLeft.interpolated(to: bottomRight, by: span.upperBound),
            bottomLeft: bottomLeft.interpolated(to: bottomRight, by: span.lowerBound)
        )
    }

    func mapped(_ transform: (CGPoint) -> CGPoint) -> Quad {
        Quad(
            topLeft: transform(topLeft),
            topRight: transform(topRight),
            bottomRight: transform(bottomRight),
            bottomLeft: transform(bottomLeft)
        )
    }
}

nonisolated extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    fileprivate func distance(to other: CGPoint) -> CGFloat {
        hypot(other.x - x, other.y - y)
    }

    fileprivate func midpoint(to other: CGPoint) -> CGPoint {
        interpolated(to: other, by: 0.5)
    }

    func interpolated(to other: CGPoint, by fraction: CGFloat) -> CGPoint {
        CGPoint(x: x + (other.x - x) * fraction, y: y + (other.y - y) * fraction)
    }
}
