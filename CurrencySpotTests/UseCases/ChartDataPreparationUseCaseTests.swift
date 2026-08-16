@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

// MARK: - Test Data Constants

private let testStartDate = createCETDate(year: 2020, month: 9, day: 13)!
private let testMiddleDate = createCETDate(year: 2020, month: 9, day: 14)!
private let testEndDate = createCETDate(year: 2020, month: 9, day: 15)!
private let testOutsideDate = createCETDate(year: 2020, month: 9, day: 16)!

// MARK: - Test Helpers

private func makeUseCase() -> ChartDataPreparationUseCase {
    ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache())
}

private func createTestExchangeRates() -> [ExchangeRate] {
    [
        ExchangeRate(currencyCode: "EUR", rate: 1.2),
        ExchangeRate(currencyCode: "GBP", rate: 0.8),
        ExchangeRate(currencyCode: "JPY", rate: 110.0),
    ]
}

private func createTestHistoricalData(
    dates: [Date] = [testStartDate, testMiddleDate, testEndDate],
    targetCurrency: CurrencyCode = "EUR",
    targetRate: Double = 1.2,
    includeMissingCurrency: Bool = false
) -> [HistoricalRateSnapshot] {
    dates.map { date in
        var rates = [
            HistoricalRatePoint(currencyCode: targetCurrency, rate: targetRate),
            HistoricalRatePoint(currencyCode: "GBP", rate: 0.8),
            HistoricalRatePoint(currencyCode: "JPY", rate: 110.0),
        ]

        if includeMissingCurrency, date == testMiddleDate {
            rates = rates.filter { $0.currencyCode != targetCurrency }
        }

        return HistoricalRateSnapshot(date: date, rates: rates)
    }
}

private func createTestChartDataPoints(count: Int = 5, startRate: Double = 1.0) -> [ChartDataPoint] {
    let calendar = TimeZoneManager.cetCalendar
    let baseDate = createCETDate(year: 2020, month: 9, day: 13)!

    return (0 ..< count).map { index in
        let date = calendar.date(byAdding: .day, value: index, to: baseDate)!
        let rate = startRate + Double(index) * 0.1
        return ChartDataPoint(date: date, rate: rate)
    }
}

@Suite("Chart Data Preparation Use Case Tests")
struct ChartDataPreparationUseCaseTests {
    // MARK: - processHistoricalRateData Tests

    @Suite("processHistoricalRateData Method Tests")
    struct ProcessHistoricalRateDataTests {
        @Test("A larger dataset is not shadowed by a smaller dataset's processed cache (same pair/range)")
        func largerDatasetNotShadowedByProcessedCache() async {
            let chartCache = InMemoryChartDataCache()
            let useCase = ChartDataPreparationUseCase(chartCache: chartCache)
            let calendar = TimeZoneManager.cetCalendar
            let end = createCETDate(year: 2025, month: 6, day: 6)!
            let range = DateRange.spanning(calendar.date(byAdding: .day, value: -90, to: end)!, end)

            func rows(_ days: Int) -> [HistoricalRateSnapshot] {
                (0 ..< days).map { offset in
                    HistoricalRateSnapshot(
                        date: calendar.date(byAdding: .day, value: -offset, to: end)!,
                        rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.1)]
                    )
                }
            }

            let small = await useCase.processHistoricalRateData(
                historicalData: rows(3), baseCurrency: "USD", targetCurrency: "EUR", dateRange: range, exchangeRates: []
            )
            let large = await useCase.processHistoricalRateData(
                historicalData: rows(60), baseCurrency: "USD", targetCurrency: "EUR", dateRange: range, exchangeRates: []
            )

            #expect(small.count == 3)
            #expect(large.count == 60)
        }

        @Test("Should filter data by date range inclusively")
        func shouldFilterDataByDateRangeInclusively() async {
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData()
            let dateRange = DateRange.spanning(testStartDate, testEndDate)

            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            #expect(result.count == 3, "Should include start, middle, and end dates")
            #expect(result.first?.date == testStartDate, "Should include start date")
            #expect(result.last?.date == testEndDate, "Should include end date")
        }

        @Test("Should exclude data outside date range")
        func shouldExcludeDataOutsideDateRange() async {
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData(dates: [testStartDate, testOutsideDate])
            let dateRange = DateRange.spanning(testStartDate, testEndDate)

            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            #expect(result.count == 1, "Should only include dates within range")
            #expect(result.first?.date == testStartDate, "Should include only the date within range")
        }

        @Test("Should filter out entries missing target currency")
        func shouldFilterOutEntriesMissingTargetCurrency() async {
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData(includeMissingCurrency: true)
            let dateRange = DateRange.spanning(testStartDate, testEndDate)

            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            #expect(result.count == 2, "Should exclude entry without target currency")
            #expect(result.contains { $0.date == testMiddleDate } == false, "Should not include middle date with missing currency")
        }

        @Test("Non-USD base prefers the same-date historical base rate over current rates")
        func nonUSDBasePrefersHistoricalRate() async {
            let useCase = makeUseCase()
            let historicalData = [
                HistoricalRateSnapshot(date: testStartDate, rates: [
                    HistoricalRatePoint(currencyCode: "EUR", rate: 1.2),
                    HistoricalRatePoint(currencyCode: "GBP", rate: 0.6),
                ]),
            ]

            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "GBP",
                targetCurrency: "EUR",
                dateRange: DateRange.spanning(testStartDate, testEndDate),
                exchangeRates: createTestExchangeRates()
            )

            #expect(result.count == 1)
            #expect(abs((result.first?.rate ?? 0) - 2.0) < 0.0001, "1.2 / 0.6 historical, not 1.2 / 0.8 current")
        }

        @Test("Non-USD base falls back to current rates when the historical row lacks the base currency")
        func nonUSDBaseFallsBackToCurrentRates() async {
            let useCase = makeUseCase()
            let historicalData = [
                HistoricalRateSnapshot(date: testStartDate, rates: [
                    HistoricalRatePoint(currencyCode: "EUR", rate: 1.2),
                ]),
            ]

            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "GBP",
                targetCurrency: "EUR",
                dateRange: DateRange.spanning(testStartDate, testEndDate),
                exchangeRates: createTestExchangeRates()
            )

            #expect(result.count == 1)
            #expect(abs((result.first?.rate ?? 0) - 1.5) < 0.0001, "1.2 / 0.8 via the current-rates fallback")
        }

        @Test("Should use USD base currency without conversion")
        func shouldUseUSDBaseCurrencyWithoutConversion() async {
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData(targetRate: 1.2)
            let dateRange = DateRange.spanning(testStartDate, testEndDate)

            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            #expect(result.count == 3, "Should process all data points")
            for point in result {
                #expect(abs(point.rate - 1.2) < 0.001, "USD to EUR should be 1.2 (original rate)")
            }
        }

        @Test("Should handle empty historical data")
        func shouldHandleEmptyHistoricalData() async {
            let useCase = makeUseCase()

            let historicalData: [HistoricalRateSnapshot] = []
            let dateRange = DateRange.spanning(testStartDate, testEndDate)

            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            #expect(result.isEmpty, "Should return empty array for empty input")
        }
    }

    // MARK: - sampleDataPoints Tests

    @Suite("sampleDataPoints Method Tests")
    struct SampleDataPointsTests {
        @Test("Should return original data when count is less than or equal to maxPoints")
        func shouldReturnOriginalDataWhenCountIsLessOrEqual() async {
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 5)

            let result = useCase.sampleDataPoints(from: data, maxPoints: 10)

            #expect(result.count == 5, "Should return all original data points")
            #expect(result == data, "Should return identical data")
        }

        @Test("Should always include first and last points")
        func shouldAlwaysIncludeFirstAndLastPoints() async {
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 1000)

            let maxPoints = 50
            let result = useCase.sampleDataPoints(from: data, maxPoints: maxPoints)

            #expect(result.first?.date == data.first?.date, "Should include first point")
            #expect(result.last?.date == data.last?.date, "Should include last point")
            let maxSampledCapacity = maxPoints + 2 + 2
            #expect(result.count <= maxSampledCapacity, "Should respect capacity limits")
        }

        @Test("Should preserve temporal ordering in sampling")
        func shouldPreserveTemporalOrderingInSampling() async {
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 200)

            let result = useCase.sampleDataPoints(from: data, maxPoints: 20)

            for i in 1 ..< result.count {
                #expect(result[i - 1].date <= result[i].date, "Sampled data should be chronologically ordered")
            }
        }

        @Test("Should handle empty data")
        func shouldHandleEmptyData() async {
            let useCase = makeUseCase()

            let data: [ChartDataPoint] = []

            let result = useCase.sampleDataPoints(from: data, maxPoints: 10)

            #expect(result.isEmpty, "Should return empty array for empty input")
        }

        @Test("Should handle single data point")
        func shouldHandleSingleDataPoint() async {
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 1)

            let result = useCase.sampleDataPoints(from: data, maxPoints: 10)

            #expect(result.count == 1, "Should return single data point")
            #expect(result.first?.date == data.first?.date, "Should return the same point")
        }
    }

    // MARK: - calculateStatistics Tests

    @Suite("calculateStatistics Method Tests")
    struct CalculateStatisticsTests {
        @Test("Should calculate basic statistics correctly")
        func shouldCalculateBasicStatisticsCorrectly() async {
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 5, startRate: 1.0)

            let result = useCase.calculateStatistics(from: data)

            #expect(result.currentRate == 1.4, "Current rate should be last rate")
            #expect(result.highestRate == 1.4, "Highest rate should be maximum")
            #expect(result.lowestRate == 1.0, "Lowest rate should be minimum")
            #expect(abs(result.averageRate - 1.2) < 0.001, "Average should be correct")
        }

        @Test("Should calculate price change correctly")
        func shouldCalculatePriceChangeCorrectly() async {
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 5, startRate: 1.0)

            let result = useCase.calculateStatistics(from: data)

            #expect(result.priceChange != nil, "Price change should be calculated")
            #expect(abs((result.priceChange ?? 0) - 0.4) < 0.001, "Price change should be +0.4")
        }

        @Test("Should calculate percentage change correctly")
        func shouldCalculatePercentageChangeCorrectly() async {
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 5, startRate: 1.0)

            let result = useCase.calculateStatistics(from: data)

            #expect(result.percentChange != nil, "Percentage change should be calculated")
            #expect(abs((result.percentChange ?? 0) - 40.0) < 0.001, "Percentage change should be +40%")
        }

        @Test("Should determine trend direction correctly for upward trend")
        func shouldDetermineTrendDirectionCorrectlyForUpwardTrend() async {
            let useCase = makeUseCase()

            let data = [
                ChartDataPoint(date: testStartDate, rate: 1.0),
                ChartDataPoint(date: testEndDate, rate: 1.5),
            ]

            let result = useCase.calculateStatistics(from: data)

            #expect(result.trendDirection == .up, "Should detect upward trend")
        }

        @Test("Should determine trend direction correctly for downward trend")
        func shouldDetermineTrendDirectionCorrectlyForDownwardTrend() async {
            let useCase = makeUseCase()

            let data = [
                ChartDataPoint(date: testStartDate, rate: 1.0),
                ChartDataPoint(date: testEndDate, rate: 0.5),
            ]

            let result = useCase.calculateStatistics(from: data)

            #expect(result.trendDirection == .down, "Should detect downward trend")
        }

        @Test("Should determine trend direction correctly for stable trend")
        func shouldDetermineTrendDirectionCorrectlyForStableTrend() async {
            let useCase = makeUseCase()

            let data = [
                ChartDataPoint(date: testStartDate, rate: 1.0),
                ChartDataPoint(date: testEndDate, rate: 1.0005),
            ]

            let result = useCase.calculateStatistics(from: data)

            #expect(result.trendDirection == .stable, "Should detect stable trend")
        }

        @Test("Should calculate Y-domain padding correctly")
        func shouldCalculateYDomainPaddingCorrectly() async {
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 5, startRate: 1.0)

            let result = useCase.calculateStatistics(from: data)

            let expectedMin = 1.0 * 0.99
            let expectedMax = 1.4 * 1.01

            #expect(abs(result.chartYDomain.lowerBound - expectedMin) < 0.001, "Should apply 1% padding to minimum")
            #expect(abs(result.chartYDomain.upperBound - expectedMax) < 0.001, "Should apply 1% padding to maximum")
        }

        @Test("Should handle empty data")
        func shouldHandleEmptyData() async {
            let useCase = makeUseCase()

            let data: [ChartDataPoint] = []

            let result = useCase.calculateStatistics(from: data)

            #expect(result.currentRate == 0, "Current rate should be 0 for empty data")
            #expect(result.highestRate == 0, "Highest rate should be 0 for empty data")
            #expect(result.lowestRate == 0, "Lowest rate should be 0 for empty data")
            #expect(result.averageRate == 0, "Average rate should be 0 for empty data")
            #expect(result.priceChange == nil, "Price change should be nil for empty data")
            #expect(result.percentChange == nil, "Percentage change should be nil for empty data")
            #expect(result.trendDirection == .stable, "Trend should be stable for empty data")
            #expect(result.chartYDomain == 0 ... 1, "Y-domain should be default range for empty data")
        }

        @Test("Should handle single data point")
        func shouldHandleSingleDataPoint() async {
            let useCase = makeUseCase()

            let data = [ChartDataPoint(date: testStartDate, rate: 1.5)]

            let result = useCase.calculateStatistics(from: data)

            #expect(result.currentRate == 1.5, "Current rate should match single point")
            #expect(result.highestRate == 1.5, "Highest rate should match single point")
            #expect(result.lowestRate == 1.5, "Lowest rate should match single point")
            #expect(result.averageRate == 1.5, "Average rate should match single point")
            #expect(result.priceChange == nil, "Price change should be nil for single point")
            #expect(result.percentChange == nil, "Percentage change should be nil for single point")
            #expect(result.trendDirection == .stable, "Trend should be stable for single point")
        }

        @Test("Should handle zero first rate for percentage calculation")
        func shouldHandleZeroFirstRateForPercentageCalculation() async {
            let useCase = makeUseCase()

            let data = [
                ChartDataPoint(date: testStartDate, rate: 0.0),
                ChartDataPoint(date: testEndDate, rate: 1.0),
            ]

            let result = useCase.calculateStatistics(from: data)

            #expect(result.priceChange != nil, "Price change should still be calculated")
            #expect(result.percentChange == nil, "Percentage change should be nil for zero first rate")
            #expect(result.trendDirection == .stable, "Trend should be stable when percentage can't be calculated")
        }
    }

    // MARK: - Integration Tests

    @Suite("Integration Tests")
    struct IntegrationTests {
        @Test("Should handle complete workflow from historical data to statistics")
        func shouldHandleCompleteWorkflowFromHistoricalDataToStatistics() async {
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData(targetRate: 1.2)
            let dateRange = DateRange.spanning(testStartDate, testEndDate)

            let chartData = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            let sampledData = useCase.sampleDataPoints(from: chartData, maxPoints: 10)
            let statistics = useCase.calculateStatistics(from: sampledData)

            #expect(chartData.isEmpty == false, "Chart data should be processed")
            #expect(sampledData.isEmpty == false, "Data should be sampled")
            #expect(statistics.currentRate > 0, "Statistics should be calculated")
            #expect(statistics.chartYDomain.lowerBound > 0, "Y-domain should be valid")
        }
    }
}
