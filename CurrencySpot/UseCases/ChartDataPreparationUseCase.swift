//
//  ChartDataPreparationUseCase.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation

// MARK: - ChartDataPreparationUseCase

/// Use case responsible for chart data preparation and processing
/// Extracted from HistoryViewModel to separate concerns
final class ChartDataPreparationUseCase {
    // MARK: - Dependencies

    private let rateCalculationUseCase: RateCalculationUseCase
    private let cacheService: CacheService

    // MARK: - Initialization

    init(rateCalculationUseCase: RateCalculationUseCase, cacheService: CacheService) {
        self.rateCalculationUseCase = rateCalculationUseCase
        self.cacheService = cacheService
    }

    // MARK: - Chart Data Processing

    /// Processes historical rate data for the specified currency pair within the given time range
    @MainActor
    func processHistoricalRateData(
        historicalData: [HistoricalRateDataValue],
        baseCurrency: String,
        targetCurrency: String,
        dateRange: DateRange,
        exchangeRates: [ExchangeRateDataValue]
    ) async -> [ChartDataPoint] {
        // Generate cache key for this specific configuration
        let cacheKey = "\(baseCurrency)-\(targetCurrency)-\(dateRange.start.timeIntervalSince1970)-\(dateRange.end.timeIntervalSince1970)"

        // Check cache first
        if let cachedData = await cacheService.getCachedProcessedChartData(for: cacheKey) {
            AppLogger.debug("Using cached processed chart data for \(baseCurrency) to \(targetCurrency)", category: .cache)
            return cachedData
        }
        // Process data in batches to allow UI updates
        var chartPoints: [ChartDataPoint] = []
        chartPoints.reserveCapacity(historicalData.count)

        for (index, historicalEntry) in historicalData.enumerated() {
            // Yield control every 50 items to prevent UI blocking
            if index % 50 == 0 {
                await Task.yield()
            }

            let date = historicalEntry.date

            guard date >= dateRange.start, date <= dateRange.end else {
                continue
            }

            // Get target rate
            let targetRate: Double
            if targetCurrency == "USD" {
                targetRate = 1.0
            } else {
                guard let rate = historicalEntry.rates.first(where: { $0.currencyCode == targetCurrency }) else {
                    continue
                }
                targetRate = rate.rate
            }

            // IMPORTANT: Use historical rates for base currency conversion, not current rates
            let convertedRate: Double
            if baseCurrency == "USD" {
                // Direct USD to target conversion
                convertedRate = targetRate
            } else {
                // Get the historical base rate for this specific date
                let historicalBaseRate = historicalEntry.rates.first(where: { $0.currencyCode == baseCurrency })?.rate

                if let baseRate = historicalBaseRate, baseRate > Double.ulpOfOne {
                    // Use historical base rate for accurate conversion
                    // Formula: (USD → Target) / (USD → Base) = Base → Target
                    convertedRate = targetRate / baseRate
                } else {
                    // Fallback: use current rates if historical rate not available
                    convertedRate = rateCalculationUseCase.convertRate(
                        usdToTargetRate: targetRate,
                        fromBaseCurrency: baseCurrency,
                        toTargetCurrency: targetCurrency,
                        historicalRates: historicalEntry.rates,
                        exchangeRates: exchangeRates
                    )
                }
            }

            chartPoints.append(ChartDataPoint(date: date, rate: convertedRate))
        }

        // Cache the processed data for future use
        await cacheService.cacheProcessedChartData(chartPoints, for: cacheKey)

        return chartPoints
    }

    /// Intelligently samples data points for chart performance while preserving important points
    @MainActor
    func sampleDataPoints(from data: [ChartDataPoint], maxPoints: Int = 100) -> [ChartDataPoint] {
        // Guard against empty data or invalid maxPoints
        guard !data.isEmpty, maxPoints > 0 else { return data }
        guard data.count > maxPoints else { return data }

        let step = Double(data.count) / Double(maxPoints)
        var result: [ChartDataPoint] = []
        result.reserveCapacity(maxPoints + 4) // Pre-allocate memory

        // Single pass to find everything we need
        var minPoint: ChartDataPoint?
        var maxPoint: ChartDataPoint?
        var minRate = Double.infinity
        var maxRate = -Double.infinity

        // Always include first
        if let first = data.first {
            result.append(first)
            minPoint = first
            maxPoint = first
            minRate = first.rate
            maxRate = first.rate
        }

        // Combined sampling + min/max detection in single pass
        for i in stride(from: step, to: Double(data.count), by: step) {
            let index = Int(i.rounded())
            if index < data.count {
                let point = data[index]
                result.append(point)

                // Track extremes in same iteration
                if point.rate < minRate {
                    minRate = point.rate
                    minPoint = point
                }
                if point.rate > maxRate {
                    maxRate = point.rate
                    maxPoint = point
                }
            }
        }

        // Add extremes if not already included
        if let min = minPoint, !result.contains(where: { $0.date == min.date }) {
            result.append(min)
        }
        if let max = maxPoint, !result.contains(where: { $0.date == max.date }) {
            result.append(max)
        }

        // Always include last
        if let last = data.last, result.last?.date != last.date {
            result.append(last)
        }

        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Statistics Calculations

    /// Calculates statistics for chart data points
    @MainActor
    func calculateStatistics(from chartData: [ChartDataPoint]) -> ChartStatistics {
        let rates = chartData.map(\.rate)

        let currentRate = chartData.last?.rate ?? 0
        let highestRate = rates.max() ?? 0
        let lowestRate = rates.min() ?? 0
        let averageRate = rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count)

        // Price change from first to last data point
        let priceChange: Double? = {
            guard chartData.count >= 2,
                  let firstRate = chartData.first?.rate,
                  let lastRate = chartData.last?.rate
            else {
                return nil
            }
            return lastRate - firstRate
        }()

        // Percentage change from first to last data point
        let percentChange: Double? = {
            guard let change = priceChange,
                  let firstRate = chartData.first?.rate,
                  firstRate > 0
            else {
                return nil
            }
            return (change / firstRate) * 100
        }()

        // Trend direction based on percentage change with stable threshold
        let trendDirection: TrendDirection = {
            guard let percentChange else { return .stable }

            if abs(percentChange) <= TrendDirection.stableChangeThreshold {
                return .stable
            } else if percentChange > 0 {
                return .up
            } else {
                return .down
            }
        }()

        // Calculate volatility (standard deviation of daily returns)
        let volatility: Double? = {
            guard chartData.count > 1 else { return nil }

            // Calculate daily percentage returns with validation
            let dailyReturns = (1 ..< chartData.count).compactMap { i -> Double? in
                let previousRate = chartData[i - 1].rate
                let currentRate = chartData[i].rate

                // Validate rates are positive and finite
                guard previousRate > 0, currentRate.isFinite, previousRate.isFinite else { return nil }

                let dailyReturn = (currentRate - previousRate) / previousRate

                // Filter out extreme values that could skew volatility calculations
                guard dailyReturn.isFinite, abs(dailyReturn) < 10.0 else { return nil }

                return dailyReturn
            }

            guard !dailyReturns.isEmpty else { return nil }

            // Calculate mean return with validation
            let meanReturn = dailyReturns.reduce(0, +) / Double(dailyReturns.count)
            guard meanReturn.isFinite else { return nil }

            // Calculate variance with validation
            let variance = dailyReturns.reduce(0) { sum, dailyReturn in
                sum + pow(dailyReturn - meanReturn, 2)
            } / Double(dailyReturns.count)

            guard variance.isFinite, variance >= 0 else { return nil }

            // Calculate standard deviation (daily volatility)
            let dailyVolatility = sqrt(variance)
            guard dailyVolatility.isFinite else { return nil }

            // Annualize volatility (assuming 252 trading days)
            // Convert to percentage
            let annualizedVolatility = dailyVolatility * sqrt(252) * 100

            // Final validation - return nil if result is invalid
            return annualizedVolatility.isFinite ? annualizedVolatility : nil
        }()

        // Y-axis domain for chart display with padding
        let chartYDomain: ClosedRange<Double> = {
            guard !chartData.isEmpty else { return 0 ... 1 }

            // Filter out invalid rates for domain calculation
            let validRates = rates.filter { $0.isFinite && $0 > 0 }
            guard !validRates.isEmpty else { return 0 ... 1 }

            let minRate = validRates.min() ?? 0
            let maxRate = validRates.max() ?? 1

            // Add padding, but validate the results
            let paddedMin = minRate * 0.99
            let paddedMax = maxRate * 1.01

            // Ensure valid range bounds
            guard paddedMin.isFinite, paddedMax.isFinite, paddedMin < paddedMax else {
                return 0 ... 1
            }

            return paddedMin ... paddedMax
        }()

        return ChartStatistics(
            currentRate: currentRate,
            highestRate: highestRate,
            lowestRate: lowestRate,
            averageRate: averageRate,
            priceChange: priceChange,
            percentChange: percentChange,
            volatility: volatility,
            trendDirection: trendDirection,
            chartYDomain: chartYDomain
        )
    }
}

// MARK: - Supporting Types

/// Statistics calculated from chart data
struct ChartStatistics {
    let currentRate: Double
    let highestRate: Double
    let lowestRate: Double
    let averageRate: Double
    let priceChange: Double?
    let percentChange: Double?
    let volatility: Double?
    let trendDirection: TrendDirection
    let chartYDomain: ClosedRange<Double>
}
