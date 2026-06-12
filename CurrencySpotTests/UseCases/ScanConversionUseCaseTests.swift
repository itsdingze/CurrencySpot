//
//  ScanConversionUseCaseTests.swift
//  CurrencySpotTests
//

import Foundation
import Testing
@testable import CurrencySpot

struct ScanConversionUseCaseTests {
    private let useCase = ScanConversionUseCase()

    /// USD-normalized rates, as served by the data layer.
    private let rates = [
        ExchangeRate(currencyCode: "JPY", rate: 150),
        ExchangeRate(currencyCode: "EUR", rate: 0.9),
        ExchangeRate(currencyCode: "USD", rate: 1),
    ]

    @Test func convertsAPriceFromBaseToTarget() {
        let result = useCase.evaluate(
            transcript: "¥1,200",
            baseCurrency: "JPY",
            targetCurrency: "USD",
            exchangeRates: rates
        )
        #expect(result == .init(amount: 1200, converted: 8, isPrice: true))
    }

    /// Non-prices keep a conversion so tap-to-convert (the user override) works.
    @Test func nonPriceStillCarriesAConversion() {
        let result = useCase.evaluate(
            transcript: "1200",
            baseCurrency: "JPY",
            targetCurrency: "USD",
            exchangeRates: rates
        )
        #expect(result == .init(amount: 1200, converted: 8, isPrice: false))
    }

    @Test func transcriptWithoutANumberIsIgnored() {
        let result = useCase.evaluate(
            transcript: "Daily specials",
            baseCurrency: "JPY",
            targetCurrency: "USD",
            exchangeRates: rates
        )
        #expect(result == nil)
    }
}
