import CoreGraphics

nonisolated enum RowSlope {
    private static let sameRowShareOfHeight: CGFloat = 0.8
    private static let maximumReachInHeights: CGFloat = 16
    private static let touchingShareOfHeight: CGFloat = 0.5
    private static let wideLineAspect: CGFloat = 4

    static func neighbourCenter(leftOf line: Quad, among lines: [Quad]) -> CGPoint? {
        lines
            .filter { isLeftNeighbour($0, of: line) }
            .max { $0.boundingBox.maxX < $1.boundingBox.maxX }?
            .center
    }

    private static func isLeftNeighbour(_ other: Quad, of line: Quad) -> Bool {
        let height = line.height
        let endsBeforeLine = other.boundingBox.maxX <= line.boundingBox.minX + touchingShareOfHeight * height
        let sharesRow = abs(other.center.y - line.center.y) <= sameRowShareOfHeight * height
        let isWithinReach = line.center.x - other.center.x <= maximumReachInHeights * height
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
