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

    private func item(_ transcript: String, at originX: CGFloat = 0) -> RecognizedTextItem {
        RecognizedTextItem(
            id: UUID(),
            transcript: transcript,
            bounds: CGRect(x: originX, y: 0, width: 40, height: 10)
        )
    }

    private func detect(
        _ items: [RecognizedTextItem],
        rates: [ExchangeRate]? = nil
    ) -> ScanConversionUseCase.DetectionResult {
        useCase.detect(
            in: items,
            baseCurrency: "JPY",
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
}
