import CoreGraphics

nonisolated struct PageAxes: Equatable {
    let angle: CGFloat

    private var u: CGPoint { CGPoint(x: cos(angle), y: sin(angle)) }
    private var v: CGPoint { CGPoint(x: -sin(angle), y: cos(angle)) }

    func span(of quad: Quad) -> PageRect {
        let us = quad.corners.map { $0.x * u.x + $0.y * u.y }
        let vs = quad.corners.map { $0.x * v.x + $0.y * v.y }
        return PageRect(u0: us.min() ?? 0, u1: us.max() ?? 0, v0: vs.min() ?? 0, v1: vs.max() ?? 0)
    }

    func quad(of rect: PageRect) -> Quad {
        Quad(
            topLeft: point(u: rect.u0, v: rect.v0),
            topRight: point(u: rect.u1, v: rect.v0),
            bottomRight: point(u: rect.u1, v: rect.v1),
            bottomLeft: point(u: rect.u0, v: rect.v1)
        )
    }

    func shift(of offset: CGPoint) -> (u: CGFloat, v: CGFloat) {
        (offset.x * u.x + offset.y * u.y, offset.x * v.x + offset.y * v.y)
    }

    private func point(u along: CGFloat, v across: CGFloat) -> CGPoint {
        CGPoint(x: u.x * along + v.x * across, y: u.y * along + v.y * across)
    }
}

nonisolated struct PageRect: Equatable {
    let u0: CGFloat
    let u1: CGFloat
    let v0: CGFloat
    let v1: CGFloat

    var width: CGFloat { u1 - u0 }
    var height: CGFloat { v1 - v0 }
    var midU: CGFloat { (u0 + u1) / 2 }
    var midV: CGFloat { (v0 + v1) / 2 }

    func grown(along: CGFloat, across: CGFloat) -> PageRect {
        PageRect(u0: u0 - along, u1: u1 + along, v0: v0 - across, v1: v1 + across)
    }

    func shifted(u du: CGFloat, v dv: CGFloat) -> PageRect {
        PageRect(u0: u0 + du, u1: u1 + du, v0: v0 + dv, v1: v1 + dv)
    }

    func sharesColumn(with other: PageRect) -> Bool {
        min(u1, other.u1) - max(u0, other.u0) > 0.01
    }

    func sharesRow(with other: PageRect) -> Bool {
        min(v1, other.v1) - max(v0, other.v0) > 0.5 * min(height, other.height)
    }

    func overlap(with other: PageRect) -> (area: CGFloat, depth: CGFloat) {
        let width = min(u1, other.u1) - max(u0, other.u0)
        let height = min(v1, other.v1) - max(v0, other.v0)
        guard width > 0, height > 0 else { return (0, 0) }
        return (width * height, width)
    }
}
