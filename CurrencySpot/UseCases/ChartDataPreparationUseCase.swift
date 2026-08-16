import Foundation

// MARK: - ChartDataPreparationUseCase

final class ChartDataPreparationUseCase {
    // MARK: - Dependencies

    private let chartCache: ChartDataCacheRepository
    private let logger: LoggerService

    // MARK: - Initialization

    init(chartCache: ChartDataCacheRepository, logger: LoggerService = OSLogLoggerService()) {
        self.chartCache = chartCache
        self.logger = logger
    }

    // MARK: - Chart Data Processing

    func processHistoricalRateData(
        historicalData: [HistoricalRateSnapshot],
        baseCurrency: CurrencyCode,
        targetCurrency: CurrencyCode,
        dateRange: DateRange,
        exchangeRates: [ExchangeRate]
    ) async -> [ChartDataPoint] {
        let cacheKey = ChartCacheKey(
            base: baseCurrency,
            target: targetCurrency,
            range: dateRange,
            snapshotCount: historicalData.count,
            firstSnapshot: historicalData.first?.date,
            lastSnapshot: historicalData.last?.date
        )

        if let cachedData = await chartCache.cachedChartData(for: cacheKey) {
            logger.debug("Using cached processed chart data for \(baseCurrency) to \(targetCurrency)", category: .cache)
            return cachedData
        }

        let chartPoints = await Self.transformHistoricalData(
            historicalData,
            baseCurrency: baseCurrency,
            targetCurrency: targetCurrency,
            dateRange: dateRange,
            exchangeRates: exchangeRates
        )

        await chartCache.storeChartData(chartPoints, for: cacheKey)

        return chartPoints
    }

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

            guard let targetRate = historicalRates.usdRate(for: targetCurrency) else {
                continue
            }

            let baseRate = historicalRates.usdRate(for: baseCurrency)
                ?? currentRates.usdRate(for: baseCurrency)
                ?? 1.0
            let convertedRate = abs(baseRate) > .ulpOfOne ? targetRate / baseRate : targetRate

            chartPoints.append(ChartDataPoint(date: date, rate: convertedRate))
        }

        return chartPoints
    }

    nonisolated func sampleDataPoints(from data: [ChartDataPoint], maxPoints: Int = 100) -> [ChartDataPoint] {
        guard !data.isEmpty, maxPoints > 0 else { return data }
        guard data.count > maxPoints else { return data }

        let step = Double(data.count) / Double(maxPoints)
        var result: [ChartDataPoint] = []
        result.reserveCapacity(maxPoints + 4)

        var minPoint: ChartDataPoint?
        var maxPoint: ChartDataPoint?
        var minRate = Double.infinity
        var maxRate = -Double.infinity

        if let first = data.first {
            result.append(first)
            minPoint = first
            maxPoint = first
            minRate = first.rate
            maxRate = first.rate
        }

        for i in stride(from: step, to: Double(data.count), by: step) {
            let index = Int(i.rounded())
            if index < data.count {
                let point = data[index]
                result.append(point)

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

        if let min = minPoint, !result.contains(where: { $0.date == min.date }) {
            result.append(min)
        }
        if let max = maxPoint, !result.contains(where: { $0.date == max.date }) {
            result.append(max)
        }

        if let last = data.last, result.last?.date != last.date {
            result.append(last)
        }

        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Statistics Calculations

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

    private nonisolated static func priceChange(of chartData: [ChartDataPoint]) -> Double? {
        guard chartData.count >= 2,
              let firstRate = chartData.first?.rate,
              let lastRate = chartData.last?.rate
        else {
            return nil
        }
        return lastRate - firstRate
    }

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

    private nonisolated static func annualizedVolatility(of chartData: [ChartDataPoint]) -> Double? {
        guard chartData.count > 1 else { return nil }

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

        let annualizedVolatility = dailyVolatility * sqrt(252) * 100
        return annualizedVolatility.isFinite ? annualizedVolatility : nil
    }

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
