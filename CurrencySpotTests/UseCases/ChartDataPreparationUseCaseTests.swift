//
//  ChartDataPreparationUseCaseTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 8/1/25.
//

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

/// Builds a fresh use case over an isolated in-memory cache, shared by every test.
@MainActor
private func makeUseCase() -> ChartDataPreparationUseCase {
    ChartDataPreparationUseCase(cacheService: InMemoryCacheService())
}

/// Creates predictable exchange rates for testing
private func createTestExchangeRates() -> [ExchangeRate] {
    [
        ExchangeRate(currencyCode: "EUR", rate: 1.2),
        ExchangeRate(currencyCode: "GBP", rate: 0.8),
        ExchangeRate(currencyCode: "JPY", rate: 110.0),
    ]
}

/// Creates test historical data with specified parameters
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

        // For testing missing currency scenarios
        if includeMissingCurrency, date == testMiddleDate {
            rates = rates.filter { $0.currencyCode != targetCurrency }
        }

        return HistoricalRateSnapshot(date: date, rates: rates)
    }
}

/// Creates test chart data points
private func createTestChartDataPoints(count: Int = 5, startRate: Double = 1.0) -> [ChartDataPoint] {
    let calendar = TimeZoneManager.cetCalendar
    let baseDate = createCETDate(year: 2020, month: 9, day: 13)!

    return (0 ..< count).map { index in
        let date = calendar.date(byAdding: .day, value: index, to: baseDate)!
        let rate = startRate + Double(index) * 0.1 // Incremental rates
        return ChartDataPoint(date: date, rate: rate)
    }
}

@Suite("Chart Data Preparation Use Case Tests")
@MainActor
struct ChartDataPreparationUseCaseTests {
    // MARK: - processHistoricalRateData Tests

    @Suite("processHistoricalRateData Method Tests")
    @MainActor
    struct ProcessHistoricalRateDataTests {
        @Test("A larger dataset is not shadowed by a smaller dataset's processed cache (same pair/range)")
        func largerDatasetNotShadowedByProcessedCache() async {
            // Regression: the processed-chart cache was keyed only by base/target/range, so a 7-day
            // result cached first would shadow a later 3-month result for the same pair and range.
            let cacheService = InMemoryCacheService()
            let useCase = ChartDataPreparationUseCase(cacheService: cacheService)
            let calendar = TimeZoneManager.cetCalendar
            let end = createCETDate(year: 2025, month: 6, day: 6)!
            let range = DateRange(start: calendar.date(byAdding: .day, value: -90, to: end)!, end: end)

            func rows(_ days: Int) -> [HistoricalRateSnapshot] {
                (0 ..< days).map { offset in
                    HistoricalRateSnapshot(
                        date: calendar.date(byAdding: .day, value: -offset, to: end)!,
                        rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.1)]
                    )
                }
            }

            // Process a small dataset first (populates the processed cache), then a large one.
            let small = await useCase.processHistoricalRateData(
                historicalData: rows(3), baseCurrency: "USD", targetCurrency: "EUR", dateRange: range, exchangeRates: []
            )
            let large = await useCase.processHistoricalRateData(
                historicalData: rows(60), baseCurrency: "USD", targetCurrency: "EUR", dateRange: range, exchangeRates: []
            )

            #expect(small.count == 3)
            #expect(large.count == 60) // must reflect the larger input, not the cached 3-point result
        }

        @Test("Should filter data by date range inclusively")
        func shouldFilterDataByDateRangeInclusively() async {
            // GIVEN: Use case with historical data spanning multiple dates
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData()
            let dateRange = DateRange(start: testStartDate, end: testEndDate)

            // WHEN: Processing historical data
            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            // THEN: Should include all dates within range (inclusively)
            #expect(result.count == 3, "Should include start, middle, and end dates")
            #expect(result.first?.date == testStartDate, "Should include start date")
            #expect(result.last?.date == testEndDate, "Should include end date")
        }

        @Test("Should exclude data outside date range")
        func shouldExcludeDataOutsideDateRange() async {
            // GIVEN: Historical data with dates outside the range
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData(dates: [testStartDate, testOutsideDate])
            let dateRange = DateRange(start: testStartDate, end: testEndDate)

            // WHEN: Processing historical data
            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            // THEN: Should only include data within range
            #expect(result.count == 1, "Should only include dates within range")
            #expect(result.first?.date == testStartDate, "Should include only the date within range")
        }

        @Test("Should filter out entries missing target currency")
        func shouldFilterOutEntriesMissingTargetCurrency() async {
            // GIVEN: Historical data with missing target currency for some entries
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData(includeMissingCurrency: true)
            let dateRange = DateRange(start: testStartDate, end: testEndDate)

            // WHEN: Processing historical data
            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            // THEN: Should exclude entry missing target currency
            #expect(result.count == 2, "Should exclude entry without target currency")
            #expect(result.contains { $0.date == testMiddleDate } == false, "Should not include middle date with missing currency")
        }

        @Test("Should use USD base currency without conversion")
        func shouldUseUSDBaseCurrencyWithoutConversion() async {
            // GIVEN: Use case with USD base currency
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData(targetRate: 1.2)
            let dateRange = DateRange(start: testStartDate, end: testEndDate)

            // WHEN: Processing with USD base currency (no conversion needed)
            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            // THEN: Rates should be unchanged for USD base
            #expect(result.count == 3, "Should process all data points")
            for point in result {
                #expect(abs(point.rate - 1.2) < 0.001, "USD to EUR should be 1.2 (original rate)")
            }
        }

        @Test("Should handle empty historical data")
        func shouldHandleEmptyHistoricalData() async {
            // GIVEN: Use case with empty historical data
            let useCase = makeUseCase()

            let historicalData: [HistoricalRateSnapshot] = []
            let dateRange = DateRange(start: testStartDate, end: testEndDate)

            // WHEN: Processing empty data
            let result = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            // THEN: Should return empty result
            #expect(result.isEmpty, "Should return empty array for empty input")
        }
    }

    // MARK: - sampleDataPoints Tests

    @Suite("sampleDataPoints Method Tests")
    @MainActor
    struct SampleDataPointsTests {
        @Test("Should return original data when count is less than or equal to maxPoints")
        func shouldReturnOriginalDataWhenCountIsLessOrEqual() async {
            // GIVEN: Use case and small dataset
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 5)

            // WHEN: Sampling with maxPoints greater than data count
            let result = await useCase.sampleDataPoints(from: data, maxPoints: 10)

            // THEN: Should return original data unchanged
            #expect(result.count == 5, "Should return all original data points")
            #expect(result == data, "Should return identical data")
        }

        @Test("Should always include first and last points")
        func shouldAlwaysIncludeFirstAndLastPoints() async {
            // GIVEN: Use case and large dataset
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 1000)

            // WHEN: Sampling data
            let maxPoints = 50
            let result = await useCase.sampleDataPoints(from: data, maxPoints: maxPoints)

            // THEN: Should always include first and last points
            #expect(result.first?.date == data.first?.date, "Should include first point")
            #expect(result.last?.date == data.last?.date, "Should include last point")
            // Sampler contract: up to maxPoints sampled points, plus the highest/lowest
            // extreme points (2) and the first/last endpoints (2) are always retained.
            let maxSampledCapacity = maxPoints + 2 + 2
            #expect(result.count <= maxSampledCapacity, "Should respect capacity limits")
        }

        @Test("Should preserve temporal ordering in sampling")
        func shouldPreserveTemporalOrderingInSampling() async {
            // GIVEN: Use case and chronologically ordered data
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 200)

            // WHEN: Sampling data
            let result = await useCase.sampleDataPoints(from: data, maxPoints: 20)

            // THEN: Result should maintain chronological order
            for i in 1 ..< result.count {
                #expect(result[i - 1].date <= result[i].date, "Sampled data should be chronologically ordered")
            }
        }

        @Test("Should handle empty data")
        func shouldHandleEmptyData() async {
            // GIVEN: Use case and empty dataset
            let useCase = makeUseCase()

            let data: [ChartDataPoint] = []

            // WHEN: Sampling empty data
            let result = await useCase.sampleDataPoints(from: data, maxPoints: 10)

            // THEN: Should return empty array
            #expect(result.isEmpty, "Should return empty array for empty input")
        }

        @Test("Should handle single data point")
        func shouldHandleSingleDataPoint() async {
            // GIVEN: Use case and single data point
            let useCase = makeUseCase()

            let data = createTestChartDataPoints(count: 1)

            // WHEN: Sampling single point
            let result = await useCase.sampleDataPoints(from: data, maxPoints: 10)

            // THEN: Should return the single point
            #expect(result.count == 1, "Should return single data point")
            #expect(result.first?.date == data.first?.date, "Should return the same point")
        }
    }

    // MARK: - calculateStatistics Tests

    @Suite("calculateStatistics Method Tests")
    @MainActor
    struct CalculateStatisticsTests {
        @Test("Should calculate basic statistics correctly")
        func shouldCalculateBasicStatisticsCorrectly() async {
            // GIVEN: Use case and test data with known values
            let useCase = makeUseCase()

            // Data: rates [1.0, 1.1, 1.2, 1.3, 1.4]
            let data = createTestChartDataPoints(count: 5, startRate: 1.0)

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should calculate correct statistics
            #expect(result.currentRate == 1.4, "Current rate should be last rate")
            #expect(result.highestRate == 1.4, "Highest rate should be maximum")
            #expect(result.lowestRate == 1.0, "Lowest rate should be minimum")
            #expect(abs(result.averageRate - 1.2) < 0.001, "Average should be correct")
        }

        @Test("Should calculate price change correctly")
        func shouldCalculatePriceChangeCorrectly() async {
            // GIVEN: Use case and test data
            let useCase = makeUseCase()

            // Data: rates [1.0, 1.1, 1.2, 1.3, 1.4] (change: 1.4 - 1.0 = +0.4)
            let data = createTestChartDataPoints(count: 5, startRate: 1.0)

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should calculate correct price change
            #expect(result.priceChange != nil, "Price change should be calculated")
            #expect(abs((result.priceChange ?? 0) - 0.4) < 0.001, "Price change should be +0.4")
        }

        @Test("Should calculate percentage change correctly")
        func shouldCalculatePercentageChangeCorrectly() async {
            // GIVEN: Use case and test data
            let useCase = makeUseCase()

            // Data: rates [1.0, 1.1, 1.2, 1.3, 1.4] (change: (1.4-1.0)/1.0 * 100 = +40%)
            let data = createTestChartDataPoints(count: 5, startRate: 1.0)

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should calculate correct percentage change
            #expect(result.percentChange != nil, "Percentage change should be calculated")
            #expect(abs((result.percentChange ?? 0) - 40.0) < 0.001, "Percentage change should be +40%")
        }

        @Test("Should determine trend direction correctly for upward trend")
        func shouldDetermineTrendDirectionCorrectlyForUpwardTrend() async {
            // GIVEN: Use case and upward trending data
            let useCase = makeUseCase()

            // Create data with significant upward trend (>0.1% change)
            let data = [
                ChartDataPoint(date: testStartDate, rate: 1.0),
                ChartDataPoint(date: testEndDate, rate: 1.5), // +50% change
            ]

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should determine upward trend
            #expect(result.trendDirection == .up, "Should detect upward trend")
        }

        @Test("Should determine trend direction correctly for downward trend")
        func shouldDetermineTrendDirectionCorrectlyForDownwardTrend() async {
            // GIVEN: Use case and downward trending data
            let useCase = makeUseCase()

            // Create data with significant downward trend (>0.1% change)
            let data = [
                ChartDataPoint(date: testStartDate, rate: 1.0),
                ChartDataPoint(date: testEndDate, rate: 0.5), // -50% change
            ]

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should determine downward trend
            #expect(result.trendDirection == .down, "Should detect downward trend")
        }

        @Test("Should determine trend direction correctly for stable trend")
        func shouldDetermineTrendDirectionCorrectlyForStableTrend() async {
            // GIVEN: Use case and stable data
            let useCase = makeUseCase()

            // Create data with minimal change (within 0.1% threshold)
            let data = [
                ChartDataPoint(date: testStartDate, rate: 1.0),
                ChartDataPoint(date: testEndDate, rate: 1.0005), // +0.05% change
            ]

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should determine stable trend
            #expect(result.trendDirection == .stable, "Should detect stable trend")
        }

        @Test("Should calculate Y-domain padding correctly")
        func shouldCalculateYDomainPaddingCorrectly() async {
            // GIVEN: Use case and test data
            let useCase = makeUseCase()

            // Data with known min (1.0) and max (1.4)
            let data = createTestChartDataPoints(count: 5, startRate: 1.0)

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should apply 1% padding to Y-domain
            let expectedMin = 1.0 * 0.99 // 0.99
            let expectedMax = 1.4 * 1.01 // 1.414

            #expect(abs(result.chartYDomain.lowerBound - expectedMin) < 0.001, "Should apply 1% padding to minimum")
            #expect(abs(result.chartYDomain.upperBound - expectedMax) < 0.001, "Should apply 1% padding to maximum")
        }

        @Test("Should handle empty data")
        func shouldHandleEmptyData() async {
            // GIVEN: Use case and empty data
            let useCase = makeUseCase()

            let data: [ChartDataPoint] = []

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should handle empty data gracefully
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
            // GIVEN: Use case and single data point
            let useCase = makeUseCase()

            let data = [ChartDataPoint(date: testStartDate, rate: 1.5)]

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should handle single point gracefully
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
            // GIVEN: Use case and data starting with zero rate
            let useCase = makeUseCase()

            let data = [
                ChartDataPoint(date: testStartDate, rate: 0.0),
                ChartDataPoint(date: testEndDate, rate: 1.0),
            ]

            // WHEN: Calculating statistics
            let result = await useCase.calculateStatistics(from: data)

            // THEN: Should handle zero first rate gracefully
            #expect(result.priceChange != nil, "Price change should still be calculated")
            #expect(result.percentChange == nil, "Percentage change should be nil for zero first rate")
            #expect(result.trendDirection == .stable, "Trend should be stable when percentage can't be calculated")
        }
    }

    // MARK: - Integration Tests

    @Suite("Integration Tests")
    @MainActor
    struct IntegrationTests {
        @Test("Should handle complete workflow from historical data to statistics")
        func shouldHandleCompleteWorkflowFromHistoricalDataToStatistics() async {
            // GIVEN: Use case and historical data
            let useCase = makeUseCase()

            let historicalData = createTestHistoricalData(targetRate: 1.2)
            let dateRange = DateRange(start: testStartDate, end: testEndDate)

            // WHEN: Processing data through complete workflow
            let chartData = await useCase.processHistoricalRateData(
                historicalData: historicalData,
                baseCurrency: "USD",
                targetCurrency: "EUR",
                dateRange: dateRange,
                exchangeRates: createTestExchangeRates()
            )

            let sampledData = await useCase.sampleDataPoints(from: chartData, maxPoints: 10)
            let statistics = await useCase.calculateStatistics(from: sampledData)

            // THEN: Should complete workflow successfully
            #expect(chartData.isEmpty == false, "Chart data should be processed")
            #expect(sampledData.isEmpty == false, "Data should be sampled")
            #expect(statistics.currentRate > 0, "Statistics should be calculated")
            #expect(statistics.chartYDomain.lowerBound > 0, "Y-domain should be valid")
        }
    }
}
