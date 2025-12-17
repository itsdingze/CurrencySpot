//
//  RateCalculationUseCase.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation

// MARK: - RateCalculationUseCase

/// Use case responsible for currency rate calculation business logic
/// Pure business logic without UI dependencies
final class RateCalculationUseCase {
    // MARK: - Initialization

    init() {}

    // MARK: - Currency Conversion

    /// Converts a USD-based rate to a different base currency rate
    /// - Parameters:
    ///   - usdToTargetRate: The USD to target currency rate
    ///   - fromBaseCurrency: The desired base currency
    ///   - toTargetCurrency: The target currency
    ///   - historicalRates: Optional historical rates from the same date (preferred)
    ///   - exchangeRates: Current exchange rates data (fallback)
    /// - Returns: The converted rate from base to target currency
    func convertRate(
        usdToTargetRate: Double,
        fromBaseCurrency: String,
        toTargetCurrency _: String,
        historicalRates: [HistoricalRateDataPointValue]? = nil,
        exchangeRates: [ExchangeRateDataValue]
    ) -> Double {
        // If base is USD, no conversion needed
        guard fromBaseCurrency != "USD" else { return usdToTargetRate }

        // Try to use historical rates first if available
        if let historicalRates,
           let baseRate = historicalRates.first(where: { $0.currencyCode == fromBaseCurrency })
        {
            // Use historical rates from the same date
            // Formula: (USD → Target) / (USD → Base) = Base → Target
            return abs(baseRate.rate) > Double.ulpOfOne ? usdToTargetRate / baseRate.rate : usdToTargetRate
        }

        // Fallback: Get current exchange rate for base currency
        guard let usdToBaseRate = exchangeRates.first(where: { $0.currencyCode == fromBaseCurrency })?.rate else {
            // Fallback to original rate if conversion not available
            return usdToTargetRate
        }

        // Convert: (USD → Target) / (USD → Base) = Base → Target
        // Protect against division by zero or near-zero values
        return abs(usdToBaseRate) > Double.ulpOfOne ? usdToTargetRate / usdToBaseRate : usdToTargetRate
    }
}
