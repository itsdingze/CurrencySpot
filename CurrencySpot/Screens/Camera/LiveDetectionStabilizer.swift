import CoreGraphics
import Foundation

struct LiveDetectionStabilizer {
    private struct Track {
        var readings: [DetectedItem]
        var shown: DetectedItem
        var vanishedAt: Int?
    }

    private let windowSize = 5
    private var tracks: [UUID: Track] = [:]
    private var order: [UUID] = []
    private var emission = 0

    var items: [DetectedItem] {
        order.compactMap { tracks[$0]?.shown }
    }

    @discardableResult
    mutating func record(_ detected: [DetectedItem]) -> Int? {
        emission += 1
        var present: Set<UUID> = []
        let frame = detected.filter { present.insert($0.id).inserted }
        let vanished = order.filter { !present.contains($0) && tracks[$0]?.vanishedAt == nil }
        vanished.forEach { tracks[$0]?.vanishedAt = emission }
        frame.forEach { absorb($0) }
        order = frame.map(\.id) + order.filter { !present.contains($0) }
        return vanished.isEmpty ? nil : emission
    }

    mutating func expireLingering(through emission: Int) {
        let expired = Set(tracks.filter { ($0.value.vanishedAt ?? .max) <= emission }.keys)
        expired.forEach { tracks[$0] = nil }
        order.removeAll { expired.contains($0) }
    }

    mutating func transform(by transform: CGAffineTransform) {
        for id in order {
            guard let shown = tracks[id]?.shown else { continue }
            tracks[id]?.shown = shown.applying(transform)
        }
    }

    mutating func reset() {
        tracks = [:]
        order = []
    }

    private mutating func absorb(_ reading: DetectedItem) {
        let readings = Array(((tracks[reading.id]?.readings ?? []) + [reading]).suffix(windowSize))
        let previousIsPrice = tracks[reading.id]?.shown.conversion.isPrice ?? reading.conversion.isPrice
        let steadiest = steadiestReading(in: readings, previousIsPrice: previousIsPrice) ?? reading
        tracks[reading.id] = Track(
            readings: readings,
            shown: steadiest.replacing(
                tokenQuad: reading.tokenQuad,
                lineQuad: reading.lineQuad,
                lineTextQuads: reading.lineTextQuads,
                rowNeighbourCenter: reading.rowNeighbourCenter
            ),
            vanishedAt: nil
        )
    }

    private func steadiestReading(in readings: [DetectedItem], previousIsPrice: Bool) -> DetectedItem? {
        let priceVotes = readings.count { $0.conversion.isPrice }
        let otherVotes = readings.count - priceVotes
        let isPrice = priceVotes == otherVotes ? previousIsPrice : priceVotes > otherVotes
        let candidates = readings.filter { $0.conversion.isPrice == isPrice }
        let amountVotes = Dictionary(grouping: candidates, by: \.conversion.amount).mapValues(\.count)
        let topVotes = amountVotes.values.max() ?? 0
        return candidates.last { amountVotes[$0.conversion.amount] == topVotes }
    }
}

private extension DetectedItem {
    func applying(_ transform: CGAffineTransform) -> DetectedItem {
        let move = { (point: CGPoint) in point.applying(transform) }
        return replacing(
            tokenQuad: tokenQuad.mapped(move),
            lineQuad: lineQuad.mapped(move),
            lineTextQuads: lineTextQuads.map { $0.mapped(move) },
            rowNeighbourCenter: rowNeighbourCenter.map(move)
        )
    }
}
