import CoreGraphics
import Foundation
@testable import CurrencySpot

nonisolated enum PlateCoverage {
    private static let frameWidth: CGFloat = 402
    private static let frameHeight: CGFloat = 760

    static func overlappingPlatePairs(_ plates: [PlateLayout.Plate]) -> Int {
        var count = 0
        for first in plates.indices {
            for second in plates.indices where second > first && intersectionArea(plates[first].quad, plates[second].quad) > 0.01 {
                count += 1
            }
        }
        return count
    }

    static func overlappingShapes(_ result: PlateLayout.Result) -> Int {
        let shapes = result.plates.map(\.quad) + result.outlines.map(\.quad)
        var count = 0
        for first in shapes.indices {
            for second in shapes.indices where second > first && intersectionArea(shapes[first], shapes[second]) > 0.01 {
                count += 1
            }
        }
        return count
    }

    private static func intersectionArea(_ first: Quad, _ second: Quad) -> CGFloat {
        area(clip(oriented(first.corners), to: oriented(second.corners)))
    }

    @concurrent
    static func itemTextCoveredShare(lines: [Quad], priceTokens tokens: [Quad], plates: [Quad]) async -> Double {
        let scale: CGFloat = 4
        let width = Int(PlateCoverage.frameWidth * scale)
        var isText = [Bool](repeating: false, count: width * Int(PlateCoverage.frameHeight * scale))
        var isCovered = isText
        for line in lines {
            let box = line.boundingBox
            let nearbyTokens = tokens.filter { $0.boundingBox.intersects(box) }
            let nearbyPlates = plates.filter { $0.boundingBox.intersects(box) }
            for y in max(0, Int(box.minY * scale))...Int(box.maxY * scale) {
                for x in max(0, Int(box.minX * scale))...min(width - 1, Int(box.maxX * scale)) {
                    let index = y * width + x
                    guard index < isText.count, !isText[index] else { continue }
                    let point = CGPoint(x: (CGFloat(x) + 0.5) / scale, y: (CGFloat(y) + 0.5) / scale)
                    guard line.contains(point), !nearbyTokens.contains(where: { $0.contains(point) }) else { continue }
                    isText[index] = true
                    isCovered[index] = nearbyPlates.contains { $0.contains(point) }
                }
            }
        }
        let textCount = isText.count { $0 }
        guard textCount > 0 else { return 0 }
        return Double(isCovered.count { $0 }) / Double(textCount)
    }

    private static func oriented(_ polygon: [CGPoint]) -> [CGPoint] {
        signedArea(polygon) < 0 ? polygon.reversed() : polygon
    }

    private static func signedArea(_ polygon: [CGPoint]) -> CGFloat {
        guard polygon.count >= 3 else { return 0 }
        return polygon.indices.reduce(0) { sum, index in
            let next = polygon[(index + 1) % polygon.count]
            return sum + polygon[index].x * next.y - polygon[index].y * next.x
        } / 2
    }

    private static func area(_ polygon: [CGPoint]) -> CGFloat {
        abs(signedArea(polygon))
    }

    private static func clip(_ subject: [CGPoint], to clipper: [CGPoint]) -> [CGPoint] {
        var output = subject
        for index in clipper.indices {
            guard !output.isEmpty else { break }
            let a = clipper[index]
            let b = clipper[(index + 1) % clipper.count]
            let edge = CGPoint(x: b.x - a.x, y: b.y - a.y)
            func side(_ p: CGPoint) -> CGFloat { edge.x * (p.y - a.y) - edge.y * (p.x - a.x) }
            let input = output
            output = []
            for pointIndex in input.indices {
                let p = input[pointIndex]
                let q = input[(pointIndex + 1) % input.count]
                let pInside = side(p) >= 0
                let qInside = side(q) >= 0
                if pInside { output.append(p) }
                if pInside != qInside {
                    let t = side(p) / (side(p) - side(q))
                    output.append(CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t))
                }
            }
        }
        return output
    }
}
