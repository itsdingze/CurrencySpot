import Foundation
import Testing
@testable import CurrencySpot

struct ConvertedPlateMetricsTests {
    @Test func fontGrowsWithTheTextHeight() {
        #expect(ConvertedPlateMetrics.fontSize(forTextHeight: 20) > ConvertedPlateMetrics.fontSize(forTextHeight: 16))
    }

    @Test func fontNeverDropsBelowLegibleMinimum() {
        #expect(ConvertedPlateMetrics.fontSize(forTextHeight: 10) == 11)
        #expect(ConvertedPlateMetrics.fontSize(forTextHeight: 0) == 11)
    }

    @Test func fontStopsGrowingOnHugeText() {
        #expect(ConvertedPlateMetrics.fontSize(forTextHeight: 400) == ConvertedPlateMetrics.fontSize(forTextHeight: 200))
    }
}
