import Foundation
import Testing
@testable import CurrencySpot

struct PriceClassifierMeasurementTests {
    private let classifier = PriceClassifier()

    @Test(arguments: [
        "1.5 kg", "2.4 GHz", "0.5 mm", "2,000 mAh", "1,500 kcal", "16.9 fl oz", "1.2 m²", "4.5 pcs",
        "64GB", "5.0 MP", "1,500 ft", "1,200 rpm", "2.5x", "6.1-inch", "Energy 1,046 kJ / 250 kcal",
    ])
    func numberWithAUnitIsNotANumber(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: [
        "12.5%", "13,5 % vol", "98.6 °F", "6.1\"", "4.8★", "★ 4.8", "Item #12345", "f/1.8", "×1.5", "Ø 12.5",
        "%50 İNDİRİM",
    ])
    func numberWithAMeasurementMarkIsNotANumber(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: [
        ("Only 9.99 in store", "9.99"),
        ("Burger 12.50 w/ fries", "12.5"),
        ("Salad 9.50 w/ chicken", "9.5"),
        ("Steak 24.90 ★★", "24.9"),
        ("TVA 5,5 % 1,23", "1.23"),
    ])
    func everydayWordOrRatingBesideAPriceKeepsThePrice(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("2 × 1,99", "1.99"), ("Rice 2.50 x 2", "2.5")])
    func quantityTimesSignLeavesTheUnitPrice(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: ["Dimensions 30.00 x 20.00 cm", "30.5 x 20.5 cm"])
    func dimensionsAreNotNumbers(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: ["Mon-Fri 9.30 to 18.00", "Tue-Sun 10.00 to 17.00", "Open daily 10.00 till 22.00"])
    func dotTimesOnALineWithADetectedDotTimeAreNotNumbers(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: [
        ("Tel 555-1234 Lunch 12.50", "12.5"),
        ("Open 10:00 Lunch 12.50", "12.5"),
        ("Was 4.99 Now 3.49", "4.99"),
    ])
    func minuteShapedPriceWithoutADetectedDotTimeStaysAPrice(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: ["口コミ 1,234件", "定員 1,200名", "1,234명", "2.5倍", "3.5時間", "1.5 กม.", "Mileage 1,234 reviews"])
    func numberWithACounterIsNotANumber(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: ["Ver.2.0", "Model A55", "Gate B12"])
    func numberGluedToAWordIsNotANumber(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: [("Soup 4.50 L", "4.5"), ("Milk 3.49 T", "3.49"), ("Eggs 2.49 X", "2.49")])
    func singleCapitalAfterAPriceIsASizeOrTaxLabel(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: ["0,75 L", "0.33 L"])
    func singleCapitalAfterAFractionOfOneIsAVolume(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }
}
