import Foundation
import Testing
@testable import CurrencySpot

struct AspectFitMappingTests {
    @Test func mapsImageRectsIntoTheFittedViewSpace() {
        let mapping = AspectFitMapping(imageSize: CGSize(width: 1000, height: 500), viewSize: CGSize(width: 500, height: 500))

        let viewRect = mapping.viewRect(for: CGRect(x: 100, y: 100, width: 200, height: 50))

        #expect(viewRect == CGRect(x: 50, y: 175, width: 100, height: 25))
    }
}
