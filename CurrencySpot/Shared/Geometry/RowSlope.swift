import CoreGraphics

nonisolated enum RowSlope {
    private static let sameRowShareOfHeight: CGFloat = 0.8
    private static let maximumReachInHeights: CGFloat = 16
    private static let touchingShareOfHeight: CGFloat = 0.5
    private static let wideLineAspect: CGFloat = 4

    static func page(of lines: [Quad]) -> PageAxes {
        PageAxes(angle: lines.map(\.angle).median)
    }

    static func neighbourCenter(leftOf line: Quad, among lines: [Quad], on page: PageAxes) -> CGPoint? {
        let span = page.span(of: line)
        return lines
            .map { (quad: $0, span: page.span(of: $0)) }
            .filter { isLeftNeighbour($0.span, of: span, height: line.height) }
            .max { $0.span.u1 < $1.span.u1 }?
            .quad.center
    }

    private static func isLeftNeighbour(_ other: PageRect, of line: PageRect, height: CGFloat) -> Bool {
        let endsBeforeLine = other.u1 <= line.u0 + touchingShareOfHeight * height
        let sharesRow = abs(other.midV - line.midV) <= sameRowShareOfHeight * height
        let isWithinReach = line.midU - other.midU <= maximumReachInHeights * height
        return endsBeforeLine && sharesRow && isWithinReach
    }

    static func sample(of line: Quad, rowNeighbourCenter neighbour: CGPoint?) -> CGFloat? {
        if let neighbour {
            let offset = line.center - neighbour
            return atan2(offset.y, offset.x)
        }
        return line.width >= wideLineAspect * line.height ? line.angle : nil
    }
}
