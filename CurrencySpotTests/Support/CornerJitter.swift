import CoreGraphics
import Foundation
@testable import CurrencySpot

struct CornerJitter {
    private static let amplitude: CGFloat = 2

    private var generator: SplitMix64

    init(seed: UInt64) {
        generator = SplitMix64(seed: seed)
    }

    mutating func jittered(_ item: DetectedItem) -> DetectedItem {
        let token = jittered(item.tokenQuad)
        let line = jittered(item.lineQuad)
        let text = item.lineTextQuads.map { jittered($0) }
        let neighbour = item.rowNeighbourCenter.map { offset($0) }
        return item.replacing(tokenQuad: token, lineQuad: line, lineTextQuads: text, rowNeighbourCenter: neighbour)
    }

    private mutating func jittered(_ quad: Quad) -> Quad {
        Quad(
            topLeft: offset(quad.topLeft),
            topRight: offset(quad.topRight),
            bottomRight: offset(quad.bottomRight),
            bottomLeft: offset(quad.bottomLeft)
        )
    }

    private mutating func offset(_ point: CGPoint) -> CGPoint {
        let radius = Self.amplitude * CGFloat.random(in: 0...1, using: &generator).squareRoot()
        let angle = CGFloat.random(in: 0..<(2 * .pi), using: &generator)
        return CGPoint(x: point.x + radius * cos(angle), y: point.y + radius * sin(angle))
    }
}

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
