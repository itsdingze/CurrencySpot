import Foundation
import Testing
@testable import CurrencySpot

struct PriceClassifierOCRRepairTests {
    private let classifier = PriceClassifier()

    @Test(arguments: [
        ("S12.99", "12.99"), ("Burger S4.50", "4.50"), ("S4.50 each", "4.50"), ("(S4.50)", "4.50"), ("[S4.50]", "4.50"),
    ])
    func capitalSGluedToCentsReadsAsADollarSign(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: ["S12", "S12.5", "BS12.99", "S12.99x", "s12.99", "A-S12.99"])
    func letterSThatIsNotADollarSignStaysPartOfAWord(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: [
        ("$1O.99", "10.99"), ("11,9O €", "11.90"), ("£O.99", "0.99"), ("€ 1O", "10"), ("5O €", "50"), ("5O円", "50"),
        ("1,2OO원", "1200"),
    ])
    func capitalOInANumberBesideACurrencySymbolReadsAsZero(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("NO.5 €", "5"), ("$1Oz", "1")])
    func capitalOInsideAWordBesideACurrencySymbolStaysALetter(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test func chemicalFormulaBesideACurrencySymbolPricesNothing() {
        #expect(classifier.classify("H2O €") == nil)
    }

    @Test(arguments: ["Room 1O", "2O15", "1O.99"])
    func capitalOAwayFromACurrencySymbolStaysALetter(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: [("¥1, 200", "1200"), ("$12, 500", "12500"), ("1, 200円", "1200")])
    func commaThenSpaceBesideAMarkerGroupsThousands(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("$5, 20", "5"), ("$5, 1000", "5"), ("$5,  200", "5"), ("$5.-, 200", "5")])
    func commaThenSpaceWithoutExactlyThreeDigitsKeepsTheNumbersApart(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [
        ("Burger $9, 100% beef", "9"), ("Pizza €12, 350 kcal", "12"), ("Hotel $5, 100 reviews", "5"), ("¥5, 100個", "5"),
    ])
    func commaThenSpaceBeforeAMeasurementKeepsTheNumbersApart(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("Tables 12, 345", "12"), ("TOP 5, 100", "5")])
    func commaThenSpaceWithoutAPriceMarkerKeepsTheNumbersApart(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .outline(amount)))
    }

    @Test(arguments: [("6,5 0 €", "6.50"), ("6.5 0 €", "6.50")])
    func strayZeroAfterOneDecimalBesideAMarkerCompletesTheCents(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test func strayZeroAfterTwoDecimalsAddsNothing() throws {
        #expect(classifier.classify("6,50 0 €") == (try .price("6.50")))
    }

    @Test func realDigitAfterOneDecimalIsItsOwnPrice() throws {
        #expect(classifier.classify("Bier 0,5 5 €") == (try .price("5")))
    }

    @Test func strayZeroWithoutAMarkerLeavesTheOutline() throws {
        #expect(classifier.classify("Soup 6,5 0") == (try .outline("6.5")))
    }
}
