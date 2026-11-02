import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

struct PlateLayoutFixtureTests {
    @Test(arguments: PlateLayoutFixture.names)
    func platesNeverOverlap(photo: String) throws {
        let result = try PlateLayoutFixture(photo).layout()

        #expect(PlateCoverage.overlappingPlatePairs(result.plates) == 0)
    }

    @Test(arguments: PlateLayoutFixture.names)
    func hitTargetsNeverOverlap(photo: String) throws {
        let result = try PlateLayoutFixture(photo).layout()

        #expect(PlateCoverage.overlappingHitTargets(result) == 0)
    }

    @Test(arguments: PlateLayoutFixture.names)
    func plateTextIsNeverSmallerThanTheMinimum(photo: String) throws {
        let result = try PlateLayoutFixture(photo).layout()

        #expect(result.plates.allSatisfy { $0.fontSize >= 11 })
    }

    @Test func everySushiPriceGetsAPlateWithoutHidingTheItems() async throws {
        let fixture = try PlateLayoutFixture("6-real-sushi-menu")

        let result = fixture.layout()

        let covered = await PlateCoverage.itemTextCoveredShare(
            lines: fixture.items.map(\.quad),
            priceTokens: fixture.prices.map(\.tokenQuad),
            plates: result.plates.map(\.quad)
        )
        #expect(fixture.prices.count == 34)
        #expect(result.plates.count == 34)
        #expect(covered <= 0.01)
    }

    @Test(arguments: [
        ("1-menu-en-yen", 0.0...0.0),
        ("2-menu-en-yen-tilt8", -9.0 ... -7.0),
        ("3-menu-ja", 0.0...0.0),
        ("4-tags-eu", 0.0...0.0),
        ("5-noise-and-multi", 0.0...0.0),
        ("6-real-sushi-menu", -5.0 ... -3.0),
        ("7-real-price-tag", 0.0...0.0),
    ])
    func pageAngleFollowsThePrintedRows(photo: String, degrees: ClosedRange<Double>) throws {
        let angle = Double(try PlateLayoutFixture(photo).layout().angle * 180 / .pi)

        #expect(degrees.contains(angle), "\(photo) \(angle)°")
    }

    @Test(arguments: ["2-menu-en-yen-tilt8", "3-menu-ja", "4-tags-eu"])
    func platesLeaveEveryOtherGlyphVisible(photo: String) async throws {
        let fixture = try PlateLayoutFixture(photo)

        let report = try await PlateInkProbe(fixture: fixture).measure(fixture.layout())

        #expect(report.otherGlyphs.count > 5)
        #expect(report.coveredOtherGlyphs.map(\.bounds) == [], "\(photo)")
    }

    @Test(arguments: ["2-menu-en-yen-tilt8", "3-menu-ja", "4-tags-eu"])
    func platesHideTheWholeOriginalPrice(photo: String) async throws {
        let fixture = try PlateLayoutFixture(photo)

        let report = try await PlateInkProbe(fixture: fixture).measure(fixture.layout())

        #expect(report.priceGlyphs.count >= fixture.prices.count)
        #expect(report.priceRemnants.map(\.bounds) == [], "\(photo)")
    }
}
