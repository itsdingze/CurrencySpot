//
//  CurrencyMarkerResolverTests.swift
//  CurrencySpotTests
//

import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

struct CurrencyMarkerResolverTests {
    /// A 20pt-tall recognized item; width defaults to a short token.
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

    /// Marker may sit up to one text-height away and must share most of the line.
    private static let resolver = CurrencyMarkerResolver(maxGap: 1.0, minLineOverlap: 0.4)

    @Test func suffixMarkerOnTheSameLinePromotesTheNumber() {
        let number = UUID(), marker = UUID()
        let result = Self.resolver.numbersAdjacentToMarker(in: [
            Self.item(number, "680", x: 0),
            Self.item(marker, "円", x: 44, width: 18),
        ])
        #expect(result == [number])
    }

    @Test func prefixMarkerOnTheSameLinePromotesTheNumber() {
        let number = UUID(), marker = UUID()
        let result = Self.resolver.numbersAdjacentToMarker(in: [
            Self.item(marker, "¥", x: 28, width: 18),
            Self.item(number, "680", x: 50),
        ])
        #expect(result == [number])
    }

    @Test func symbolMarkerRescuesASubHundredAmount() {
        let number = UUID(), marker = UUID()
        let result = Self.resolver.numbersAdjacentToMarker(in: [
            Self.item(number, "8", x: 0, width: 30),
            Self.item(marker, "€", x: 34, width: 18),
        ])
        #expect(result == [number])
    }

    /// A bare all-caps word that happens to be an ISO code ("USD", "ALL", "TOP")
    /// is not trusted as a standalone marker — too easily ordinary sign text.
    @Test(arguments: ["USD", "ALL", "TOP"])
    func bareIsoCodeWordIsNotAStandaloneMarker(word: String) {
        let number = UUID()
        let result = Self.resolver.numbersAdjacentToMarker(in: [
            Self.item(number, "50", x: 0, width: 30),
            Self.item(UUID(), word, x: 34, width: 44),
        ])
        #expect(result.isEmpty)
    }

    /// A marker sitting between two numbers promotes only the nearer one.
    @Test func markerBetweenTwoNumbersPromotesOnlyTheNearest() {
        let far = UUID(), near = UUID()
        let result = Self.resolver.numbersAdjacentToMarker(in: [
            Self.item(far, "100", x: 0, width: 40),     // gap to marker: 10
            Self.item(UUID(), "円", x: 50, width: 18),
            Self.item(near, "200", x: 72, width: 40),    // gap to marker: 4
        ])
        #expect(result == [near])
    }

    @Test func numberWithNoMarkerItemIsNotPromoted() {
        let number = UUID()
        let result = Self.resolver.numbersAdjacentToMarker(in: [Self.item(number, "680", x: 0)])
        #expect(result.isEmpty)
    }

    @Test func markerOnAnotherLineDoesNotPromote() {
        let number = UUID(), marker = UUID()
        let result = Self.resolver.numbersAdjacentToMarker(in: [
            Self.item(number, "680", x: 0, y: 0),
            Self.item(marker, "円", x: 44, y: 100, width: 18),
        ])
        #expect(result.isEmpty)
    }

    @Test func markerTooFarHorizontallyDoesNotPromote() {
        let number = UUID(), marker = UUID()
        let result = Self.resolver.numbersAdjacentToMarker(in: [
            Self.item(number, "680", x: 0),
            Self.item(marker, "円", x: 200, width: 18),
        ])
        #expect(result.isEmpty)
    }

    /// An inline-marked number ("¥680") is the classifier's job; the resolver only
    /// fires when the marker is a separate item, so it finds nothing here.
    @Test func inlineMarkedNumberNeedsNoSeparateMarker() {
        let number = UUID()
        let result = Self.resolver.numbersAdjacentToMarker(in: [Self.item(number, "¥680", x: 0)])
        #expect(result.isEmpty)
    }
}
