import Foundation
import Testing
@testable import CurrencySpot

struct PriceClassifierMarkerTests {
    private let classifier = PriceClassifier()

    @Test(arguments: [
        ("2 x $5", "5"),
        ("Combo 5 $9", "9"),
        ("Coke 330ml $2", "2"),
        ("3個入 ¥300", "300"),
        ("TEL 03-1234-5678 ランチ 980円", "980"),
        ("Valid until 31.12.2026 €5 off", "5"),
        ("1.5 kg €3,49/kg", "3.49"),
    ])
    func markerPricesTheNumberItTouches(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: ["元町・中華街 4番出口", "병원 3층", "3单元 501室"])
    func markerAwayFromEveryNumberPricesNothing(transcript: String) {
        #expect(classifier.classify(transcript)?.isPrice != true)
    }

    @Test(arguments: [("12 € 15", "12"), ("12 $ 15", "15")])
    func equalGapsFollowTheMarkersReadingSide(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("Chianti 2019 € 38", "38"), ("Barolo 2016 € 65", "65"), ("€ 2019", "2019")])
    func yearLosesAnEqualGapToTheOtherSide(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("12 €5", "5"), ("12$ 5", "12")])
    func smallerGapOutranksTheMarkersReadingSide(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test func zeroBesideAMarkerYieldsToTheNumberOnItsOtherSide() throws {
        #expect(classifier.classify("5 €0") == (try .price("5")))
    }

    @Test func strayZeroBesideAMarkerIsNeverPriced() throws {
        #expect(classifier.classify("Soup of the day 6,5 0 €") == (try .outline("6.5")))
    }

    @Test(arguments: [
        ("$3.99 lb", "3.99"),
        ("€12,90 kg", "12.9"),
        ("Latte $4.50 L", "4.5"),
        ("€12-15", "12"),
    ])
    func markedAmountIgnoresTheUnitOrRangeAfterIt(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test func markerSkipsATimeForTheNumberOnItsOtherSide() throws {
        #expect(classifier.classify("10:30 € 5") == (try .price("5")))
    }

    @Test(arguments: ["10:00-22:00 ¥", "16:9 €"])
    func markerBesideATimeOrRatioPricesNothing(transcript: String) {
        #expect(classifier.classify(transcript)?.isPrice != true)
    }

    @Test(arguments: [("USD: 20", "20"), ("Price (USD) 20", "20"), ("RMB 28", "28")])
    func currencyCodeBindsAcrossAColonOrClosingParenthesis(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: ["AMD Ryzen 7 5800X", "EUR-Palette 1200 x 800 mm"])
    func currencyCodeAwayFromEveryNumberPricesNothing(transcript: String) {
        #expect(classifier.classify(transcript)?.isPrice != true)
    }

    @Test(arguments: ["TOP 10", "CUP 2", "ALL 50% OFF", "TRY 2 FREE", "SOS 112", "MOP 3"])
    func wordLikeCurrencyCodeBesideAPlainIntegerIsNotAPrice(transcript: String) {
        #expect(classifier.classify(transcript)?.isPrice != true)
    }

    @Test func wordLikeCurrencyCodeLeavesItsPlainIntegerAsAnOutline() throws {
        #expect(classifier.classify("CAD 12") == (try .outline("12")))
    }

    @Test(arguments: [("CAD 12.00", "12"), ("TRY 89,90", "89.9"), ("CAD 1,299", "1299")])
    func wordLikeCurrencyCodeBesideAMoneyShapedAmountIsAPrice(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [
        ("349 ₽", "349"), ("₴250", "250"), ("₱150", "150"), ("₦500", "500"), ("₸500", "500"), ("₾ 12", "12"),
        ("৳250", "250"), ("₨ 499", "499"), ("50圓", "50"),
    ])
    func regionalCurrencySymbolMarksAPrice(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [
        ("45 kr", "45"), ("45kr", "45"), ("kr 45", "45"), ("129 zł", "129"), ("15 lei", "15"), ("1299 Kč", "1299"),
        ("Rs. 499", "499"), ("Rs499", "499"), ("KSh500", "500"), ("Rp25.000", "25000"),
        ("45000đ", "45000"), ("45000 VNĐ", "45000"), ("30 лв", "30"), ("500 руб", "500"), ("250 грн", "250"),
    ])
    func localCurrencyWordMarksAPrice(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("120 บาท", "120"), ("5 euros", "5"), ("500 yen", "500"), ("20 dollars", "20")])
    func spelledOutCurrencyAfterTheNumberMarksAPrice(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: ["yen 500", "euros 5"])
    func spelledOutCurrencyBeforeTheNumberMarksNothing(transcript: String) {
        #expect(classifier.classify(transcript)?.isPrice != true)
    }

    @Test(arguments: [("12¢", "0.12"), ("99¢", "0.99")])
    func centSignDividesAWholeAmountByAHundred(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("149.9¢", "1.499"), ("12.5¢", "0.125")])
    func centSignDividesADecimalAmountByAHundred(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [
        ("RM 12", "MYR", "12"), ("49 TL", "TRY", "49"), ("Fr. 12.50", "CHF", "12.5"), ("SFr. 9.90", "CHF", "9.9"),
        ("KD 12", "KWD", "12"), ("BD 3", "BHD", "3"), ("JD 5", "JOD", "5"), ("15 DT", "TND", "15"),
        ("QR 20", "QAR", "20"), ("SR 25", "SAR", "25"), ("Dh 30", "AED", "30"), ("Dhs 30", "AED", "30"),
        ("Tk 250", "BDT", "250"), ("2500 Ft", "HUF", "2500"),
    ])
    func localWordMarksAPriceUnderItsBaseCurrency(transcript: String, base: CurrencyCode, amount: String) throws {
        let classifier = PriceClassifier(baseCurrency: base)
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("RM 12", "12"), ("49 TL", "49"), ("KD 12", "12")])
    func localWordIsPlainTextUnderAnotherBaseCurrency(transcript: String, amount: String) throws {
        let classifier = PriceClassifier(baseCurrency: .usd)
        #expect(classifier.classify(transcript) == (try .outline(amount)))
    }

    @Test(arguments: ["Mo 10 Di 11 Fr 12", "Fr 9-18"])
    func swissFrancWordNeedsAMoneyShapedAmount(transcript: String) {
        let classifier = PriceClassifier(baseCurrency: .chf)
        #expect(classifier.classify(transcript)?.isPrice != true)
    }

    @Test func swissFrancBindsADashPriceFollowedByText() throws {
        let classifier = PriceClassifier(baseCurrency: .chf)
        #expect(classifier.classify("Fr. 12.- inkl. Kaffee") == (try .price("12")))
    }

    @Test(arguments: ["Mo-Fr 9.00-18.30", "Mo\u{2013}Fr 9.00\u{2013}18.30"])
    func swissFrancWordBeforeAnHourRangeIsNotAPrice(transcript: String) {
        let classifier = PriceClassifier(baseCurrency: .chf)
        #expect(classifier.classify(transcript)?.isPrice != true)
    }

    @Test(arguments: [("RM12.90", "12.9"), ("Rp25.000", "25000")])
    func numberGluedToACurrencyWordSurvives(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("Hose 50 Ft $24.99", "24.99"), ("Ladder 6 Ft 3.99", "3.99")])
    func feetAbbreviationLeavesThePriceToTheRealAmount(transcript: String, amount: String) throws {
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test func kuaiMarksAPriceUnderTheYuan() throws {
        let classifier = PriceClassifier(baseCurrency: .cny)
        #expect(classifier.classify("28块") == (try .price("28")))
    }

    @Test(arguments: [("鸡翅 4块 25元", "25"), ("红烧肉 3块 38元", "38"), ("炸鸡块 6块 ¥18", "18")])
    func kuaiRanksBelowEveryOtherMarker(transcript: String, amount: String) throws {
        let classifier = PriceClassifier(baseCurrency: .cny)
        #expect(classifier.classify(transcript) == (try .price(amount)))
    }

    @Test(arguments: [("鸡翅 4块 25元", "25"), ("红烧肉 3块 38元", "38"), ("炸鸡块 6块 ¥18", "18")])
    func kuaiBesideAnotherMarkedPriceIsNotAPriceOfItsOwn(transcript: String, amount: String) throws {
        let classifier = PriceClassifier(baseCurrency: .cny)
        let expected = try #require(Decimal(string: amount))

        #expect(classifier.candidates(in: transcript).map(\.amount) == [expected])
    }

    @Test(arguments: [CurrencyCode.usd, .jpy])
    func kuaiIsAPieceCounterOutsideTheYuan(base: CurrencyCode) {
        let classifier = PriceClassifier(baseCurrency: base)
        #expect(classifier.classify("28块")?.isPrice != true)
    }

    @Test(arguments: ["Extension Cord 25 Ft", "Clearance 6 Ft 8 In"])
    func feetAbbreviationBesideAPlainIntegerIsNotAPrice(transcript: String) {
        #expect(classifier.classify(transcript)?.isPrice != true)
    }
}
