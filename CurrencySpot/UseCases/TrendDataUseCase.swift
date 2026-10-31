import Foundation
import OSLog

// MARK: - TrendDataUseCase

final class TrendDataUseCase {
    // MARK: - Dependencies

    private let trendRepository: TrendRepository
    private let historicalRateRepository: HistoricalRateRepository
    private let dateProvider: DateProvider
    private let logger = Logger(category: .useCase)

    // MARK: - Initialization

    init(
        trendRepository: TrendRepository,
        historicalRateRepository: HistoricalRateRepository,
        dateProvider: DateProvider
    ) {
        self.trendRepository = trendRepository
        self.historicalRateRepository = historicalRateRepository
        self.dateProvider = dateProvider
    }

    // MARK: - Trend Window

    private func trendWindow(now: Date) -> DateRange {
        let calendar = CETCalendar.calendar
        let endDate = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        return DateRange.spanning(startDate, endDate)
    }

    // MARK: - Trend Calculation (pure)

    static func calculateTrends(from historicalData: [HistoricalRateSnapshot]) -> [Trend] {
        dailySeries(from: historicalData).compactMap { currencyCode, rates in
            guard rates.count >= 2,
                  let firstRate = rates.first,
                  let lastRate = rates.last,
                  let weeklyChange = RateMath.percentChange(from: firstRate, to: lastRate)
            else {
                return nil
            }

            return Trend(
                currencyCode: currencyCode,
                weeklyChange: weeklyChange,
                miniChartData: rates
            )
        }
    }

    private static func dailySeries(from historicalData: [HistoricalRateSnapshot]) -> [CurrencyCode: [Double]] {
        var series: [CurrencyCode: [Double]] = [:]
        for historicalDay in historicalData.sorted(by: { $0.date < $1.date }) {
            let dayRates = Dictionary(
                historicalDay.rates.map { ($0.currencyCode, $0.rate) },
                uniquingKeysWith: { _, latest in latest }
            )
            for currencyCode in Set(series.keys).union(dayRates.keys) {
                guard let rate = dayRates[currencyCode] ?? series[currencyCode]?.last else { continue }
                series[currencyCode, default: []].append(rate)
            }
        }
        return series
    }

    private func recalculateAndSaveTrends() async throws {
        let window = trendWindow(now: dateProvider.now())
        let historicalData = try await historicalRateRepository.loadStoredHistoricalRates(in: window)
        try await trendRepository.saveTrendData(Self.calculateTrends(from: historicalData))
    }

    // MARK: - Trend Data Management

    func initializeTrendData() async throws -> [Trend] {
        let existingTrends = try await trendRepository.loadTrendData()
        guard existingTrends.isEmpty else { return existingTrends }

        let window = trendWindow(now: dateProvider.now())
        var historicalData = try await historicalRateRepository.loadStoredHistoricalRates(in: window)

        if historicalData.count < 2 {
            historicalData = try await historicalRateRepository.fetchAndMergeHistoricalRates(in: window)
        }

        try await trendRepository.saveTrendData(Self.calculateTrends(from: historicalData))
        return try await trendRepository.loadTrendData()
    }

    func getTrendData(for currencyCode: CurrencyCode, from trendData: [Trend]) -> Trend? {
        trendData.first { $0.currencyCode == currencyCode }
    }

    func checkAndRecalculateTrendsIfNeeded(for missingRanges: [DateRange]) async -> [Trend] {
        do {
            let now = dateProvider.now()
            let shouldRecalculateTrends = missingRanges.contains { range in
                dateRangeAffectsTrends(startDate: range.start, endDate: range.end, now: now)
            }

            if shouldRecalculateTrends {
                logger.info("Recalculating trend data due to new latest data")
                try await recalculateAndSaveTrends()
                let updatedTrends = try await trendRepository.loadTrendData()
                logger.info("Trend data updated with \(updatedTrends.count, privacy: .public) currencies")
                return updatedTrends
            } else {
                return try await trendRepository.loadTrendData()
            }
        } catch {
            logger.warning("Failed to check or recalculate trends: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func dateRangeAffectsTrends(startDate: Date, endDate: Date, now: Date) -> Bool {
        let calendar = CETCalendar.calendar
        let window = trendWindow(now: now)

        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.startOfDay(for: endDate)

        return normalizedStartDate <= window.end && normalizedEndDate >= window.start
    }

    // MARK: - Cross-Currency Adjustment

    func adjustedTrend(
        for currencyCode: CurrencyCode,
        baseCurrency: CurrencyCode,
        in trendData: [Trend]
    ) -> Trend? {
        if currencyCode == .usd, baseCurrency != .usd {
            guard let baseTrend = getTrendData(for: baseCurrency, from: trendData),
                  !baseTrend.miniChartData.isEmpty
            else {
                return nil
            }

            let invertedMiniChartData = baseTrend.miniChartData.map { rate in
                rate != 0 ? 1.0 / rate : 1.0
            }

            guard let firstRate = invertedMiniChartData.first,
                  let lastRate = invertedMiniChartData.last,
                  let adjustedChange = RateMath.percentChange(from: firstRate, to: lastRate)
            else {
                return nil
            }

            return Trend(
                currencyCode: .usd,
                weeklyChange: adjustedChange,
                miniChartData: invertedMiniChartData
            )
        }

        guard let targetTrend = getTrendData(for: currencyCode, from: trendData) else {
            return nil
        }

        if baseCurrency == .usd {
            return targetTrend
        }

        guard let baseTrend = getTrendData(for: baseCurrency, from: trendData) else {
            return nil
        }

        let sharedDays = min(targetTrend.miniChartData.count, baseTrend.miniChartData.count)
        guard sharedDays >= 2 else {
            return nil
        }

        let adjustedMiniChartData = zip(
            targetTrend.miniChartData.suffix(sharedDays),
            baseTrend.miniChartData.suffix(sharedDays)
        ).map { targetRate, baseRate in
            baseRate != 0 ? targetRate / baseRate : targetRate
        }

        guard let firstRate = adjustedMiniChartData.first,
              let lastRate = adjustedMiniChartData.last,
              let adjustedChange = RateMath.percentChange(from: firstRate, to: lastRate)
        else {
            return nil
        }

        return Trend(
            currencyCode: currencyCode,
            weeklyChange: adjustedChange,
            miniChartData: adjustedMiniChartData
        )
    }
}
