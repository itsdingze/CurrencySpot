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

    private let cacheService: CacheService
    private let logger: LoggerService

    // MARK: - Initialization

    init(cacheService: CacheService, logger: LoggerService = OSLogLoggerService()) {
        self.cacheService = cacheService
        self.logger = logger
    }

    // MARK: - Chart Data Processing

    /// Processes historical rate data for the specified currency pair within the given time range
    func processHistoricalRateData(
        historicalData: [HistoricalRateSnapshot],
        baseCurrency: CurrencyCode,
        targetCurrency: CurrencyCode,
        dateRange: DateRange,
        exchangeRates: [ExchangeRate]
    ) async -> [ChartDataPoint] {
        // Generate a cache key for this configuration AND its input coverage. The processed output
        // depends on the actual historical rows, not just the date range: the same currency pair +
        // range can hold a partial (e.g. 7-day) or full (3-month) dataset, so the key must include the
        // data's size/bounds — otherwise a smaller dataset's processed result shadows a larger one.
        let coverage = "\(historicalData.count)-\(historicalData.first?.date.timeIntervalSince1970 ?? 0)-\(historicalData.last?.date.timeIntervalSince1970 ?? 0)"
        let cacheKey = "\(baseCurrency)-\(targetCurrency)-\(dateRange.start.timeIntervalSince1970)-\(dateRange.end.timeIntervalSince1970)-\(coverage)"

        // Check cache first
        if let cachedData = await cacheService.getCachedProcessedChartData(for: cacheKey) {
            logger.debug("Using cached processed chart data for \(baseCurrency) to \(targetCurrency)", category: .cache)
            return cachedData
        }

        // Run the pure CPU transform off the main actor. This await is a suspension
        // between the cache check and the cache write, so reentrant callers may
        // duplicate the transform — never corrupt state, because the write below is
        // an unconditional, idempotent set of the same computed value.
        let chartPoints = await Self.transformHistoricalData(
            historicalData,
            baseCurrency: baseCurrency,
            targetCurrency: targetCurrency,
            dateRange: dateRange,
            exchangeRates: exchangeRates
        )

        // Cache the processed data for future use
        await cacheService.cacheProcessedChartData(chartPoints, for: cacheKey)

        return chartPoints
    }

    /// Pure transform from historical rows to chart points. `@concurrent` so the work
    /// runs on the cooperative pool instead of blocking the main actor.
    @concurrent
    private nonisolated static func transformHistoricalData(
        _ historicalData: [HistoricalRateSnapshot],
        baseCurrency: CurrencyCode,
        targetCurrency: CurrencyCode,
        dateRange: DateRange,
        exchangeRates: [ExchangeRate]
    ) async -> [ChartDataPoint] {
        let currentRates = RateTable(exchangeRates)
        var chartPoints: [ChartDataPoint] = []
        chartPoints.reserveCapacity(historicalData.count)

        for historicalEntry in historicalData {
            let date = historicalEntry.date

            guard date >= dateRange.start, date <= dateRange.end else {
                continue
            }

            let historicalRates = RateTable(points: historicalEntry.rates)

            // Skip dates that never recorded the target currency (USD is implicit).
            guard let targetRate = historicalRates.usdRate(for: targetCurrency) else {
                continue
            }

            // Prefer the same-date historical base rate; fall back to current rates,
            // then to 1.0 (returning the USD-based rate unchanged).
            let baseRate = historicalRates.usdRate(for: baseCurrency)
                ?? currentRates.usdRate(for: baseCurrency)
                ?? 1.0
            let convertedRate = abs(baseRate) > .ulpOfOne ? targetRate / baseRate : targetRate

            chartPoints.append(ChartDataPoint(date: date, rate: convertedRate))
        }

        return chartPoints
    }

    /// Intelligently samples data points for chart performance while preserving important points.
    /// Pure computation over its inputs, so it is not actor-isolated.
    nonisolated func sampleDataPoints(from data: [ChartDataPoint], maxPoints: Int = 100) -> [ChartDataPoint] {
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

    /// Calculates statistics for chart data points.
    /// Pure computation over its inputs, so it is not actor-isolated.
    nonisolated func calculateStatistics(from chartData: [ChartDataPoint]) -> ChartStatistics {
        let rates = chartData.map(\.rate)
        let priceChange = Self.priceChange(of: chartData)
        let percentChange = Self.percentChange(of: chartData, priceChange: priceChange)

        return ChartStatistics(
            currentRate: chartData.last?.rate ?? 0,
            highestRate: rates.max() ?? 0,
            lowestRate: rates.min() ?? 0,
            averageRate: rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count),
            priceChange: priceChange,
            percentChange: percentChange,
            volatility: Self.annualizedVolatility(of: chartData),
            trendDirection: percentChange.map(TrendDirection.init(percentChange:)) ?? .stable,
            chartYDomain: Self.chartYDomain(of: rates)
        )
    }

    /// Absolute change from the first to the last point; nil with fewer than two points.
    private nonisolated static func priceChange(of chartData: [ChartDataPoint]) -> Double? {
        guard chartData.count >= 2,
              let firstRate = chartData.first?.rate,
              let lastRate = chartData.last?.rate
        else {
            return nil
        }
        return lastRate - firstRate
    }

    /// Percentage change from the first to the last point; nil when there is no price
    /// change to compute or the first rate is non-positive.
    private nonisolated static func percentChange(of chartData: [ChartDataPoint], priceChange: Double?) -> Double? {
        guard priceChange != nil,
              let firstRate = chartData.first?.rate,
              firstRate > 0,
              let lastRate = chartData.last?.rate
        else {
            return nil
        }
        return RateMath.percentChange(from: firstRate, to: lastRate)
    }

    /// Annualized standard deviation of daily returns, as a percentage (252 trading
    /// days). nil with too few points, or when validation rejects the inputs/result.
    private nonisolated static func annualizedVolatility(of chartData: [ChartDataPoint]) -> Double? {
        guard chartData.count > 1 else { return nil }

        // Daily percentage returns, dropping non-finite rates and extreme outliers.
        let dailyReturns = (1 ..< chartData.count).compactMap { i -> Double? in
            let previousRate = chartData[i - 1].rate
            let currentRate = chartData[i].rate
            guard previousRate > 0, currentRate.isFinite, previousRate.isFinite else { return nil }

            let dailyReturn = (currentRate - previousRate) / previousRate
            guard dailyReturn.isFinite, abs(dailyReturn) < 10.0 else { return nil }
            return dailyReturn
        }

        guard !dailyReturns.isEmpty else { return nil }

        let meanReturn = dailyReturns.reduce(0, +) / Double(dailyReturns.count)
        guard meanReturn.isFinite else { return nil }

        let variance = dailyReturns.reduce(0) { sum, dailyReturn in
            sum + pow(dailyReturn - meanReturn, 2)
        } / Double(dailyReturns.count)
        guard variance.isFinite, variance >= 0 else { return nil }

        let dailyVolatility = sqrt(variance)
        guard dailyVolatility.isFinite else { return nil }

        // Annualize (252 trading days) and convert to a percentage.
        let annualizedVolatility = dailyVolatility * sqrt(252) * 100
        return annualizedVolatility.isFinite ? annualizedVolatility : nil
    }

    /// Y-axis domain with 1% padding; falls back to 0...1 when no valid rates exist.
    private nonisolated static func chartYDomain(of rates: [Double]) -> ClosedRange<Double> {
        let validRates = rates.filter { $0.isFinite && $0 > 0 }
        guard !validRates.isEmpty else { return 0 ... 1 }

        let paddedMin = (validRates.min() ?? 0) * 0.99
        let paddedMax = (validRates.max() ?? 1) * 1.01
        guard paddedMin.isFinite, paddedMax.isFinite, paddedMin < paddedMax else {
            return 0 ... 1
        }
        return paddedMin ... paddedMax
    }
}
