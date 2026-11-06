import CoreGraphics
import Foundation
import Testing
@testable import CurrencySpot

struct ScanConversionUseCaseTests {
    private let useCase = ScanConversionUseCase()

    private let rates = [
        ExchangeRate(currencyCode: "JPY", rate: 150),
        ExchangeRate(currencyCode: "EUR", rate: 0.9),
        ExchangeRate(currencyCode: "USD", rate: 1),
    ]

    private func item(_ transcript: String, at originX: CGFloat = 0, width: CGFloat = 40) -> RecognizedTextItem {
        RecognizedTextItem(
            id: UUID(),
            transcript: transcript,
            bounds: CGRect(x: originX, y: 0, width: width, height: 10)
        )
    }

    private func detect(
        _ items: [RecognizedTextItem],
        base: CurrencyCode = "JPY",
        rates: [ExchangeRate]? = nil
    ) -> ScanConversionUseCase.DetectionResult {
        useCase.detect(
            in: items,
            baseCurrency: base,
            targetCurrency: "USD",
            exchangeRates: rates ?? self.rates
        )
    }

    private func glyphItem(_ transcript: String, width: CGFloat, numberSpan: ClosedRange<CGFloat>) -> RecognizedTextItem {
        let count = transcript.count
        let numberStart = count - 3
        let spans = (0..<count).map { offset -> ClosedRange<CGFloat> in
            guard offset >= numberStart else {
                let step = numberSpan.lowerBound / CGFloat(numberStart)
                return CGFloat(offset) * step...CGFloat(offset + 1) * step
            }
            let step = (numberSpan.upperBound - numberSpan.lowerBound) / 3
            let position = CGFloat(offset - numberStart)
            return numberSpan.lowerBound + position * step...numberSpan.lowerBound + (position + 1) * step
        }
        return RecognizedTextItem(
            id: UUID(),
            transcript: transcript,
            quad: Quad(CGRect(x: 0, y: 0, width: width, height: 10)),
            characterSpans: spans
        )
    }

    private func swallowingLine(inkGaps: [ClosedRange<CGFloat>]) -> RecognizedTextItem {
        let letters: [ClosedRange<CGFloat>] = [0...0.1, 0.1...0.2, 0.2...0.3, 0.3...0.4, 0.4...0.6]
        return RecognizedTextItem(
            id: UUID(),
            transcript: "Ramen ¥980",
            quad: Quad(CGRect(x: 0, y: 0, width: 100, height: 10)),
            characterSpans: letters + [0.13...0.13, 0.605...0.66, 0.66...0.77, 0.77...0.88, 0.88...1],
            inkGaps: inkGaps
        )
    }

    @Test func convertsAPriceFromBaseToTarget() throws {
        let result = detect([item("¥1,200")])

        let detected = try #require(result.items.first)
        #expect(detected.conversion == .init(amount: 1200, converted: 8, isPrice: true))
        #expect(result.foundPrices)
    }

    @Test func nonPriceStillCarriesAConversion() throws {
        let result = detect([item("1200")])

        let detected = try #require(result.items.first)
        #expect(detected.conversion == .init(amount: 1200, converted: 8, isPrice: false))
        #expect(result.foundPrices == false)
    }

    @Test func transcriptWithoutANumberIsIgnored() {
        let result = detect([item("Daily specials")])

        #expect(result.items.isEmpty)
        #expect(result.foundPrices == false)
    }

    @Test func conversionReflectsUpdatedRates() throws {
        let first = try #require(detect([item("¥1,200")]).items.first)
        #expect(first.conversion.converted == 8)

        let updatedRates = [
            ExchangeRate(currencyCode: "JPY", rate: 100),
            ExchangeRate(currencyCode: "USD", rate: 1),
        ]
        let second = try #require(detect([item("¥1,200")], rates: updatedRates).items.first)
        #expect(second.conversion.converted == 12)
    }

    @Test func classificationFollowsTheBaseCurrency() throws {
        let ringgit = item("RM 12")

        let underRinggit = try #require(detect([ringgit], base: "MYR").items.first)
        let underDollar = try #require(detect([ringgit], base: "USD").items.first)
        let underRinggitAgain = try #require(detect([ringgit], base: "MYR").items.first)

        #expect(underRinggit.conversion.isPrice)
        #expect(underDollar.conversion.isPrice == false)
        #expect(underRinggitAgain.conversion.isPrice)
    }

    @Test func numberBesideAStandaloneMarkerIsReadWithThatMarker() throws {
        let number = item("Combo 2 98", at: 0, width: 60)
        let result = detect([number, item("円", at: 64, width: 10)])

        let detected = try #require(result.items.first { $0.id == number.id })
        #expect(detected.conversion.amount == 98)
        #expect(detected.conversion.isPrice)
        #expect(detected.transcript == "Combo 2 98")
        #expect(result.foundPrices)
    }

    @Test func prefixMarkerIsReadBeforeTheNumber() throws {
        let number = item("680 Ramen", at: 14)
        let result = detect([item("¥", at: 0, width: 10), number])

        let detected = try #require(result.items.first { $0.id == number.id })
        #expect(detected.conversion.amount == 680)
        #expect(detected.conversion.isPrice)
    }

    @Test(arguments: [("Poutine 12", "$", "12"), ("Pad Thai 120", "฿", "120"), ("2 for 5", "$", "5")])
    func standaloneMarkerRightOfTheNumberIsReadAfterIt(transcript: String, glyph: String, amount: String) throws {
        let number = item(transcript, at: 0, width: 60)
        let result = detect([number, item(glyph, at: 64, width: 10)])

        let detected = try #require(result.items.first { $0.id == number.id })
        #expect(detected.conversion.amount == (try #require(Decimal(string: amount))))
        #expect(detected.conversion.isPrice)
    }

    @Test func standaloneMarkerLeftOfTheNumberIsReadBeforeIt() throws {
        let number = item("12 Pizza", at: 14, width: 60)
        let result = detect([item("€", at: 0, width: 10), number])

        let detected = try #require(result.items.first { $0.id == number.id })
        #expect(detected.conversion.amount == 12)
        #expect(detected.conversion.isPrice)
    }

    @Test func eachPriceOnALineGetsItsOwnItem() {
        let line = item("Was $12.99 Now $9.99", width: 200)

        let first = detect([line], base: "USD").items
        let second = detect([line], base: "USD").items

        #expect(first.map(\.conversion.amount) == [Decimal(string: "12.99"), Decimal(string: "9.99")])
        #expect(first.map(\.lineID) == [line.id, line.id])
        #expect(first.first?.id == line.id)
        #expect(first.last?.id != line.id)
        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test(arguments: [
        ("Small ¥500 Large ¥800", "JPY", ["Small ¥500", "Large ¥800"]),
        ("S $3.50 M $4.00 L $4.50", "USD", ["S $3.50", "M $4.00", "L $4.50"]),
        ("500円 / 800円", "JPY", ["500円", "800円"]),
    ])
    func eachPriceOnALineNamesItsOwnPartOfTheLine(transcript: String, base: CurrencyCode, names: [String]) {
        let result = detect([item(transcript, width: 200)], base: base)

        #expect(result.items.map(\.transcript) == names)
    }

    @Test(arguments: [
        ("780円(税込858円)", "JPY", ["780", "858"]),
        ("S $3.50 M $4.00 L $4.50", "USD", ["3.5", "4", "4.5"]),
    ])
    func everyPriceOnALineIsKept(transcript: String, base: CurrencyCode, amounts: [String]) {
        let result = detect([item(transcript, width: 200)], base: base)

        #expect(result.items.map(\.conversion.amount) == amounts.map { Decimal(string: $0) })
        #expect(Set(result.items.map(\.id)).count == amounts.count)
    }

    @Test func eachPriceSitsOverItsOwnToken() throws {
        let result = detect([item("Was $12.99 Now $9.99", width: 200)], base: "USD")

        let later = try #require(result.items.dropFirst().first)
        #expect(result.items.map(\.bounds.maxX) == [100, 200])
        #expect(result.items.map(\.bounds.minX).allSatisfy { $0 > 30 })
        #expect(later.bounds.minX > 140)
    }

    @Test func priceRemembersTheNameBesideItOnItsRow() throws {
        let name = item("Maguro", at: 0, width: 60)
        let price = item("¥680", at: 120, width: 40)

        let detected = try #require(detect([name, price]).items.first)

        #expect(detected.rowNeighbourCenter == name.quad.center)
    }

    @Test func tokenFollowsTheCharacterIndexWithoutMeasuredGlyphs() throws {
        let detected = try #require(detect([item("Edamame 350", width: 110)]).items.first)

        #expect(detected.bounds == CGRect(x: 80, y: 0, width: 30, height: 10))
    }

    @Test func wideCharactersTakeTwoSlotsInTheCharacterIndex() throws {
        let detected = try #require(detect([item("ラーメン 850", width: 120)]).items.first)

        #expect(detected.bounds == CGRect(x: 90, y: 0, width: 30, height: 10))
    }

    @Test func measuredGlyphsPlaceTheToken() throws {
        let line = glyphItem("Edamame 350", width: 100, numberSpan: 0.6...0.9)

        let detected = try #require(detect([line]).items.first)

        #expect(abs(detected.bounds.minX - 60) < 0.001)
        #expect(abs(detected.bounds.maxX - 90) < 0.001)
    }

    @Test func measuredSpacesDoNotStretchTheToken() throws {
        let word: ClosedRange<CGFloat> = 0...0.378
        let number: ClosedRange<CGFloat> = 0.401...0.824
        let space: ClosedRange<CGFloat> = -0.216...(-0.216)
        let line = RecognizedTextItem(
            id: UUID(),
            transcript: "Brot 2,49 €",
            quad: Quad(CGRect(x: 0, y: 0, width: 100, height: 10)),
            characterSpans: [word, word, word, word, space, number, number, number, number, space, 0.846...1]
        )

        let detected = try #require(detect([line], base: "EUR").items.first)

        #expect(abs(detected.bounds.minX - 40.1) < 0.001)
    }

    @Test func implausibleMeasuredGlyphsFallBackToTheCharacterIndex() throws {
        let line = glyphItem("Edamame 350", width: 110, numberSpan: 0...0.05)

        let detected = try #require(detect([line]).items.first)

        #expect(detected.bounds == CGRect(x: 80, y: 0, width: 30, height: 10))
    }

    @Test func markerSideReachesAcrossLeaderDotsToCoverTheWholeMarker() throws {
        let detected = try #require(detect([item("Curry ..¥1,200", width: 140)]).items.first)

        #expect(detected.bounds.minX == 76)
        #expect(detected.bounds.maxX == 140)
    }

    @Test func markerEdgeMovesToTheInkGapBeforeTheMarker() throws {
        let line = swallowingLine(inkGaps: [0.08...0.1, 0.53...0.57, 0.66...0.67])

        let detected = try #require(detect([line]).items.first)

        #expect(abs(detected.bounds.minX - 55) < 0.001)
    }

    @Test func inkEdgeNeverPullsTheTokenIntoItsMarker() throws {
        let line = RecognizedTextItem(
            id: UUID(),
            transcript: "Udon ¥1,050",
            quad: Quad(CGRect(x: 0, y: 0, width: 100, height: 10)),
            inkGaps: [0...1]
        )

        let detected = try #require(detect([line]).items.first)

        #expect(detected.bounds.minX <= 100 * 5 / 11 + 0.001)
    }

    @Test func inkGapBeyondTheMarkersReachIsIgnored() throws {
        let line = swallowingLine(inkGaps: [0.2...0.25])

        let detected = try #require(detect([line]).items.first)

        #expect(abs(detected.bounds.minX - 60) < 0.001)
    }

    @Test func trailingMarkerEdgeMovesToTheInkGapAfterIt() throws {
        let line = RecognizedTextItem(
            id: UUID(),
            transcript: "850円 Ramen",
            quad: Quad(CGRect(x: 0, y: 0, width: 100, height: 10)),
            characterSpans: [0...0.1, 0.1...0.2, 0.2...0.3, 0.3...0.36, 0.5...0.5, 0.36...0.5, 0.5...0.6, 0.6...0.7, 0.7...0.8, 0.8...1],
            inkGaps: [0.4...0.44]
        )

        let detected = try #require(detect([line]).items.first)

        #expect(abs(detected.bounds.maxX - 42) < 0.001)
    }

    @Test func markerSideStopsAtTheLetterBeforeIt() throws {
        let detected = try #require(detect([item("定食¥1,050", width: 100)]).items.first)

        #expect(detected.bounds.minX == 40)
    }

    @Test func lineTextOutsideThePriceIsKeptAsObstacles() throws {
        let detected = try #require(detect([item("Ramen ¥980", width: 100)]).items.first)

        #expect(detected.lineTextQuads.map(\.boundingBox) == [CGRect(x: 0, y: 0, width: 50, height: 10)])
    }

    @Test func standaloneMarkerPriceSitsOverTheNumbersOwnLine() throws {
        let number = item("980", at: 14, width: 30)
        let result = detect([item("¥", at: 0, width: 10), number])

        let detected = try #require(result.items.first { $0.lineID == number.id })
        #expect(detected.bounds == number.bounds)
    }

    @Test func alternateReadingWithACurrencyGlyphRescuesAPrice() throws {
        let line = RecognizedTextItem(
            id: UUID(),
            transcript: "B4.50",
            quad: Quad(CGRect(x: 0, y: 0, width: 50, height: 10)),
            alternateTranscripts: ["$4.50"]
        )

        let detected = try #require(detect([line], base: "USD").items.first)

        #expect(detected.conversion.isPrice)
        #expect(detected.conversion.amount == Decimal(string: "4.5"))
        #expect(detected.transcript == "B4.50")
    }

    @Test(arguments: ["$4.80", "$4.50 off", "B$4.5"])
    func alternateReadingThatChangesMoreThanAGlyphIsIgnored(alternate: String) {
        let line = RecognizedTextItem(
            id: UUID(),
            transcript: "B4.50",
            quad: Quad(CGRect(x: 0, y: 0, width: 50, height: 10)),
            alternateTranscripts: [alternate]
        )

        let result = detect([line], base: "USD")

        #expect(result.foundPrices == false)
    }

    @Test(arguments: [
        ("¥615/kg", "JPY", "/kg"),
        ("Äpfel 1.5 kg €3,49/kg", "EUR", "/kg"),
        ("Beef ¥300 / 100 g", "JPY", "/100g"),
        ("Cola $2/pc", "USD", "/pc"),
    ])
    func perUnitSuffixFollowsThePrice(transcript: String, base: CurrencyCode, suffix: String) throws {
        let detected = try #require(detect([item(transcript, width: 200)], base: base).items.first)

        #expect(detected.perUnitSuffix == suffix)
    }

    @Test(arguments: ["Coke $2", "Beer ¥600 /lunch", "Tea ¥300 / day"])
    func priceWithoutAUnitHasNoSuffix(transcript: String) throws {
        let detected = try #require(detect([item(transcript, width: 200)]).items.first)

        #expect(detected.perUnitSuffix == nil)
    }

    @Test func standaloneMarkerThatCannotReachTheNumberLeavesAnOutline() throws {
        let number = item("No. 12", at: 14)
        let result = detect([item("¥", at: 0, width: 10), number])

        let detected = try #require(result.items.first { $0.id == number.id })
        #expect(detected.conversion.isPrice == false)
        #expect(result.foundPrices == false)
    }
}
