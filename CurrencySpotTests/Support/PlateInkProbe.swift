import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import CurrencySpot

nonisolated struct PlateInkProbe: Sendable {
    struct Glyph: Sendable {
        let bounds: CGRect
        let pixelCount: Int
        let coveredCount: Int

        var visibleShare: Double { Double(pixelCount - coveredCount) / Double(pixelCount) }
    }

    struct Report: Sendable {
        var priceGlyphs: [Glyph] = []
        var otherGlyphs: [Glyph] = []

        var coveredOtherGlyphs: [Glyph] { otherGlyphs.filter { $0.coveredCount > 0 } }
        var priceRemnants: [Glyph] { priceGlyphs.filter { $0.visibleShare > PlateInkProbe.remnantShare } }
    }

    static let remnantShare = 0.02
    private static let scale: CGFloat = 3
    private static let regionGrowthAcross: CGFloat = 0.2
    private static let backgroundPercentile = 0.85
    private static let inkShareOfBackground = 0.6
    private static let punctuationShare: CGFloat = 0.3

    private let lines: [Quad]
    private let priceTokens: [Quad]
    private let photoURL: URL
    private let imageFrame: CGRect
    private let frameSize: CGSize

    @MainActor
    init(fixture: PlateLayoutFixture) {
        lines = fixture.items.map(\.quad)
        priceTokens = fixture.prices.map(\.tokenQuad)
        photoURL = fixture.photoURL
        imageFrame = fixture.imageFrame
        frameSize = PlateLayoutFixture.frameSize
    }

    private var width: Int { Int(frameSize.width * Self.scale) }
    private var height: Int { Int(frameSize.height * Self.scale) }

    @concurrent
    func measure(_ result: PlateLayout.Result) async throws -> Report {
        let values = try photoValues()
        var owner = [Int32](repeating: -1, count: width * height)
        var regions: [(line: Int, pixels: [Int], lineHeight: CGFloat)] = []
        for (lineIndex, line) in lines.enumerated() {
            let inside = pixels(inside: grown(line))
            guard !inside.isEmpty else { continue }
            let background = percentile(inside.map { values[$0] }, Self.backgroundPercentile)
            let threshold = Double(background) * Self.inkShareOfBackground
            var ink: [Int] = []
            for index in inside where Double(values[index]) < threshold && owner[index] < 0 {
                owner[index] = Int32(lineIndex)
                ink.append(index)
            }
            regions.append((lineIndex, ink, line.height * Self.scale))
        }

        var report = Report()
        var visited = Set<Int>()
        for region in regions {
            for start in region.pixels where !visited.contains(start) {
                let pixels = component(from: start, owner: owner, visited: &visited)
                let bounds = bounds(of: pixels)
                guard max(bounds.width, bounds.height) * Self.scale >= Self.punctuationShare * region.lineHeight else { continue }
                let glyph = Glyph(
                    bounds: bounds,
                    pixelCount: pixels.count,
                    coveredCount: pixels.count { index in result.plates.contains { $0.covers(point(of: index)) } }
                )
                if pixels.count(where: { isInside(point(of: $0), any: priceTokens) }) * 2 > pixels.count {
                    report.priceGlyphs.append(glyph)
                } else {
                    report.otherGlyphs.append(glyph)
                }
            }
        }
        return report
    }

    private func point(of index: Int) -> CGPoint {
        CGPoint(x: (CGFloat(index % width) + 0.5) / Self.scale, y: (CGFloat(index / width) + 0.5) / Self.scale)
    }

    private func isInside(_ point: CGPoint, any quads: [Quad]) -> Bool {
        quads.contains { $0.boundingBox.contains(point) && $0.contains(point) }
    }

    private func pixels(inside quad: Quad) -> [Int] {
        let box = quad.boundingBox
        let minX = max(0, Int(box.minX * Self.scale))
        let maxX = min(width - 1, Int(box.maxX * Self.scale))
        let minY = max(0, Int(box.minY * Self.scale))
        let maxY = min(height - 1, Int(box.maxY * Self.scale))
        guard minX <= maxX, minY <= maxY else { return [] }
        var result: [Int] = []
        for y in minY...maxY {
            for x in minX...maxX where quad.contains(point(of: y * width + x)) {
                result.append(y * width + x)
            }
        }
        return result
    }

    private func bounds(of pixels: [Int]) -> CGRect {
        let xs = pixels.map { $0 % width }
        let ys = pixels.map { $0 / width }
        return CGRect(
            x: CGFloat(xs.min() ?? 0) / Self.scale,
            y: CGFloat(ys.min() ?? 0) / Self.scale,
            width: CGFloat((xs.max() ?? 0) - (xs.min() ?? 0) + 1) / Self.scale,
            height: CGFloat((ys.max() ?? 0) - (ys.min() ?? 0) + 1) / Self.scale
        )
    }

    private func grown(_ quad: Quad) -> Quad {
        let across = quad.height * Self.regionGrowthAcross
        let up = CGPoint(x: (quad.topLeft.x - quad.bottomLeft.x) / quad.height, y: (quad.topLeft.y - quad.bottomLeft.y) / quad.height)
        func moved(_ point: CGPoint, _ distance: CGFloat) -> CGPoint {
            CGPoint(x: point.x + up.x * distance, y: point.y + up.y * distance)
        }
        return Quad(
            topLeft: moved(quad.topLeft, across),
            topRight: moved(quad.topRight, across),
            bottomRight: moved(quad.bottomRight, -across),
            bottomLeft: moved(quad.bottomLeft, -across)
        )
    }

    private func component(from start: Int, owner: [Int32], visited: inout Set<Int>) -> [Int] {
        var stack = [start]
        var pixels: [Int] = []
        visited.insert(start)
        while let index = stack.popLast() {
            pixels.append(index)
            let x = index % width
            let y = index / width
            for dy in -1...1 {
                for dx in -1...1 where dx != 0 || dy != 0 {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                    let next = ny * width + nx
                    if owner[next] == owner[start], visited.insert(next).inserted {
                        stack.append(next)
                    }
                }
            }
        }
        return pixels
    }

    private func photoValues() throws -> [UInt8] {
        let size = frameSize
        let source = try #require(CGImageSourceCreateWithURL(photoURL as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var bytes = [UInt8](repeating: 0, count: width * height)
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            let fitted = imageFrame
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(
                x: fitted.minX * Self.scale,
                y: (size.height - fitted.maxY) * Self.scale,
                width: fitted.width * Self.scale,
                height: fitted.height * Self.scale
            ))
        }
        return bytes
    }

    private func percentile(_ values: [UInt8], _ share: Double) -> UInt8 {
        let sorted = values.sorted()
        return sorted[min(sorted.count - 1, Int(Double(sorted.count) * share))]
    }
}

nonisolated extension PlateLayout.Plate {
    func covers(_ point: CGPoint) -> Bool {
        guard visibleBounds.contains(point) else { return false }
        let along = CGPoint(x: (quad.topRight.x - quad.topLeft.x) / size.width, y: (quad.topRight.y - quad.topLeft.y) / size.width)
        let across = CGPoint(x: (quad.bottomLeft.x - quad.topLeft.x) / size.height, y: (quad.bottomLeft.y - quad.topLeft.y) / size.height)
        let offset = CGPoint(x: point.x - quad.topLeft.x, y: point.y - quad.topLeft.y)
        let x = offset.x * along.x + offset.y * along.y
        let y = offset.x * across.x + offset.y * across.y
        guard x >= 0, y >= 0, x <= size.width, y <= size.height else { return false }
        let cornerX = min(x, size.width - x)
        let cornerY = min(y, size.height - y)
        guard cornerX < cornerRadius, cornerY < cornerRadius else { return true }
        return hypot(cornerRadius - cornerX, cornerRadius - cornerY) <= cornerRadius
    }
}
