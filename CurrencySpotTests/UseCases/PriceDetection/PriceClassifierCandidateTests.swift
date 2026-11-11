import Foundation
import Testing
@testable import CurrencySpot

struct PriceClassifierCandidateTests {
    private let classifier = PriceClassifier()

    private func amounts(_ candidates: [PriceCandidate]) -> [PriceClassification] {
        candidates.map(\.classification)
    }

    @Test func classifyReturnsTheFirstMarkedPriceInReadingOrder() throws {
        #expect(classifier.classify("Was $12.99 Now $9.99") == (try .price("12.99")))
    }

    @Test func markedPriceOutranksAnUnmarkedPriceWithCents() throws {
        #expect(classifier.classify("Qty 2.00 $5.00") == (try .price("5")))
    }

    @Test func candidatesListEveryMarkedPriceInReadingOrder() throws {
        let candidates = classifier.candidates(in: "S $3.50 M $4.00 L $4.50")
        #expect(amounts(candidates) == [try .price("3.5"), try .price("4"), try .price("4.5")])
    }

    @Test func candidatesSkipUnmarkedPricesWhenAPriceIsMarked() throws {
        #expect(amounts(classifier.candidates(in: "Qty 2.00 $5.00")) == [try .price("5")])
    }

    @Test func candidatesListEveryUnmarkedPriceWhenNoneIsMarked() throws {
        let candidates = classifier.candidates(in: "Small 3.50 Large 4.50")
        #expect(amounts(candidates) == [try .price("3.5"), try .price("4.5")])
    }

    @Test func candidatesFallBackToTheFirstOutline() throws {
        #expect(amounts(classifier.candidates(in: "Aisle 12 Bay 4")) == [try .outline("12")])
    }

    @Test func candidatesAreEmptyWithoutANumber() {
        #expect(classifier.candidates(in: "Open daily").isEmpty)
    }

    @Test func candidateRangesPointIntoTheOriginalTranscript() throws {
        let transcript = "ラーメン １,２００円"
        let candidate = try #require(classifier.candidates(in: transcript).first)
        #expect(transcript[candidate.range] == "１,２００")
        #expect(transcript[candidate.rangeIncludingMarker] == "１,２００円")
    }

    @Test func devanagariDigitRangesPointIntoTheOriginalTranscript() throws {
        let transcript = "मसाला चाय ₹१,२५०"
        let candidate = try #require(classifier.candidates(in: transcript).first)
        #expect(transcript[candidate.range] == "१,२५०")
        #expect(transcript[candidate.rangeIncludingMarker] == "₹१,२५०")
    }

    @Test(arguments: [
        ("Rs. 499", "499", "Rs. 499"),
        ("Total 1 200 € incl.", "1 200", "1 200 €"),
        ("Price (USD) 20", "20", "USD) 20"),
        ("12,– €", "12,–", "12,– €"),
        ("¥1.2万 税込", "1.2万", "¥1.2万"),
    ])
    func rangeIncludingMarkerSpansTheNumberAndItsMarker(
        transcript: String,
        number: String,
        numberWithMarker: String
    ) throws {
        let candidate = try #require(classifier.candidates(in: transcript).first)
        #expect(String(transcript[candidate.range]) == number)
        #expect(String(transcript[candidate.rangeIncludingMarker]) == numberWithMarker)
    }

    @Test func unmarkedCandidateRangeIncludingMarkerIsItsNumberRange() throws {
        let transcript = "Iced Latte 5.25"
        let candidate = try #require(classifier.candidates(in: transcript).first)
        #expect(transcript[candidate.range] == "5.25")
        #expect(candidate.rangeIncludingMarker == candidate.range)
    }

    @Test func swissFrancWordBindsUnderTheSwissFranc() throws {
        let transcript = "Fr. 12.50"
        let classifier = PriceClassifier(baseCurrency: .chf)
        let candidate = try #require(classifier.candidates(in: transcript).first)
        #expect(transcript[candidate.rangeIncludingMarker] == "Fr. 12.50")
    }
}
