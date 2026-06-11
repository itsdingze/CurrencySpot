//
//  ConvertedPlateMetricsTests.swift
//  CurrencySpotTests
//

import Foundation
import Testing
@testable import CurrencySpot

struct ConvertedPlateMetricsTests {
    @Test func fontScalesWithDetectedBoxHeight() {
        #expect(ConvertedPlateMetrics.fontSize(forBoxHeight: 40) == 30)
        #expect(ConvertedPlateMetrics.fontSize(forBoxHeight: 80) == 60)
    }

    @Test func fontNeverDropsBelowLegibleMinimum() {
        #expect(ConvertedPlateMetrics.fontSize(forBoxHeight: 10) == 11)
        #expect(ConvertedPlateMetrics.fontSize(forBoxHeight: 0) == 11)
    }
}
