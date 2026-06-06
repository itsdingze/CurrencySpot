//
//  RateCalculationUseCaseTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 8/1/25.
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("Rate Calculation Use Case Tests")
struct RateCalculationUseCaseTests {
    // Rates are USD-based: value means "1 USD = value units of the currency".
    private static let usdToEUR = 1.21
    private static let usdToGBP = 0.85
    private static let usdToJPY = 110.0

    private let useCase = RateCalculationUseCase()

    private func standardExchangeRates() -> [ExchangeRateDataValue] {
        [
            ExchangeRateDataValue(currencyCode: "EUR", rate: Self.usdToEUR),
            ExchangeRateDataValue(currencyCode: "GBP", rate: Self.usdToGBP),
            ExchangeRateDataValue(currencyCode: "JPY", rate: Self.usdToJPY),
        ]
    }

    // MARK: - USD base: rate is returned unchanged

    @Test("USD base returns the USD->target rate unchanged", arguments: [0.0, 1.85, 1_000_000.0])
    func usdBaseReturnsRateUnchanged(rate: Double) {
        let result = useCase.convertRate(
            usdToTargetRate: rate,
            fromBaseCurrency: "USD",
            toTargetCurrency: "EUR",
            exchangeRates: standardExchangeRates()
        )
        #expect(result == rate)
    }

    // MARK: - Non-USD base with available rate: Base->Target = (USD->Target) / (USD->Base)

    @Test("EUR base, GBP target divides USD->GBP by USD->EUR")
    func eurBaseGbpTarget() {
        let result = useCase.convertRate(
            usdToTargetRate: Self.usdToGBP, // USD -> GBP
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: standardExchangeRates()
        )
        // 0.85 / 1.21 = 0.70247933...
        #expect(abs(result - 0.7024793) < 0.0001)
    }

    @Test("GBP base, JPY target divides USD->JPY by USD->GBP")
    func gbpBaseJpyTarget() {
        let result = useCase.convertRate(
            usdToTargetRate: Self.usdToJPY, // USD -> JPY
            fromBaseCurrency: "GBP",
            toTargetCurrency: "JPY",
            exchangeRates: standardExchangeRates()
        )
        // 110.0 / 0.85 = 129.41176...
        #expect(abs(result - 129.41176) < 0.01)
    }

    @Test("JPY base, EUR target divides USD->EUR by USD->JPY")
    func jpyBaseEurTarget() {
        let result = useCase.convertRate(
            usdToTargetRate: Self.usdToEUR, // USD -> EUR
            fromBaseCurrency: "JPY",
            toTargetCurrency: "EUR",
            exchangeRates: standardExchangeRates()
        )
        // 1.21 / 110.0 = 0.011
        #expect(abs(result - 0.011) < 0.0001)
    }

    @Test("Realistic EUR->GBP cross rate is below 1 and matches the hand computation")
    func realisticEurToGbp() {
        let rates = [
            ExchangeRateDataValue(currencyCode: "EUR", rate: 1.08), // 1 USD = 1.08 EUR
            ExchangeRateDataValue(currencyCode: "GBP", rate: 0.79), // 1 USD = 0.79 GBP
        ]
        let result = useCase.convertRate(
            usdToTargetRate: 0.79,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: rates
        )
        // 0.79 / 1.08 = 0.731481...
        #expect(abs(result - 0.731481) < 0.0001)
        #expect(result < 1.0)
    }

    // MARK: - Historical rates path (preferred over current exchange rates)

    @Test("Historical base rate is preferred over the current exchange rate")
    func historicalRatePreferredOverExchange() {
        // Same base present in both; historical (1.5) must win over exchange (1.21).
        let historical = [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.5)]
        let result = useCase.convertRate(
            usdToTargetRate: 3.0,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            historicalRates: historical,
            exchangeRates: standardExchangeRates() // EUR = 1.21 here, must be ignored
        )
        // 3.0 / 1.5 = 2.0 (historical), NOT 3.0 / 1.21 = 2.479 (exchange)
        #expect(abs(result - 2.0) < 0.0001)
    }

    @Test("Falls through to exchange rates when the base is absent from historical rates")
    func historicalMissingBaseFallsThroughToExchange() {
        let historical = [HistoricalRateDataPointValue(currencyCode: "GBP", rate: 0.9)] // no EUR
        let result = useCase.convertRate(
            usdToTargetRate: Self.usdToEUR,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            historicalRates: historical,
            exchangeRates: standardExchangeRates() // EUR = 1.21
        )
        // 1.21 / 1.21 = 1.0 via the exchange-rate fallback
        #expect(abs(result - 1.0) < 0.0001)
    }

    @Test("Near-zero historical base rate falls back to the original rate (no divide-by-zero)")
    func historicalZeroBaseRateFallsBack() {
        let historical = [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 0.0)]
        let result = useCase.convertRate(
            usdToTargetRate: 2.5,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            historicalRates: historical,
            exchangeRates: standardExchangeRates()
        )
        #expect(result == 2.5)
        #expect(result.isFinite)
    }

    // MARK: - Fallback behavior (no usable base rate)

    @Test("Non-USD base with no exchange rates returns the original rate")
    func noExchangeRatesFallsBack() {
        let result = useCase.convertRate(
            usdToTargetRate: 1.85,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: []
        )
        #expect(result == 1.85)
    }

    @Test("Base currency missing from exchange rates returns the original rate")
    func missingBaseCurrencyFallsBack() {
        let result = useCase.convertRate(
            usdToTargetRate: 2.34,
            fromBaseCurrency: "CAD", // not present
            toTargetCurrency: "EUR",
            exchangeRates: standardExchangeRates()
        )
        #expect(result == 2.34)
    }

    @Test("Zero USD->target with non-USD base yields zero")
    func zeroTargetRateNonUsdBase() {
        let result = useCase.convertRate(
            usdToTargetRate: 0.0,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: standardExchangeRates()
        )
        #expect(result == 0.0) // 0.0 / 1.21
    }

    @Test("Zero base rate falls back to original rate instead of producing infinity")
    func zeroBaseRateFallsBack() {
        let rates = [
            ExchangeRateDataValue(currencyCode: "EUR", rate: 0.0),
            ExchangeRateDataValue(currencyCode: "GBP", rate: 0.85),
        ]
        let result = useCase.convertRate(
            usdToTargetRate: 0.85,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: rates
        )
        #expect(result == 0.85)
        #expect(result.isFinite)
    }

    // MARK: - Magnitude / precision

    @Test("Division with extreme magnitudes is exact and does not underflow to zero")
    func extremeMagnitudeDivision() {
        let rates = [ExchangeRateDataValue(currencyCode: "HUGE", rate: 1_000_000_000.0)]
        let result = useCase.convertRate(
            usdToTargetRate: 0.000_000_001,
            fromBaseCurrency: "HUGE",
            toTargetCurrency: "TARGET",
            exchangeRates: rates
        )
        // 1e-9 / 1e9 = 1e-18 exactly representable region; must not flush to zero.
        #expect(abs(result - 1e-18) < 1e-24)
        #expect(result > 0.0)
        #expect(result.isFinite)
    }

    @Test("Target currency argument does not affect the computed cross rate")
    func targetCurrencyArgumentIsIgnored() {
        let gbp = useCase.convertRate(
            usdToTargetRate: 0.85, fromBaseCurrency: "EUR", toTargetCurrency: "GBP",
            exchangeRates: standardExchangeRates()
        )
        let irrelevant = useCase.convertRate(
            usdToTargetRate: 0.85, fromBaseCurrency: "EUR", toTargetCurrency: "IRRELEVANT",
            exchangeRates: standardExchangeRates()
        )
        #expect(gbp == irrelevant)
    }
}
