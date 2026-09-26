import CoreGraphics

nonisolated struct FingerDemoFrame {
    var progress: Double
    var opacity: Double
    var touch: Double

    private static let hoverScale = 1.1
    private static let pressedScale = 0.95

    var isTouching: Bool { touch >= 0.5 }

    var scale: Double {
        Self.hoverScale + (Self.pressedScale - Self.hoverScale) * touch
    }

    func selectedIndex(pointCount: Int) -> Int? {
        guard isTouching, pointCount > 0 else { return nil }
        return min(max(Int(progress.rounded()), 0), pointCount - 1)
    }

    func fingertip(alongX positions: [CGFloat], atHeight height: CGFloat) -> CGPoint? {
        guard !positions.isEmpty else { return nil }
        let clamped = min(max(progress, 0), Double(positions.count - 1))
        let lowerIndex = Int(clamped.rounded(.down))
        let lower = positions[lowerIndex]
        let upper = positions[min(lowerIndex + 1, positions.count - 1)]
        let fraction = clamped - Double(lowerIndex)
        return CGPoint(x: lower + (upper - lower) * fraction, y: height)
    }
}
