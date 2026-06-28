//
//  HistoryViewModelDisplayValues.swift
//  CurrencySpot
//

import Foundation

// Read-only chart statistics, formatted display strings, and chart configuration,
// all derived from the cached `chartStatistics`. Split out to keep HistoryViewModel
// focused on loading and state; every member here only reads already-published state.
extension HistoryViewModel {
    // MARK: - Statistics

    /// Current exchange rate (most recent data point)
    var currentRate: Double {
        chartStatistics.currentRate
    }

    /// Highest exchange rate in the current time range
    var highestRate: Double {
        chartStatistics.highestRate
    }

    /// Lowest exchange rate in the current time range
    var lowestRate: Double {
        chartStatistics.lowestRate
    }

    /// Average exchange rate in the current time range
    var averageRate: Double {
        chartStatistics.averageRate
    }

    /// Price change from first to last data point
    var priceChange: Double? {
        chartStatistics.priceChange
    }

    /// Percentage change from first to last data point
    var percentChange: Double? {
        chartStatistics.percentChange
    }

    /// Trend direction based on percentage change with stable threshold
    var trendDirection: TrendDirection {
        chartStatistics.trendDirection
    }

    /// Volatility (annualized standard deviation of returns)
    var volatility: Double? {
        chartStatistics.volatility
    }

    // MARK: - Formatted Display Values

    /// Formatted string for current exchange rate
    var formattedCurrentRate: String {
        "1 \(baseCurrency) = \(currentRate.toStringMax4Decimals) \(targetCurrency)"
    }

    /// Formatted string for highest exchange rate
    var formattedHighestRate: String {
        highestRate.toStringMax4Decimals
    }

    /// Formatted string for lowest exchange rate
    var formattedLowestRate: String {
        lowestRate.toStringMax4Decimals
    }

    /// Formatted string for average exchange rate
    var formattedAverageRate: String {
        averageRate.toStringMax4Decimals
    }

    /// Volatility classified into a qualitative level (nil when volatility is unavailable).
    var volatilityLevel: VolatilityLevel? {
        volatility.map(VolatilityLevel.init(annualizedPercent:))
    }

    /// Formatted string for volatility with interpretation
    var formattedVolatility: String {
        volatilityLevel?.displayName ?? "N/A"
    }

    // MARK: - Chart Configuration

    /// Y-axis domain for chart display with padding
    var chartYDomain: ClosedRange<Double> {
        chartStatistics.chartYDomain
    }
}
