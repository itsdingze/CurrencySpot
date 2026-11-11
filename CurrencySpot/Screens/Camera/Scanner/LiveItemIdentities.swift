import CoreGraphics
import Foundation

nonisolated struct LiveItemIdentities {
    private struct Track {
        let id: UUID
        var center: CGPoint
        var height: CGFloat
        var transcript: String
        var missedFrames = 0
    }

    private static let reachInHeights: CGFloat = 1
    private static let motionReachInHeights: CGFloat = 5
    private static let differentTextPenaltyInHeights: CGFloat = 0.25
    private static let framesKeptAfterMissing = 5

    private var tracks: [Track] = []

    mutating func transform(by transform: CGAffineTransform) {
        let scale = hypot(transform.a, transform.b)
        for index in tracks.indices {
            tracks[index].center = tracks[index].center.applying(transform)
            tracks[index].height *= scale
        }
    }

    mutating func identify(_ items: [RecognizedTextItem]) -> [RecognizedTextItem] {
        var ids = [UUID?](repeating: nil, count: items.count)
        var claimed: Set<Int> = []
        for (itemIndex, trackIndex) in Self.matches(of: items, to: tracks) {
            ids[itemIndex] = tracks[trackIndex].id
            claimed.insert(trackIndex)
            tracks[trackIndex] = Track(
                id: tracks[trackIndex].id,
                center: items[itemIndex].quad.center,
                height: items[itemIndex].quad.height,
                transcript: items[itemIndex].transcript
            )
        }
        for trackIndex in tracks.indices where !claimed.contains(trackIndex) {
            tracks[trackIndex].missedFrames += 1
        }
        tracks.removeAll { $0.missedFrames > Self.framesKeptAfterMissing }
        return items.enumerated().map { index, item in
            let id = ids[index] ?? startTrack(for: item)
            return RecognizedTextItem(
                id: id,
                transcript: item.transcript,
                quad: item.quad,
                characterSpans: item.characterSpans,
                inkGaps: item.inkGaps,
                alternateTranscripts: item.alternateTranscripts
            )
        }
    }

    private mutating func startTrack(for item: RecognizedTextItem) -> UUID {
        let track = Track(id: UUID(), center: item.quad.center, height: item.quad.height, transcript: item.transcript)
        tracks.append(track)
        return track.id
    }

    private static func sharedMotion(of items: [RecognizedTextItem], from tracks: [Track]) -> CGPoint {
        let offsets = items.compactMap { item -> CGPoint? in
            guard items.count(where: { $0.transcript == item.transcript }) == 1 else { return nil }
            let sameText = tracks.filter { $0.transcript == item.transcript }
            guard sameText.count == 1, let track = sameText.first else { return nil }
            let offset = item.quad.center - track.center
            let reach = motionReachInHeights * max(item.quad.height, track.height)
            return hypot(offset.x, offset.y) <= reach ? offset : nil
        }
        return CGPoint(x: offsets.map(\.x).median, y: offsets.map(\.y).median)
    }

    private static func matches(of items: [RecognizedTextItem], to tracks: [Track]) -> [(Int, Int)] {
        let motion = sharedMotion(of: items, from: tracks)
        var pairs: [(cost: CGFloat, item: Int, track: Int)] = []
        for (itemIndex, item) in items.enumerated() {
            for (trackIndex, track) in tracks.enumerated() {
                let scale = max(item.quad.height, track.height)
                let center = item.quad.center - motion
                let distance = hypot(center.x - track.center.x, center.y - track.center.y)
                guard distance <= reachInHeights * scale else { continue }
                let penalty = item.transcript == track.transcript ? 0 : differentTextPenaltyInHeights * scale
                pairs.append((distance + penalty, itemIndex, trackIndex))
            }
        }
        var usedItems: Set<Int> = []
        var usedTracks: Set<Int> = []
        var matched: [(Int, Int)] = []
        for pair in pairs.sorted(by: { $0.cost < $1.cost })
            where !usedItems.contains(pair.item) && !usedTracks.contains(pair.track) {
            usedItems.insert(pair.item)
            usedTracks.insert(pair.track)
            matched.append((pair.item, pair.track))
        }
        return matched
    }
}
