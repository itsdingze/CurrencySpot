import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

@Suite(.serialized)
struct PlateLayoutDeviceReadTests {
    @Test(arguments: ["2-menu-en-yen-tilt8", "3-menu-ja", "4-tags-eu"])
    func platesCoverPricesReadOnThisDeviceAndNothingElse(photo: String) async throws {
        let fixture = try await PlateLayoutFixture.readOnThisDevice(photo)

        let report = try await PlateInkProbe(fixture: fixture).measure(fixture.layout())

        #expect(fixture.prices.count >= 4)
        #expect(report.priceRemnants.map(\.bounds) == [], "\(photo) remnants")
        #expect(report.coveredOtherGlyphs.map(\.bounds) == [], "\(photo) covered")
    }

    @Test(arguments: [
        ("1-menu-en-yen", 0.0...0.0),
        ("2-menu-en-yen-tilt8", -9.5 ... -6.5),
        ("3-menu-ja", 0.0...0.0),
        ("4-tags-eu", 0.0...0.0),
        ("5-noise-and-multi", 0.0...0.0),
        ("6-real-sushi-menu", -5.0 ... -3.0),
        ("7-real-price-tag", 0.0...0.0),
    ])
    func pageAngleReadOnThisDeviceFollowsThePrintedRows(photo: String, degrees: ClosedRange<Double>) async throws {
        let fixture = try await PlateLayoutFixture.readOnThisDevice(photo)

        let angle = Double(fixture.layout().angle * 180 / .pi)

        #expect(degrees.contains(angle), "\(photo) \(angle)°")
    }
}
