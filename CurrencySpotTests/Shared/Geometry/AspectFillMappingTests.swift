import CoreGraphics
import Testing
@testable import CurrencySpot

struct AspectFillMappingTests {
    @Test("a frame wider than the preview fills its height and crops its sides")
    func cropsTheSidesOfAWideFrame() {
        let mapping = AspectFillMapping(imageSize: CGSize(width: 1000, height: 2000), viewSize: CGSize(width: 400, height: 1000))

        #expect(mapping.viewPoint(CGPoint(x: 0, y: 0)) == CGPoint(x: -50, y: 0))
        #expect(mapping.viewPoint(CGPoint(x: 500, y: 1000)) == CGPoint(x: 200, y: 500))
        #expect(mapping.viewPoint(CGPoint(x: 100, y: 200)) == CGPoint(x: 0, y: 100))
    }

    @Test("a frame taller than the preview fills its width and crops top and bottom")
    func cropsTheTopAndBottomOfATallFrame() {
        let mapping = AspectFillMapping(imageSize: CGSize(width: 1000, height: 1000), viewSize: CGSize(width: 400, height: 200))

        #expect(mapping.viewPoint(CGPoint(x: 500, y: 500)) == CGPoint(x: 200, y: 100))
        #expect(mapping.viewPoint(CGPoint(x: 1000, y: 0)) == CGPoint(x: 400, y: -100))
    }

    @Test("a movement in frame pixels scales to preview points without the crop offset")
    func scalesMovementWithoutOffset() {
        let mapping = AspectFillMapping(imageSize: CGSize(width: 1000, height: 2000), viewSize: CGSize(width: 400, height: 1000))

        #expect(mapping.viewDistance(CGPoint(x: 40, y: -20)) == CGPoint(x: 20, y: -10))
    }

    @Test("an empty frame maps nothing")
    func emptyFrameMapsToZero() {
        let mapping = AspectFillMapping(imageSize: .zero, viewSize: CGSize(width: 400, height: 1000))

        #expect(mapping.viewDistance(CGPoint(x: 40, y: -20)) == .zero)
    }
}
