//
//  RateCalculationUseCaseTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 8/1/25.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Rate Calculation Use Case Tests")
@MainActor
struct RateCalculationUseCaseTests {
    // MARK: - Test Data Constants

    private static let standardUSDRate = 1.0
    private static let eurToUSDRate = 1.21
    private static let gbpToUSDRate = 0.85
    private static let jpyToUSDRate = 110.0
    private static let usdToEURRate = 1.21 // USD → EUR
    private static let usdToGBPRate = 0.85 // USD → GBP
    private static let usdToJPYRate = 110.0 // USD → JPY

    // MARK: - Test Helpers

    /// Creates standard test exchange rates (USD-based rates)
    private func createStandardExchangeRates() -> [ExchangeRateDataValue] {
        [
            ExchangeRateDataValue(currencyCode: "EUR", rate: Self.eurToUSDRate),
            ExchangeRateDataValue(currencyCode: "GBP", rate: Self.gbpToUSDRate),
            ExchangeRateDataValue(currencyCode: "JPY", rate: Self.jpyToUSDRate),
        ]
    }

    // MARK: - Business Rule Tests: USD Base Currency

    @Test("When base currency is USD, should return original rate unchanged")
    func whenBaseCurrencyIsUSD_shouldReturnOriginalRate() {
        // GIVEN: A use case and standard exchange rates
        let exchangeRates = createStandardExchangeRates()
        let useCase = RateCalculationUseCase()
        let originalRate = 1.85

        // WHEN: Converting with USD as base currency
        let result = useCase.convertRate(
            usdToTargetRate: originalRate,
            fromBaseCurrency: "USD",
            toTargetCurrency: "EUR",
            exchangeRates: exchangeRates
        )

        // THEN: Should return the original rate unchanged
        #expect(result == originalRate)
    }

    @Test("When base currency is USD with zero rate, should return zero")
    func whenBaseCurrencyIsUSDWithZeroRate_shouldReturnZero() {
        // GIVEN: A use case with zero USD rate
        let exchangeRates: [ExchangeRateDataValue] = []
        let useCase = RateCalculationUseCase()
        let zeroRate = 0.0

        // WHEN: Converting with USD as base currency
        let result = useCase.convertRate(
            usdToTargetRate: zeroRate,
            fromBaseCurrency: "USD",
            toTargetCurrency: "EUR",
            exchangeRates: exchangeRates
        )

        // THEN: Should return zero
        #expect(result == 0.0)
    }

    @Test("When base currency is USD with very large rate, should return same large rate")
    func whenBaseCurrencyIsUSDWithVeryLargeRate_shouldReturnSameLargeRate() {
        // GIVEN: A use case with very large USD rate
        let exchangeRates: [ExchangeRateDataValue] = []
        let useCase = RateCalculationUseCase()
        let largeRate = 1_000_000.0

        // WHEN: Converting with USD as base currency
        let result = useCase.convertRate(
            usdToTargetRate: largeRate,
            fromBaseCurrency: "USD",
            toTargetCurrency: "EUR",
            exchangeRates: exchangeRates
        )

        // THEN: Should return the same large rate
        #expect(result == largeRate)
    }

    // MARK: - Business Rule Tests: Non-USD Base Currency with Available Rate

    @Test("When base currency is EUR and rate available, should convert correctly using division")
    func whenBaseCurrencyIsEURWithAvailableRate_shouldConvertCorrectly() {
        // GIVEN: A use case with EUR exchange rate available
        let exchangeRates = createStandardExchangeRates()
        let useCase = RateCalculationUseCase()
        let usdToTargetRate = 0.85 // USD → GBP

        // WHEN: Converting from EUR to GBP
        let result = useCase.convertRate(
            usdToTargetRate: usdToTargetRate,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: exchangeRates
        )

        // THEN: Should convert using division: (USD → GBP) / (USD → EUR) = EUR → GBP
        let expected = usdToTargetRate / Self.eurToUSDRate // 0.85 / 1.21 ≈ 0.7024
        #expect(abs(result - expected) < 0.0001, "Expected \(expected), got \(result)")
    }

    @Test("When base currency is GBP and rate available, should convert correctly")
    func whenBaseCurrencyIsGBPWithAvailableRate_shouldConvertCorrectly() {
        // GIVEN: A use case with GBP exchange rate available
        let exchangeRates = createStandardExchangeRates()
        let useCase = RateCalculationUseCase()
        let usdToTargetRate = 110.0 // USD → JPY

        // WHEN: Converting from GBP to JPY
        let result = useCase.convertRate(
            usdToTargetRate: usdToTargetRate,
            fromBaseCurrency: "GBP",
            toTargetCurrency: "JPY",
            exchangeRates: exchangeRates
        )

        // THEN: Should convert using division: (USD → JPY) / (USD → GBP) = GBP → JPY
        let expected = usdToTargetRate / Self.gbpToUSDRate // 110.0 / 0.85 ≈ 129.41
        #expect(abs(result - expected) < 0.01, "Expected \(expected), got \(result)")
    }

    @Test("When base currency is JPY and rate available, should convert correctly")
    func whenBaseCurrencyIsJPYWithAvailableRate_shouldConvertCorrectly() {
        // GIVEN: A use case with JPY exchange rate available
        let exchangeRates = createStandardExchangeRates()
        let useCase = RateCalculationUseCase()
        let usdToTargetRate = 1.21 // USD → EUR

        // WHEN: Converting from JPY to EUR
        let result = useCase.convertRate(
            usdToTargetRate: usdToTargetRate,
            fromBaseCurrency: "JPY",
            toTargetCurrency: "EUR",
            exchangeRates: exchangeRates
        )

        // THEN: Should convert using division: (USD → EUR) / (USD → JPY) = JPY → EUR
        let expected = usdToTargetRate / Self.jpyToUSDRate // 1.21 / 110.0 ≈ 0.011
        #expect(abs(result - expected) < 0.0001, "Expected \(expected), got \(result)")
    }

    // MARK: - Business Rule Tests: Fallback Behavior

    @Test("When exchange rates not loaded, should fallback to original rate")
    func whenExchangeRatesNotLoaded_shouldFallbackToOriginalRate() {
        // GIVEN: A use case with no exchange rates loaded
        let exchangeRates: [ExchangeRateDataValue] = []
        let useCase = RateCalculationUseCase()
        let originalRate = 1.85

        // WHEN: Converting with non-USD base currency
        let result = useCase.convertRate(
            usdToTargetRate: originalRate,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: exchangeRates
        )

        // THEN: Should fallback to original rate
        #expect(result == originalRate)
    }

    @Test("When base currency rate not available, should fallback to original rate")
    func whenBaseCurrencyRateNotAvailable_shouldFallbackToOriginalRate() {
        // GIVEN: A use case with exchange rates that don't include the base currency
        let exchangeRates = [
            ExchangeRateDataValue(currencyCode: "EUR", rate: 1.21),
            ExchangeRateDataValue(currencyCode: "GBP", rate: 0.85),
        ]
        let useCase = RateCalculationUseCase()
        let originalRate = 2.34

        // WHEN: Converting with CAD (not in available rates)
        let result = useCase.convertRate(
            usdToTargetRate: originalRate,
            fromBaseCurrency: "CAD",
            toTargetCurrency: "EUR",
            exchangeRates: exchangeRates
        )

        // THEN: Should fallback to original rate
        #expect(result == originalRate)
    }

    @Test("When exchange rates are empty, should fallback to original rate")
    func whenExchangeRatesAreEmpty_shouldFallbackToOriginalRate() {
        // GIVEN: A use case with empty exchange rates
        let exchangeRates: [ExchangeRateDataValue] = []
        let useCase = RateCalculationUseCase()
        let originalRate = 3.45

        // WHEN: Converting with any non-USD base currency
        let result = useCase.convertRate(
            usdToTargetRate: originalRate,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: exchangeRates
        )

        // THEN: Should fallback to original rate
        #expect(result == originalRate)
    }

    // MARK: - Edge Case Tests: Zero and Extreme Values

    @Test("When USD to target rate is zero, should return zero for USD base")
    func whenUSDToTargetRateIsZero_shouldReturnZeroForUSDBase() {
        // GIVEN: A use case with zero USD rate
        let exchangeRates = createStandardExchangeRates()
        let useCase = RateCalculationUseCase()

        // WHEN: Converting with zero rate and USD base
        let result = useCase.convertRate(
            usdToTargetRate: 0.0,
            fromBaseCurrency: "USD",
            toTargetCurrency: "EUR",
            exchangeRates: exchangeRates
        )

        // THEN: Should return zero
        #expect(result == 0.0)
    }

    @Test("When USD to target rate is zero with non-USD base, should return zero")
    func whenUSDToTargetRateIsZeroWithNonUSDBase_shouldReturnZero() {
        // GIVEN: A use case with available exchange rates
        let exchangeRates = createStandardExchangeRates()
        let useCase = RateCalculationUseCase()

        // WHEN: Converting with zero rate and EUR base
        let result = useCase.convertRate(
            usdToTargetRate: 0.0,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: exchangeRates
        )

        // THEN: Should return zero (0.0 / 1.21 = 0.0)
        #expect(result == 0.0)
    }

    @Test("When base currency rate is zero, should return original rate as fallback")
    func whenBaseCurrencyRateIsZero_shouldReturnOriginalRateAsFallback() {
        // GIVEN: A use case with zero rate for base currency
        let exchangeRates = [
            ExchangeRateDataValue(currencyCode: "EUR", rate: 0.0),
            ExchangeRateDataValue(currencyCode: "GBP", rate: 0.85),
        ]
        let useCase = RateCalculationUseCase()
        let originalRate = 0.85

        // WHEN: Converting with EUR (zero rate) as base
        let result = useCase.convertRate(
            usdToTargetRate: originalRate,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: exchangeRates
        )

        // THEN: Should return original rate as safe fallback (not infinity)
        #expect(result == originalRate)
        #expect(result.isFinite)
    }

    @Test("When dealing with very small numbers, should maintain precision")
    func whenDealingWithVerySmallNumbers_shouldMaintainPrecision() {
        // GIVEN: A use case with very small exchange rates
        let verySmallRate = 0.000001
        let exchangeRates = [
            ExchangeRateDataValue(currencyCode: "MICRO", rate: verySmallRate),
        ]
        let useCase = RateCalculationUseCase()
        let usdToTargetRate = 0.000002

        // WHEN: Converting with very small numbers
        let result = useCase.convertRate(
            usdToTargetRate: usdToTargetRate,
            fromBaseCurrency: "MICRO",
            toTargetCurrency: "TARGET",
            exchangeRates: exchangeRates
        )

        // THEN: Should calculate correctly: 0.000002 / 0.000001 = 2.0
        let expected = usdToTargetRate / verySmallRate
        #expect(abs(result - expected) < 0.000001, "Expected \(expected), got \(result)")
    }

    @Test("When dealing with very large numbers, should handle correctly")
    func whenDealingWithVeryLargeNumbers_shouldHandleCorrectly() {
        // GIVEN: A use case with very large exchange rates
        let veryLargeRate = 1_000_000.0
        let exchangeRates = [
            ExchangeRateDataValue(currencyCode: "LARGE", rate: veryLargeRate),
        ]
        let useCase = RateCalculationUseCase()
        let usdToTargetRate = 2_000_000.0

        // WHEN: Converting with very large numbers
        let result = useCase.convertRate(
            usdToTargetRate: usdToTargetRate,
            fromBaseCurrency: "LARGE",
            toTargetCurrency: "TARGET",
            exchangeRates: exchangeRates
        )

        // THEN: Should calculate correctly: 2,000,000 / 1,000,000 = 2.0
        let expected = usdToTargetRate / veryLargeRate
        #expect(result == expected, "Expected \(expected), got \(result)")
    }

    // MARK: - Precision Tests

    @Test("When performing division, should maintain double precision")
    func whenPerformingDivision_shouldMaintainDoublePrecision() {
        // GIVEN: A use case with precise exchange rates
        let preciseRate = 1.234567890123456
        let exchangeRates = [
            ExchangeRateDataValue(currencyCode: "PRECISE", rate: preciseRate),
        ]
        let useCase = RateCalculationUseCase()
        let usdToTargetRate = 2.345678901234567

        // WHEN: Converting with precise numbers
        let result = useCase.convertRate(
            usdToTargetRate: usdToTargetRate,
            fromBaseCurrency: "PRECISE",
            toTargetCurrency: "TARGET",
            exchangeRates: exchangeRates
        )

        // THEN: Should maintain precision in calculation
        let expected = usdToTargetRate / preciseRate
        #expect(abs(result - expected) < Double.ulpOfOne * 10, "Expected \(expected), got \(result)")
    }

    @Test("When result is very small due to division, should not underflow to zero")
    func whenResultIsVerySmallDueToDivision_shouldNotUnderflowToZero() {
        // GIVEN: A use case where division results in very small number
        let largeBaseRate = 1_000_000_000.0
        let exchangeRates = [
            ExchangeRateDataValue(currencyCode: "HUGE", rate: largeBaseRate),
        ]
        let useCase = RateCalculationUseCase()
        let smallTargetRate = 0.000000001

        // WHEN: Dividing very small by very large
        let result = useCase.convertRate(
            usdToTargetRate: smallTargetRate,
            fromBaseCurrency: "HUGE",
            toTargetCurrency: "TARGET",
            exchangeRates: exchangeRates
        )

        // THEN: Should not underflow to zero
        #expect(result > 0.0, "Result should be greater than zero")
        #expect(result.isFinite, "Result should be finite")
    }

    // MARK: - Boundary Condition Tests

    @Test("When currency codes are empty strings, should handle gracefully")
    func whenCurrencyCodesAreEmptyStrings_shouldHandleGracefully() {
        // GIVEN: A use case with exchange rates including empty currency code
        let exchangeRates = [
            ExchangeRateDataValue(currencyCode: "", rate: 1.21),
        ]
        let useCase = RateCalculationUseCase()
        let originalRate = 1.85

        // WHEN: Converting with empty base currency code
        let result = useCase.convertRate(
            usdToTargetRate: originalRate,
            fromBaseCurrency: "",
            toTargetCurrency: "EUR",
            exchangeRates: exchangeRates
        )

        // THEN: Should use the exchange rate if found, otherwise fallback
        let expected = originalRate / 1.21
        #expect(abs(result - expected) < 0.0001, "Expected \(expected), got \(result)")
    }

    @Test("When target currency parameter is irrelevant to calculation, should ignore it")
    func whenTargetCurrencyParameterIsIrrelevant_shouldIgnoreIt() {
        // GIVEN: A use case with available exchange rates
        let exchangeRates = createStandardExchangeRates()
        let useCase = RateCalculationUseCase()
        let usdToTargetRate = 0.85

        // WHEN: Converting with any target currency (should not affect calculation)
        let result1 = useCase.convertRate(
            usdToTargetRate: usdToTargetRate,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: exchangeRates
        )
        let result2 = useCase.convertRate(
            usdToTargetRate: usdToTargetRate,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "IRRELEVANT",
            exchangeRates: exchangeRates
        )

        // THEN: Results should be identical (target currency doesn't affect calculation)
        #expect(result1 == result2, "Target currency should not affect calculation")
    }

    // MARK: - Real-world Scenario Tests

    @Test("Converting EUR to GBP through USD should match real-world expectations")
    func convertingEURToGBPThroughUSD_shouldMatchRealWorldExpectations() {
        // GIVEN: Real-world-like exchange rates
        let exchangeRates = [
            ExchangeRateDataValue(currencyCode: "EUR", rate: 1.08), // 1 USD = 1.08 EUR
            ExchangeRateDataValue(currencyCode: "GBP", rate: 0.79), // 1 USD = 0.79 GBP
        ]
        let useCase = RateCalculationUseCase()
        let usdToGBPRate = 0.79

        // WHEN: Converting EUR to GBP
        let result = useCase.convertRate(
            usdToTargetRate: usdToGBPRate,
            fromBaseCurrency: "EUR",
            toTargetCurrency: "GBP",
            exchangeRates: exchangeRates
        )

        // THEN: Should calculate EUR to GBP rate correctly
        let expected = usdToGBPRate / 1.08 // 0.79 / 1.08 ≈ 0.731
        #expect(abs(result - expected) < 0.001, "Expected ~0.731, got \(result)")
        #expect(result < 1.0, "EUR to GBP should be less than 1 in this scenario")
    }

    @Test("Multiple conversions with same parameters should produce consistent results")
    func multipleConversionsWithSameParameters_shouldProduceConsistentResults() {
        // GIVEN: A use case with stable exchange rates
        let exchangeRates = createStandardExchangeRates()
        let useCase = RateCalculationUseCase()
        let usdToTargetRate = 1.21

        // WHEN: Performing multiple conversions with same parameters
        let results = (1 ... 10).map { _ in
            useCase.convertRate(
                usdToTargetRate: usdToTargetRate,
                fromBaseCurrency: "EUR",
                toTargetCurrency: "GBP",
                exchangeRates: exchangeRates
            )
        }

        // THEN: All results should be identical
        let firstResult = results.first!
        for result in results {
            #expect(result == firstResult, "All conversions should produce identical results")
        }
    }
}
