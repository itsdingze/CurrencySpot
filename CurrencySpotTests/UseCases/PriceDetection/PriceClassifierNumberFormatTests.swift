import Foundation
import Testing
@testable import CurrencySpot

struct PriceClassifierNumberFormatTests {
    private let classifier = PriceClassifier()

    @Test(arguments: [
        ("￥980", "980"),
        ("＄12", "12"),
        ("￡5", "5"),
        ("￦500", "500"),
        ("１,２００円", "1200"),
        ("８５０円", "850"),
        ("1，200円", "1200"),
        ("天ぷら盛り合わせ\u{3000}１，６８０円", "1680"),
    ])
    func fullwidthCharactersReadAsTheirAsciiForms(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("Pint 4.5", "4.5"), ("iOS 17.2", "17.2")])
    func unmarkedOneDecimalNumberIsAnOutline(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .outline(amount)))
    }

    @Test(arguments: ["Section 3.1.4", "192.168.1.1", "35.6895", "Ab 01.07", "Receipt No. 004521"])
    func malformedOrZeroLedNumberIsNotANumber(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test func unmarkedCentsOutrankAGroupedNumber() throws {
        #expect(classifier.classify("1,000 x 2,49") == (try .price("2.49")))
    }

    @Test(arguments: [
        ("1 200 €", "1200"),
        ("1 200,50 €", "1200.5"),
        ("1\u{00A0}200,50 €", "1200.5"),
        ("1\u{202F}200 €", "1200"),
        ("12 345,67 €", "12345.67"),
        ("1 299 Kč", "1299"),
        ("Rp 1 250 000", "1250000"),
    ])
    func spaceGroupsThousandsBesideAMarker(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("CHF 1'200.50", "1200.5"), ("CHF 1\u{2019}200.50", "1200.5"), ("1'299", "1299")])
    func apostropheGroupsThousands(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("Room 2 150 ¥", "150"), ("ビール 2 300円", "300"), ("2 980円", "980"), ("4 120 元", "120")])
    func spaceNeverGroupsDigitsBesideAnEastAsianMarker(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test func spacedNumbersWithoutAMarkerStaySeparate() throws {
        #expect(classifier.classify("Table 2 100 guests") == (try .outline("2")))
    }

    @Test(arguments: [
        ("12,-", "12"), ("12.-", "12"), ("120.-", "120"), ("12,\u{2013} €", "12"), ("1 200,- Kč", "1200"),
        ("Rs 250/-", "250"), ("250/-", "250"), ("ข้าวมันไก่ 50.-", "50"),
    ])
    func dashAfterTheDigitsMarksAWholePrice(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: ["12.-15. Juni", "12.\u{2013}15. Juni", "1.-3. Klasse"])
    func dashFollowedByADigitIsARangeNotAPrice(transcript: String) {
        #expect(classifier.classify(transcript)?.isPrice != true)
    }

    @Test(arguments: [
        ("1万円", "10000"), ("1.5万円", "15000"), ("12万9,800円", "129800"), ("1万2千円", "12000"),
        ("3千円", "3000"), ("1만원", "10000"), ("3만 5천원", "35000"), ("¥1.2万", "12000"), ("2.5万元", "25000"),
    ])
    func cjkMultiplierScalesAMarkedAmount(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: ["1万人", "10万部突破", "1万歩", "累計100万部"])
    func cjkMultiplierBeforeACounterIsNotAPrice(transcript: String) {
        #expect(classifier.classify(transcript) == nil)
    }

    @Test(arguments: ["1.- Introduzca la tarjeta", "Paso 1.- Pulse", "Art. 5.- Las personas"])
    func dashNumberFollowedByAWordIsAStepNotAPrice(transcript: String) {
        #expect(classifier.classify(transcript)?.isPrice != true)
    }

    @Test func cjkMultiplierChainStopsAtALargerMultiplier() throws {
        #expect(classifier.classify("3千5万円") == (try .price("50000")))
    }

    @Test(arguments: [("10万", "100000"), ("1万5千", "15000")])
    func unmarkedCjkMultiplierIsAnOutlineOfTheScaledAmount(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .outline(amount)))
    }

    @Test(arguments: [
        ("KD 1.250", "KWD", "1.25"), ("1.250 KWD", "KWD", "1.25"), ("4.750", "KWD", "4.75"),
        ("BD 0.500", "BHD", "0.5"), ("OMR 2.500", "OMR", "2.5"), ("JOD 3.750", "JOD", "3.75"),
        ("TND 1.200", "TND", "1.2"), ("LYD 5.500", "LYD", "5.5"),
    ])
    func threeDecimalBaseReadsThreeDigitsAfterAPeriodAsAFraction(
        transcript: String,
        base: CurrencyCode,
        amount: String
    ) throws {
        let classifier = PriceClassifier(baseCurrency: base)
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("1,250", "KWD", "1250"), ("KD 1.250", "USD", "1250"), ("IQD 25.000", "IQD", "25000")])
    func threeDigitsAfterASeparatorGroupThousandsOtherwise(
        transcript: String,
        base: CurrencyCode,
        amount: String
    ) throws {
        let classifier = PriceClassifier(baseCurrency: base)
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }
}
