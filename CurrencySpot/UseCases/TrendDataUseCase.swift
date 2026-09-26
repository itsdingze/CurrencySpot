import Foundation

// MARK: - TrendDataUseCase

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

    private func trendWindow(now: Date) -> DateRange {
        let calendar = TimeZoneManager.cetCalendar
        let endDate = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        return DateRange.spanning(startDate, endDate)
    }

    // MARK: - Trend Calculation (pure)

    static func calculateTrends(from historicalData: [HistoricalRateSnapshot]) -> [Trend] {
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

            return Trend(
                currencyCode: currencyCode,
                weeklyChange: weeklyChange,
                miniChartData: sortedRates.map(\.1)
            )
        }
    }

    private func recalculateAndSaveTrends() async throws {
        await historicalRateRepository.waitForPendingHistoricalWrites()
        let window = trendWindow(now: dateProvider.now())
        let historicalData = try await trendRepository.loadHistoricalRates(from: window.start, to: window.end)
        try await trendRepository.saveTrendData(Self.calculateTrends(from: historicalData))
    }

    // MARK: - Trend Data Management

    func initializeTrendData() async throws -> [Trend] {
        let existingTrends = try await trendRepository.loadTrendData()
        guard existingTrends.isEmpty else { return existingTrends }

        let window = trendWindow(now: dateProvider.now())
        var historicalData = try await trendRepository.loadHistoricalRates(from: window.start, to: window.end)

        // The fetch returns the window's snapshots directly — a persistence read-back
        // here would race the deferred save.
        if historicalData.count < 2 {
            historicalData = try await historicalRateRepository.fetchHistoricalRates(in: window)
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
                logger.info("Recalculating trend data due to new latest data...", category: .useCase)
                try await recalculateAndSaveTrends()
                let updatedTrends = try await trendRepository.loadTrendData()
                logger.info("Trend data updated with \(updatedTrends.count) currencies", category: .useCase)
                return updatedTrends
            } else {
                return try await trendRepository.loadTrendData()
            }
        } catch {
            logger.warning("Failed to check/recalculate trends: \(error.localizedDescription)", category: .useCase)
            return []
        }
    }

    func dateRangeAffectsTrends(startDate: Date, endDate: Date, now: Date) -> Bool {
        let calendar = TimeZoneManager.cetCalendar
        let window = trendWindow(now: now)

        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.startOfDay(for: endDate)

        return normalizedStartDate <= window.end && normalizedEndDate >= window.start
    }

    // MARK: - Cross-Currency Adjustment

    func adjustedTrends(baseCurrency: CurrencyCode, in trendData: [Trend]) -> [CurrencyCode: Trend] {
        let codes = Set(trendData.map(\.currencyCode)).union([.usd])
        return codes.reduce(into: [:]) { adjusted, code in
            adjusted[code] = adjustedTrend(for: code, baseCurrency: baseCurrency, in: trendData)
        }
    }

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

        guard let baseTrend = getTrendData(for: baseCurrency, from: trendData),
              baseTrend.miniChartData.count == targetTrend.miniChartData.count,
              baseTrend.miniChartData.count >= 2
        else {
            return targetTrend
        }

        let adjustedMiniChartData = zip(targetTrend.miniChartData, baseTrend.miniChartData).map { targetRate, baseRate in
            baseRate != 0 ? targetRate / baseRate : targetRate
        }

        guard let firstRate = adjustedMiniChartData.first,
              let lastRate = adjustedMiniChartData.last,
              let adjustedChange = RateMath.percentChange(from: firstRate, to: lastRate)
        else {
            return targetTrend
        }

        return Trend(
            currencyCode: currencyCode,
            weeklyChange: adjustedChange,
            miniChartData: adjustedMiniChartData
        )
    }
}
