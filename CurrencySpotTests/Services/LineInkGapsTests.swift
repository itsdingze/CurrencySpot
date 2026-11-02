import CoreGraphics
import Testing
@testable import CurrencySpot

struct LineInkGapsTests {
    private let line = Quad(CGRect(x: 0, y: 10, width: 200, height: 20))

    private func strip(background: CGFloat, bars: [CGRect] = []) throws -> GrayscaleImage {
        let context = try #require(CGContext(
            data: nil,
            width: 200,
            height: 40,
            bitsPerComponent: 8,
            bytesPerRow: 200,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        context.setFillColor(gray: background, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 40))
        context.setFillColor(gray: 0, alpha: 1)
        bars.forEach { context.fill($0) }
        let image = try #require(context.makeImage())
        return try #require(GrayscaleImage(image))
    }

    @Test(arguments: [1, 0] as [CGFloat])
    func uniformLineHasNoInkGaps(background: CGFloat) throws {
        let gaps = LineInkGaps.gaps(along: line, in: try strip(background: background))

        #expect(gaps.isEmpty)
    }

    @Test func darkGlyphsOnLightPaperLeaveGapsBetweenThem() throws {
        let image = try strip(background: 1, bars: [CGRect(x: 20, y: 12, width: 40, height: 16), CGRect(x: 100, y: 12, width: 40, height: 16)])

        let gaps = LineInkGaps.gaps(along: line, in: image)

        #expect(gaps.contains { $0.lowerBound <= 0.31 && $0.upperBound >= 0.49 })
    }
}
