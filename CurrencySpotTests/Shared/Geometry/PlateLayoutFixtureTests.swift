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
    func platesAndOutlinesNeverOverlap(photo: String) throws {
        let result = try PlateLayoutFixture(photo).layout()

        #expect(PlateCoverage.overlappingShapes(result) == 0)
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

    @Test(arguments: PlateLayoutFixture.names, 0 ..< 10)
    func jitteringLiveFramesKeepPlatesSteady(photo: String, seed: Int) throws {
        let fixture = try PlateLayoutFixture(photo)
        let photoIndex = PlateLayoutFixture.names.firstIndex(of: photo) ?? 0
        var jitter = CornerJitter(seed: UInt64(photoIndex * 100 + 1 + seed * 13) &* 7919)
        var stabilizer = LiveDetectionStabilizer()
        var memory = PlateLayoutMemory(tracksFrames: true)
        var previous: PlateLayout.Result?
        var changes: [String] = []
        var framesWithOverlap = 0

        for frame in 0..<10 {
            stabilizer.record(fixture.detected.map { jitter.jittered($0) })
            let result = fixture.layout(stabilizer.items, memory: &memory)
            if PlateCoverage.overlappingPlatePairs(result.plates) > 0 { framesWithOverlap += 1 }
            if let previous {
                changes += Self.changes(from: previous, to: result).map { "frame \(frame): \($0)" }
            }
            previous = result
        }

        #expect(changes.count <= 2, "\(changes)")
        #expect(framesWithOverlap == 0)
    }

    private static func changes(from before: PlateLayout.Result, to after: PlateLayout.Result) -> [String] {
        before.plates.compactMap { old in
            guard let new = after.plates.first(where: { $0.id == old.id }) else { return "\(old.text) vanished" }
            var kinds: [String] = []
            if abs(old.fontSize - new.fontSize) > 0.01 { kinds.append("font \(old.fontSize)→\(new.fontSize)") }
            if old.alignment != new.alignment { kinds.append("alignment \(old.alignment)→\(new.alignment)") }
            if abs(old.size.width - new.size.width) >= 1 { kinds.append("width \(old.size.width)→\(new.size.width)") }
            if abs(old.size.height - new.size.height) >= 1 { kinds.append("height \(old.size.height)→\(new.size.height)") }
            return kinds.isEmpty ? nil : "\(old.text) " + kinds.joined(separator: ", ")
        }
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
