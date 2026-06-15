//
//  PriceClassifierTests.swift
//  CurrencySpotTests
//

import Foundation
import Testing
@testable import CurrencySpot

struct PriceClassifierTests {
    private let classifier = PriceClassifier()

    @Test func amountWithCurrencySymbolIsAPrice() {
        let result = classifier.classify("¥1,200")
        #expect(result == PriceClassification(amount: 1200, isPrice: true))
    }

    @Test func bareGroupedNumberIsAPrice() {
        let result = classifier.classify("1,200")
        #expect(result == PriceClassification(amount: 1200, isPrice: true))
    }

    @Test func decimalCommaParsesAsFraction() {
        let result = classifier.classify("€12,50")
        #expect(result == PriceClassification(amount: Decimal(string: "12.5")!, isPrice: true))
    }

    @Test func multiNumberTranscriptPicksThePriceShapedToken() {
        let result = classifier.classify("2 for 5.00")
        #expect(result == PriceClassification(amount: 5, isPrice: true))
    }

    @Test(arguments: ["12.06.2026", "12/06/2026", "June 10, 2026"])
    func datesAreFilteredOut(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: ["1.5kg", "330ml", "2.4GHz", "98.6°F"])
    func measurementsAreFilteredOut(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: [("USD 20", 20), ("20 EUR", 20), ("1200円", 1200)])
    func currencyCodeOrCJKMarkerIsAPrice(transcript: String, amount: Int) {
        let result = classifier.classify(transcript)
        #expect(result == PriceClassification(amount: Decimal(amount), isPrice: true))
    }

    @Test(arguments: ["090-1234-5678", "(415) 555-2671", "10:30", "16:9"])
    func phoneNumbersTimesAndRatiosAreFilteredOut(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: ["4901234567894", "1234567"])
    func longBareDigitRunsAreFilteredOut(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: ["SN12345", "REF2024", "A1234"])
    func letterGluedIdentifiersAreFilteredOut(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: ["12-34567", "4006-100-0000"])
    func hyphenGluedDigitGroupsAreFilteredOut(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    /// A currency marker overrides every noise rule.
    @Test func currencyMarkerBeatsNoiseRules() {
        let result = classifier.classify("$1234567")
        #expect(result == PriceClassification(amount: 1234567, isPrice: true))
    }

    /// Conservative: a bare integer with no separator and no marker stays an
    /// outline. A split-off marker beside it (handled by CurrencyMarkerResolver),
    /// not magnitude, is what makes "680円" a price.
    @Test(arguments: ["8", "80", "680", "1200", "150000"])
    func bareUnmarkedIntegerIsNotAPrice(transcript: String) {
        let result = classifier.classify(transcript)
        #expect(result == PriceClassification(amount: Decimal(string: transcript)!, isPrice: false))
    }

    @Test(arguments: ["Open daily", "MENU", ""])
    func textWithoutNumbersIsNotANumber(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }
}
