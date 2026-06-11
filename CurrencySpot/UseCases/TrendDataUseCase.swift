//
//  TrendDataUseCase.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation

// MARK: - TrendDataUseCase

/// Use case responsible for trend data management: owns the weekly trend math
/// (percent change + sparkline) and the cross-currency adjustment, while the
/// repositories only load raw rates and store computed values.
final class TrendDataUseCase {
    // MARK: - Dependencies

    private let trendRepository: TrendRepository
    private let historicalRateRepository: HistoricalRateRepository
    private let dateProvider: DateProvider
    private let logger: LoggerService

    // MARK: - Initialization

    init(
        trendRepository: TrendRepository,
        historicalRateRepository: HistoricalRateRepository,
        dateProvider: DateProvider = SystemDateProvider(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.trendRepository = trendRepository
        self.historicalRateRepository = historicalRateRepository
        self.dateProvider = dateProvider
        self.logger = logger
    }

    // MARK: - Trend Window

    /// The 7-day window (ending at today's CET start-of-day) trends are computed over.
    private func trendWindow(now: Date) -> DateRange {
        let calendar = TimeZoneManager.cetCalendar
        let endDate = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        return DateRange(start: startDate, end: endDate)
    }

    // MARK: - Trend Calculation (pure)

    /// Computes per-currency weekly trends from raw historical rows.
    /// Currencies with fewer than 2 data points in the window are skipped;
    /// USD is omitted because its trends derive from inverting other currencies.
    static func calculateTrends(from historicalData: [HistoricalRateDataValue]) -> [TrendDataValue] {
        var currencyDateRates: [CurrencyCode: [(Date, Double)]] = [:]

        for historicalDay in historicalData {
            for ratePoint in historicalDay.rates {
                currencyDateRates[ratePoint.currencyCode, default: []].append((historicalDay.date, ratePoint.rate))
            }
        }

        return currencyDateRates.compactMap { currencyCode, dateRates in
            let sortedRates = dateRates.sorted { $0.0 < $1.0 }

            guard sortedRates.count >= 2,
                  let firstRate = sortedRates.first?.1,
                  let lastRate = sortedRates.last?.1,
                  let weeklyChange = RateMath.percentChange(from: firstRate, to: lastRate)
            else {
                return nil
            }

            return TrendDataValue(
                currencyCode: currencyCode,
                weeklyChange: weeklyChange,
                miniChartData: sortedRates.map(\.1)
            )
        }
    }

    /// Recomputes trends over the current window from stored historical rates and saves them.
    private func recalculateAndSaveTrends() async throws {
        let window = trendWindow(now: dateProvider.now())
        let historicalData = try await trendRepository.loadHistoricalRates(from: window.start, to: window.end)
        try await trendRepository.saveTrendData(Self.calculateTrends(from: historicalData))
    }

    // MARK: - Trend Data Management

    /// Initializes trend data by checking stored trends and fetching/calculating if needed.
    /// Throws on failure; the calling ViewModel routes errors to its error handler.
    func initializeTrendData() async throws -> [TrendDataValue] {
        let existingTrends = try await trendRepository.loadTrendData()
        guard existingTrends.isEmpty else { return existingTrends }

        let window = trendWindow(now: dateProvider.now())
        var historicalData = try await trendRepository.loadHistoricalRates(from: window.start, to: window.end)

        // Need at least 2 days of data for meaningful trends; fetch the window if short.
        if historicalData.count < 2 {
            try await historicalRateRepository.fetchAndSaveHistoricalRates(from: window.start, to: window.end)
            historicalData = try await trendRepository.loadHistoricalRates(from: window.start, to: window.end)
        }

        try await trendRepository.saveTrendData(Self.calculateTrends(from: historicalData))
        return try await trendRepository.loadTrendData()
    }

    /// Gets trend data for a specific currency
    func getTrendData(for currencyCode: CurrencyCode, from trendData: [TrendDataValue]) -> TrendDataValue? {
        trendData.first { $0.currencyCode == currencyCode }
    }

    /// Checks if any of the missing ranges affect trend calculation and recalculates trends if needed
    func checkAndRecalculateTrendsIfNeeded(for missingRanges: [DateRange]) async -> [TrendDataValue] {
        do {
            let now = dateProvider.now()
            let shouldRecalculateTrends = missingRanges.contains { range in
                dateRangeAffectsTrends(startDate: range.start, endDate: range.end, now: now)
            }

            if shouldRecalculateTrends {
                logger.info("Recalculating trend data due to new latest data...", category: .useCase)
                try await recalculateAndSaveTrends()
                let updatedTrends = try await trendRepository.loadTrendData()
                logger.info("Trend data updated with \(updatedTrends.count) currencies", category: .useCase)
                return updatedTrends
            } else {
                // Return existing trends if no recalculation needed
                return try await trendRepository.loadTrendData()
            }
        } catch {
            logger.warning("Failed to check/recalculate trends: \(error.localizedDescription)", category: .useCase)
            // Continue without failing the main flow
            return []
        }
    }

    /// Whether a date range overlaps the trend calculation window (last 7 days).
    func dateRangeAffectsTrends(startDate: Date, endDate: Date, now: Date) -> Bool {
        let calendar = TimeZoneManager.cetCalendar
        let trendWindowEnd = calendar.startOfDay(for: now)
        let trendWindowStart = calendar.date(byAdding: .day, value: -7, to: trendWindowEnd) ?? trendWindowEnd

        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.startOfDay(for: endDate)

        return normalizedStartDate <= trendWindowEnd && normalizedEndDate >= trendWindowStart
    }

    // MARK: - Cross-Currency Adjustment

    /// Trend data for a currency, re-based from USD onto the given base currency.
    /// Stored trends are USD-based; viewing them against another base requires
    /// inverting (for USD itself) or dividing the two USD series pointwise.
    func adjustedTrend(
        for currencyCode: CurrencyCode,
        baseCurrency: CurrencyCode,
        in trendData: [TrendDataValue]
    ) -> TrendDataValue? {
        // Special handling when the target currency is USD: invert the base series.
        if currencyCode == .usd, baseCurrency != .usd {
            guard let baseTrend = getTrendData(for: baseCurrency, from: trendData),
                  !baseTrend.miniChartData.isEmpty
            else {
                return nil
            }

            // If EUR/USD = 1.1, then USD/EUR = 1/1.1
            let invertedMiniChartData = baseTrend.miniChartData.map { rate in
                rate != 0 ? 1.0 / rate : 1.0
            }

            guard let firstRate = invertedMiniChartData.first,
                  let lastRate = invertedMiniChartData.last,
                  let adjustedChange = RateMath.percentChange(from: firstRate, to: lastRate)
            else {
                return nil
            }

            return TrendDataValue(
                currencyCode: .usd,
                weeklyChange: adjustedChange,
                miniChartData: invertedMiniChartData
            )
        }

        guard let targetTrend = getTrendData(for: currencyCode, from: trendData) else {
            return nil
        }

        // If base currency is USD, return the trend as-is (already USD-based)
        if baseCurrency == .usd {
            return targetTrend
        }

        // Get the base currency's trend data (USD → Base)
        guard let baseTrend = getTrendData(for: baseCurrency, from: trendData),
              baseTrend.miniChartData.count == targetTrend.miniChartData.count,
              baseTrend.miniChartData.count >= 2
        else {
            // If we can't find base currency trend or data is invalid, return original
            return targetTrend
        }

        // Convert each data point: Base → Target rate = (USD → Target) / (USD → Base)
        let adjustedMiniChartData = zip(targetTrend.miniChartData, baseTrend.miniChartData).map { targetRate, baseRate in
            baseRate != 0 ? targetRate / baseRate : targetRate
        }

        guard let firstRate = adjustedMiniChartData.first,
              let lastRate = adjustedMiniChartData.last,
              let adjustedChange = RateMath.percentChange(from: firstRate, to: lastRate)
        else {
            return targetTrend
        }

        return TrendDataValue(
            currencyCode: currencyCode,
            weeklyChange: adjustedChange,
            miniChartData: adjustedMiniChartData
        )
    }
}
