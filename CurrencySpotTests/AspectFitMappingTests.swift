//
//  AspectFitMappingTests.swift
//  CurrencySpotTests
//

import Foundation
import Testing
@testable import CurrencySpot

struct AspectFitMappingTests {
    /// A 1000×500 image fit into a 500×500 view scales by 0.5 and centers vertically.
    @Test func mapsImageRectsIntoTheFittedViewSpace() {
        let mapping = AspectFitMapping(imageSize: CGSize(width: 1000, height: 500), viewSize: CGSize(width: 500, height: 500))

        let viewRect = mapping.viewRect(for: CGRect(x: 100, y: 100, width: 200, height: 50))

        #expect(viewRect == CGRect(x: 50, y: 175, width: 100, height: 25))
    }
}
