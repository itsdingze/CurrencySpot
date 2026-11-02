import CoreGraphics

nonisolated extension Array where Element == CGFloat {
    var median: CGFloat {
        let sorted = sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted.count.isMultiple(of: 2)
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]
    }
}
