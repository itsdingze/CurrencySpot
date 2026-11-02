import CoreGraphics

enum PlateHitTargets {
    static func resolve(visible: [CGRect], in frame: CGRect) -> [CGRect] {
        var targets = visible.map { expanded($0).intersection(frame) }
        for first in targets.indices {
            for second in targets.indices where second > first && overlapArea(targets[first], targets[second]) > 0 {
                (targets[first], targets[second]) = trimmed(
                    targets[first], targets[second], visible: visible[first], visible[second]
                )
            }
        }
        return targets
    }

    private static func expanded(_ rect: CGRect) -> CGRect {
        let minimum = ConvertedPlateMetrics.minimumHitTarget
        return rect.insetBy(dx: -max(0, (minimum - rect.width) / 2), dy: -max(0, (minimum - rect.height) / 2))
    }

    private static func overlapArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let shared = first.intersection(second)
        return shared.isNull ? 0 : shared.width * shared.height
    }

    private static func trimmed(_ first: CGRect, _ second: CGRect, visible a: CGRect, _ b: CGRect) -> (CGRect, CGRect) {
        let gapX = max(b.minX - a.maxX, a.minX - b.maxX)
        let gapY = max(b.minY - a.maxY, a.minY - b.maxY)
        if gapX >= gapY {
            let firstIsLeading = a.midX < b.midX
            let middle = firstIsLeading ? (a.maxX + b.minX) / 2 : (b.maxX + a.minX) / 2
            return firstIsLeading
                ? (first.clipped(maxX: middle), second.clipped(minX: middle))
                : (first.clipped(minX: middle), second.clipped(maxX: middle))
        }
        let firstIsAbove = a.midY < b.midY
        let middle = firstIsAbove ? (a.maxY + b.minY) / 2 : (b.maxY + a.minY) / 2
        return firstIsAbove
            ? (first.clipped(maxY: middle), second.clipped(minY: middle))
            : (first.clipped(minY: middle), second.clipped(maxY: middle))
    }
}

private extension CGRect {
    func clipped(minX: CGFloat? = nil, maxX: CGFloat? = nil, minY: CGFloat? = nil, maxY: CGFloat? = nil) -> CGRect {
        let left = max(self.minX, minX ?? self.minX)
        let right = max(left, min(self.maxX, maxX ?? self.maxX))
        let top = max(self.minY, minY ?? self.minY)
        let bottom = max(top, min(self.maxY, maxY ?? self.maxY))
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
