import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

struct CurrencyMarkerResolverTests {
    private static func item(
        _ id: UUID,
        _ transcript: String,
        x: CGFloat,
        y: CGFloat = 0,
        width: CGFloat = 40,
        height: CGFloat = 20
    ) -> RecognizedTextItem {
        RecognizedTextItem(id: id, transcript: transcript, bounds: CGRect(x: x, y: y, width: width, height: height))
    }

    private static let resolver = CurrencyMarkerResolver(maxGap: 1.0, minLineOverlap: 0.4)

    private static func glyphs(beside items: [RecognizedTextItem]) -> [UUID: Character] {
        resolver.markersBesideNumbers(in: items).mapValues(\.glyph)
    }

    @Test func suffixMarkerOnTheSameLinePromotesTheNumber() {
        let number = UUID(), marker = UUID()
        let result = Self.glyphs(beside: [
            Self.item(number, "680", x: 0),
            Self.item(marker, "円", x: 44, width: 18),
        ])
        #expect(result == [number: "円"])
    }

    @Test func prefixMarkerOnTheSameLinePromotesTheNumber() {
        let number = UUID(), marker = UUID()
        let result = Self.glyphs(beside: [
            Self.item(marker, "¥", x: 28, width: 18),
            Self.item(number, "680", x: 50),
        ])
        #expect(result == [number: "¥"])
    }

    @Test func symbolMarkerRescuesASubHundredAmount() {
        let number = UUID(), marker = UUID()
        let result = Self.glyphs(beside: [
            Self.item(number, "8", x: 0, width: 30),
            Self.item(marker, "€", x: 34, width: 18),
        ])
        #expect(result == [number: "€"])
    }

    @Test(arguments: ["USD", "ALL", "TOP"])
    func bareIsoCodeWordIsNotAStandaloneMarker(word: String) {
        let number = UUID()
        let result = Self.glyphs(beside: [
            Self.item(number, "50", x: 0, width: 30),
            Self.item(UUID(), word, x: 34, width: 44),
        ])
        #expect(result.isEmpty)
    }

    @Test(arguments: ["$$", "€ $ £"])
    func severalGlyphsAreNotAStandaloneMarker(transcript: String) {
        let result = Self.glyphs(beside: [
            Self.item(UUID(), "50", x: 0, width: 30),
            Self.item(UUID(), transcript, x: 34, width: 18),
        ])
        #expect(result.isEmpty)
    }

    @Test(arguments: [("￥", Character("¥")), ("円 ", "円")])
    func singleGlyphReadsAsItsNormalizedMarker(transcript: String, glyph: Character) {
        let number = UUID()
        let result = Self.glyphs(beside: [
            Self.item(UUID(), transcript, x: 28, width: 18),
            Self.item(number, "680", x: 50),
        ])
        #expect(result == [number: glyph])
    }

    @Test func markerRecordsWhichSideOfTheNumberItSits() {
        let left = UUID(), right = UUID()
        let result = Self.resolver.markersBesideNumbers(in: [
            Self.item(UUID(), "¥", x: 0, width: 18),
            Self.item(left, "680", x: 22),
            Self.item(right, "Poutine 12", x: 0, y: 100, width: 80),
            Self.item(UUID(), "$", x: 84, y: 100, width: 18),
        ]).mapValues(\.side)
        #expect(result == [left: .leading, right: .trailing])
    }

    @Test func markerBetweenTwoNumbersPromotesOnlyTheNearest() {
        let far = UUID(), near = UUID()
        let result = Self.glyphs(beside: [
            Self.item(far, "100", x: 0, width: 40),
            Self.item(UUID(), "円", x: 50, width: 18),
            Self.item(near, "200", x: 72, width: 40),
        ])
        #expect(result == [near: "円"])
    }

    @Test func numberWithNoMarkerItemIsNotPromoted() {
        let number = UUID()
        let result = Self.glyphs(beside: [Self.item(number, "680", x: 0)])
        #expect(result.isEmpty)
    }

    @Test func markerOnAnotherLineDoesNotPromote() {
        let number = UUID(), marker = UUID()
        let result = Self.glyphs(beside: [
            Self.item(number, "680", x: 0, y: 0),
            Self.item(marker, "円", x: 44, y: 100, width: 18),
        ])
        #expect(result.isEmpty)
    }

    @Test func markerTooFarHorizontallyDoesNotPromote() {
        let number = UUID(), marker = UUID()
        let result = Self.glyphs(beside: [
            Self.item(number, "680", x: 0),
            Self.item(marker, "円", x: 200, width: 18),
        ])
        #expect(result.isEmpty)
    }

    @Test func inlineMarkedNumberNeedsNoSeparateMarker() {
        let number = UUID()
        let result = Self.glyphs(beside: [Self.item(number, "¥680", x: 0)])
        #expect(result.isEmpty)
    }
}
