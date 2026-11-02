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

    @Test func standaloneMarkerThatCannotReachTheNumberLeavesAnOutline() throws {
        let number = item("No. 12", at: 14)
        let result = detect([item("¥", at: 0, width: 10), number])

        let detected = try #require(result.items.first { $0.id == number.id })
        #expect(detected.conversion.isPrice == false)
        #expect(result.foundPrices == false)
    }
}
