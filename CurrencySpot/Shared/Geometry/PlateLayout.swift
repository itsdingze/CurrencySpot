import CoreGraphics
import Foundation

struct PlateLayout {
    nonisolated struct Plate: Equatable, Sendable {
        let id: UUID
        let text: String
        let fontSize: CGFloat
        let alignment: PlateLayoutMemory.Alignment
        let quad: Quad
        let size: CGSize
        let cornerRadius: CGFloat

        var center: CGPoint { quad.center }
        var visibleBounds: CGRect { quad.boundingBox }
    }

    nonisolated struct Outline: Equatable, Sendable {
        let id: UUID
        let quad: Quad
        let size: CGSize
        let cornerRadius: CGFloat

        var center: CGPoint { quad.center }
        var visibleBounds: CGRect { quad.boundingBox.insetBy(dx: -Self.strokeOutset, dy: -Self.strokeOutset) }

        private static let strokeOutset: CGFloat = 1.75
    }

    nonisolated struct Result: Equatable, Sendable {
        let angle: CGFloat
        let plates: [Plate]
        let outlines: [Outline]

        static let empty = Result(angle: 0, plates: [], outlines: [])
    }

    private struct Anchor {
        let item: DetectedItem
        let text: String
        let token: PageRect
        init(item: DetectedItem, text: String, token: PageRect, lockedSize: CGSize) {
            self.item = item
            self.text = text
            self.token = PageRect(
                u0: token.midU - lockedSize.width / 2,
                u1: token.midU + lockedSize.width / 2,
                v0: token.midV - lockedSize.height / 2,
                v1: token.midV + lockedSize.height / 2
            )
        }

        var textHeight: CGFloat { token.height }
    }

    private struct Sized {
        let anchor: Anchor
        let fontSize: CGFloat
        let contentWidth: CGFloat
        var width: CGFloat
        let coveredHeight: CGFloat
        let baseHeight: CGFloat
        var alignment = PlateLayoutMemory.Alignment.centered
        var u0: CGFloat = 0

        var token: PageRect { anchor.token }
        var id: UUID { anchor.item.id }
        var span: PageRect { PageRect(u0: u0, u1: u0 + width, v0: token.midV - baseHeight / 2, v1: token.midV + baseHeight / 2) }

        func positioned(_ alignment: PlateLayoutMemory.Alignment, within room: ClosedRange<CGFloat>) -> Sized {
            var copy = self
            copy.alignment = alignment
            copy.u0 = switch alignment {
            case .centered: token.midU - width / 2
            case .leading: max(token.u0 - ConvertedPlateMetrics.tokenOverhang, room.lowerBound)
            case .trailing: min(token.u1 + ConvertedPlateMetrics.tokenOverhang, room.upperBound) - width
            }
            return copy
        }

        func centered(within room: ClosedRange<CGFloat>) -> Sized {
            var copy = positioned(.centered, within: room)
            let roomWidth = room.upperBound - room.lowerBound
            if copy.width > roomWidth {
                copy.width = max(contentWidth, roomWidth.rounded(.down))
                copy.u0 = (room.lowerBound + room.upperBound) / 2 - copy.width / 2
            } else {
                copy.u0 = min(max(copy.u0, room.lowerBound), room.upperBound - copy.width)
            }
            return copy
        }

        func resized(to newWidth: CGFloat) -> Sized {
            var copy = self
            copy.width = newWidth
            copy.u0 = switch alignment {
            case .leading: u0
            case .trailing: u0 + width - newWidth
            case .centered: u0 + (width - newWidth) / 2
            }
            return copy
        }

        func room(among obstacles: [PageRect]) -> ClosedRange<CGFloat> {
            let row = obstacles.filter { min($0.v1, span.v1) > max($0.v0, span.v0) }
            let leading = row.filter { $0.midU < token.midU }.map { min($0.u1, token.u0) }.max() ?? -.infinity
            let trailing = row.filter { $0.midU >= token.midU }.map { max($0.u0, token.u1) }.min() ?? .infinity
            return leading...trailing
        }
    }

    private static let pageAngleSnap: CGFloat = 1.5 * .pi / 180
    private static let duplicateOverlap: CGFloat = 0.5
    private static let frameInset: CGFloat = 2
    private static let plateGap: CGFloat = 1
    private static let columnMargin: CGFloat = 2

    let frame: CGRect
    let measureText: (String, CGFloat) -> CGFloat

    func layout(
        _ items: [DetectedItem],
        text: (DetectedItem) -> String,
        memory: inout PlateLayoutMemory
    ) -> Result {
        let prices = Self.withoutDuplicates(items.filter(\.conversion.isPrice))
        let axes = PageAxes(angle: memory.pageAngle(measured: Self.medianLineAngle(of: prices), snappingBelow: Self.pageAngleSnap))
        let anchors = prices.map { price in
            let token = Self.token(price.tokenQuad, on: axes)
            return Anchor(
                item: price,
                text: text(price),
                token: token,
                lockedSize: memory.tokenSize(for: price.id, measured: CGSize(width: token.width, height: token.height))
            )
        }
        let outlines = items.filter { !$0.conversion.isPrice }.map { outline($0, axes: axes) }

        var sized = anchors.map { size($0, among: anchors, memory: &memory) }
        align(&sized, axes: axes, outlines: outlines, memory: &memory)
        let plates = sized.map { item in
            plate(
                item,
                height: height(of: item, among: sized, outlines: outlines, memory: &memory),
                axes: axes,
                roundsOrigin: memory.tracksFrames
            )
        }
        memory.forget(allBut: Set(plates.map(\.id)))
        return Result(angle: axes.angle, plates: plates, outlines: outlines.map(\.placed))
    }

    private static func token(_ quad: Quad, on axes: PageAxes) -> PageRect {
        let span = axes.span(of: quad)
        let width = min(span.width, quad.width)
        let height = min(span.height, quad.height)
        return PageRect(u0: span.midU - width / 2, u1: span.midU + width / 2, v0: span.midV - height / 2, v1: span.midV + height / 2)
    }

    private static func withoutDuplicates(_ prices: [DetectedItem]) -> [DetectedItem] {
        prices.reduce(into: []) { kept, price in
            let isDuplicate = kept.contains { other in
                other.conversion.amount == price.conversion.amount
                    && other.bounds.intersectionOverUnion(with: price.bounds) > duplicateOverlap
            }
            if !isDuplicate { kept.append(price) }
        }
    }

    private static func medianLineAngle(of prices: [DetectedItem]) -> CGFloat {
        var seen: Set<UUID> = []
        let lines = prices.filter { seen.insert($0.lineID).inserted }
        let rowSlopes = lines.compactMap { RowSlope.sample(of: $0.lineQuad, rowNeighbourCenter: $0.rowNeighbourCenter) }
        return (rowSlopes.isEmpty ? lines.map(\.lineQuad.angle) : rowSlopes).median
    }

    private func size(_ anchor: Anchor, among anchors: [Anchor], memory: inout PlateLayoutMemory) -> Sized {
        let peers = anchors.map(\.textHeight).filter {
            $0 >= anchor.textHeight / ConvertedPlateMetrics.fontPeerRatio
                && $0 <= anchor.textHeight * ConvertedPlateMetrics.fontPeerRatio
        }
        let fontSize = memory.fontSize(for: anchor.item.id, textHeight: peers.median)
        let padding = ConvertedPlateMetrics.horizontalPadding(forFontSize: fontSize)
        let content = (measureText(anchor.text, fontSize) + 2 * padding).rounded(.up)
        let required = max((anchor.token.width + 2 * ConvertedPlateMetrics.tokenOverhang).rounded(.up), content)
        let coveredHeight = (anchor.token.height + 2).rounded(.up)
        return Sized(
            anchor: anchor,
            fontSize: fontSize,
            contentWidth: content,
            width: required,
            coveredHeight: coveredHeight,
            baseHeight: max(ConvertedPlateMetrics.baseHeight(forFontSize: fontSize), coveredHeight)
        )
    }

    private func align(_ items: inout [Sized], axes: PageAxes, outlines: [PlacedOutline], memory: inout PlateLayoutMemory) {
        var placed: [PageRect] = []
        for index in Self.readingOrder(of: items) {
            let item = items[index]
            let obstacles = alignmentObstacles(for: item, among: items, outlines: outlines, placed: placed, axes: axes)
            let room = item.room(among: obstacles)
            let fitsToken = item.width <= (item.token.width + 2 * ConvertedPlateMetrics.tokenOverhang).rounded(.up)
            let intrusion = { (alignment: PlateLayoutMemory.Alignment) in
                measureIntrusion(of: item.positioned(alignment, within: room).span, by: obstacles, axes: axes)
            }
            let alignment = memory.alignment(
                for: item.id,
                choosing: {
                    guard !fitsToken else { return .centered }
                    let scored = [PlateLayoutMemory.Alignment.leading, .trailing, .centered].map { ($0, intrusion($0).area) }
                    return (scored.first { $0.1 <= 0.01 } ?? scored.min { $0.1 < $1.1 })?.0 ?? .centered
                },
                intrusionDepth: { intrusion($0).depth }
            )
            let aligned = fitsToken && alignment == .centered
                ? item.centered(within: room)
                : item.positioned(alignment, within: room)
            let isRoomBound = fitsToken && alignment == .centered
            let width = memory.width(
                for: item.id,
                required: aligned.width,
                limit: isRoomBound ? room.upperBound - room.lowerBound : .infinity,
                floor: item.contentWidth
            )
            items[index] = isRoomBound ? aligned.resized(to: width).centered(within: room) : aligned.resized(to: width)
            placed.append(items[index].span)
        }
    }

    private static func readingOrder(of items: [Sized]) -> [Int] {
        let sorted = items.indices.sorted { items[$0].token.midV < items[$1].token.midV }
        var rows: [[Int]] = []
        for index in sorted {
            if let first = rows.last?.first, items[index].token.midV - items[first].token.midV <= items[first].token.height / 2 {
                rows[rows.count - 1].append(index)
            } else {
                rows.append([index])
            }
        }
        return rows.flatMap { row in row.sorted { items[$0].token.u0 < items[$1].token.u0 } }
    }

    private func alignmentObstacles(
        for item: Sized,
        among items: [Sized],
        outlines: [PlacedOutline],
        placed: [PageRect],
        axes: PageAxes
    ) -> [PageRect] {
        let lineID = item.anchor.item.lineID
        let text = item.anchor.item.lineTextQuads.map(axes.span)
        let tokens = items.filter { $0.anchor.item.lineID == lineID && $0.id != item.id }.map(\.token)
        let lineOutlines = outlines.filter { $0.lineID == lineID }.map(\.shape)
        let plates = placed.filter { $0.sharesRow(with: item.span) }.map { $0.grown(along: Self.plateGap, across: 0) }
        return text + tokens + lineOutlines + plates
    }

    private func measureIntrusion(of rect: PageRect, by obstacles: [PageRect], axes: PageAxes) -> (area: CGFloat, depth: CGFloat) {
        var area: CGFloat = 0
        var depth: CGFloat = 0
        for obstacle in obstacles {
            let overlap = rect.overlap(with: obstacle)
            area += overlap.area
            depth = max(depth, overlap.depth)
        }
        let box = axes.quad(of: rect).boundingBox
        let inside = box.intersection(frame.insetBy(dx: Self.frameInset, dy: Self.frameInset))
        let outsideArea = box.width * box.height - (inside.isNull ? 0 : inside.width * inside.height)
        if outsideArea > 0.01 {
            area += outsideArea
            depth = max(depth, box.width - (inside.isNull ? 0 : inside.width))
        }
        return (area, depth)
    }

    private func height(of item: Sized, among items: [Sized], outlines: [PlacedOutline], memory: inout PlateLayoutMemory) -> CGFloat {
        let span = item.span.grown(along: memory.tracksFrames ? Self.columnMargin : 0, across: 0)
        let priceLimits = items
            .filter { $0.id != item.id && span.sharesColumn(with: $0.span) && !$0.token.sharesRow(with: item.token) }
            .map { abs($0.token.midV - item.token.midV) }
        let outlineLimits = outlines
            .filter { span.sharesColumn(with: $0.shape) && !$0.shape.sharesRow(with: item.token) }
            .map { 2 * (abs($0.shape.midV - item.token.midV) - $0.shape.height / 2) }
        let limit = (priceLimits + outlineLimits).min() ?? .infinity
        let clearance = limit - Self.plateGap
        let fontFloor = ConvertedPlateMetrics.minimumHeight(forFontSize: item.fontSize)
        let floor = max(item.coveredHeight, fontFloor)
        let required = max(floor, min(clearance.rounded(.down), item.baseHeight))
        let holdFloor = memory.tracksFrames ? max(item.token.height.rounded(.up), fontFloor) : floor
        return memory.height(for: item.id, required: required, limit: clearance, floor: holdFloor)
    }

    private func plate(_ item: Sized, height: CGFloat, axes: PageAxes, roundsOrigin: Bool) -> Plate {
        let rect = PageRect(u0: item.u0, u1: item.u0 + item.width, v0: item.token.midV - height / 2, v1: item.token.midV + height / 2)
        let box = axes.quad(of: rect).boundingBox
        let dx = max(0, frame.minX - box.minX) - max(0, box.maxX - frame.maxX)
        let dy = max(0, frame.minY - box.minY) - max(0, box.maxY - frame.maxY)
        let shift = axes.shift(of: CGPoint(x: dx, y: dy))
        let shifted = rect.shifted(u: shift.u, v: shift.v)
        let rounded = roundsOrigin
            ? shifted.shifted(u: shifted.u0.rounded() - shifted.u0, v: shifted.v0.rounded() - shifted.v0)
            : shifted
        return Plate(
            id: item.id,
            text: item.anchor.text,
            fontSize: item.fontSize,
            alignment: item.alignment,
            quad: axes.quad(of: rounded),
            size: CGSize(width: item.width, height: height),
            cornerRadius: ConvertedPlateMetrics.cornerRadius(forHeight: height)
        )
    }

    private func outline(_ item: DetectedItem, axes: PageAxes) -> PlacedOutline {
        let token = axes.span(of: item.tokenQuad)
        let shape = token.grown(
            along: ConvertedPlateMetrics.outlineGrowthAlong,
            across: ConvertedPlateMetrics.outlineGrowthAcross(forTokenHeight: token.height)
        )
        return PlacedOutline(id: item.id, lineID: item.lineID, shape: shape, axes: axes)
    }
}

private struct PlacedOutline {
    let id: UUID
    let lineID: UUID
    let shape: PageRect
    let axes: PageAxes

    var placed: PlateLayout.Outline {
        PlateLayout.Outline(
            id: id,
            quad: axes.quad(of: shape),
            size: CGSize(width: shape.width, height: shape.height),
            cornerRadius: ConvertedPlateMetrics.cornerRadius(forHeight: shape.height)
        )
    }
}

private extension CGRect {
    func intersectionOverUnion(with other: CGRect) -> CGFloat {
        let shared = intersection(other)
        guard !shared.isNull else { return 0 }
        let sharedArea = shared.width * shared.height
        let union = width * height + other.width * other.height - sharedArea
        return union > 0 ? sharedArea / union : 0
    }
}
