import CoreGraphics

nonisolated enum LineInkGaps {
    private static let sampledRows = 9
    private static let sampledHeightShare: CGFloat = 0.7
    private static let backgroundPercentile = 0.85
    private static let inkShareOfBackground = 0.6

    static func gaps(along line: Quad, in image: GrayscaleImage) -> [ClosedRange<CGFloat>] {
        let columns = max(1, Int(line.width.rounded()))
        let darkest = (0 ..< columns).map { column in
            darkestValue(at: (CGFloat(column) + 0.5) / CGFloat(columns), across: line, in: image)
        }
        let sorted = darkest.sorted()
        let background = Double(sorted[min(sorted.count - 1, Int(Double(sorted.count) * backgroundPercentile))])
        let isInk = darkest.map { Double($0) < background * inkShareOfBackground }
        guard isInk.contains(true), isInk.contains(false) else { return [] }
        return blankRuns(in: isInk).map { run in
            CGFloat(run.lowerBound) / CGFloat(columns)...CGFloat(run.upperBound) / CGFloat(columns)
        }
    }

    private static func darkestValue(at fraction: CGFloat, across line: Quad, in image: GrayscaleImage) -> UInt8 {
        let top = line.topLeft.interpolated(to: line.topRight, by: fraction)
        let bottom = line.bottomLeft.interpolated(to: line.bottomRight, by: fraction)
        let margin = (1 - sampledHeightShare) / 2
        return (0 ..< sampledRows).compactMap { row in
            let share = margin + sampledHeightShare * CGFloat(row) / CGFloat(sampledRows - 1)
            return image.luminance(at: top.interpolated(to: bottom, by: share))
        }.min() ?? .max
    }

    private static func blankRuns(in isInk: [Bool]) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var start: Int?
        for (index, ink) in isInk.enumerated() {
            if !ink, start == nil { start = index }
            if ink, let runStart = start {
                runs.append(runStart ..< index)
                start = nil
            }
        }
        if let start { runs.append(start ..< isInk.count) }
        return runs
    }
}
