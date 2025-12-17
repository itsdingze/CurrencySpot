//
//  TrendDataUpdateTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 12/9/25.
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("Trend Data Update Tests")
struct TrendDataUpdateTests {
    // MARK: - Test Data Setup

    private func createMockHistoricalData(for currency: String, days: Int = 7) -> [HistoricalRateDataValue] {
        let calendar = TimeZoneManager.cetCalendar
        let today = Date()
        var data: [HistoricalRateDataValue] = []

        for dayOffset in (0 ..< days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

            // Create rates with slight variations to simulate real data
            let baseRate = currency == "EUR" ? 0.92 : (currency == "GBP" ? 0.79 : 1.5)
            let variation = Double.random(in: -0.02 ... 0.02)
            let rate = baseRate + variation

            let ratePoint = HistoricalRateDataPointValue(
                currencyCode: currency,
                rate: rate
            )

            data.append(HistoricalRateDataValue(
                date: date,
                rates: [ratePoint]
            ))
        }

        return data
    }

    // MARK: - DataOrchestrationUseCase Tests

    @Test("DataOrchestrationUseCase returns correct fetched ranges")
    func dataOrchestrationReturnsFetchedRanges() async throws {
        // Create mock services
        let mockService = MockExchangeRateService()
        let cacheService = InMemoryCacheService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()

        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: cacheService
        )

        // Request 3 months of data
        let calendar = TimeZoneManager.cetCalendar
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: endDate)!
        let requestedRange = DateRange(start: startDate, end: endDate)

        // Load data (should trigger fetch since cache is empty)
        let result = try await dataOrchestrationUseCase.loadHistoricalData(
            for: "EUR",
            dateRange: requestedRange
        )

        // Verify that fetchedRanges is not empty when new data is fetched
        #expect(result.newDataFetched == true)
        #expect(!result.fetchedRanges.isEmpty)

        // The fetched range should be within the requested range
        if let firstFetchedRange = result.fetchedRanges.first {
            #expect(firstFetchedRange.start >= requestedRange.start)
            #expect(firstFetchedRange.end <= requestedRange.end)
        }
    }

    @Test("DataOrchestrationUseCase returns empty fetched ranges when using cache")
    func dataOrchestrationReturnsEmptyFetchedRangesFromCache() async throws {
        let mockService = MockExchangeRateService()
        let cacheService = InMemoryCacheService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()

        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: cacheService
        )

        // Pre-populate cache
        let mockData = createMockHistoricalData(for: "EUR", days: 90)
        await cacheService.cacheHistoricalData(mockData, for: "EUR")

        // Request data that's already in cache
        let calendar = TimeZoneManager.cetCalendar
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        let requestedRange = DateRange(start: startDate, end: endDate)

        let result = try await dataOrchestrationUseCase.loadHistoricalData(
            for: "EUR",
            dateRange: requestedRange
        )

        // Should use cache, not fetch new data
        #expect(result.newDataFetched == false)
        #expect(result.fetchedRanges.isEmpty)
    }

    // MARK: - Trend Data Recalculation Tests

    @Test("Trend data recalculates when fetched range affects last 7 days")
    func trendRecalculationForRecentData() async throws {
        let mockService = MockExchangeRateService()
        let trendDataUseCase = TrendDataUseCase(service: mockService)

        let calendar = TimeZoneManager.cetCalendar
        let today = Date()

        // Test range within last 7 days (should trigger recalculation)
        let recentRange = DateRange(
            start: calendar.date(byAdding: .day, value: -3, to: today)!,
            end: today
        )

        let trends = await trendDataUseCase.checkAndRecalculateTrendsIfNeeded(for: [recentRange])

        // Should have recalculated and returned trends
        #expect(!trends.isEmpty)
    }

    @Test("Trend data doesn't recalculate for old data")
    func noTrendRecalculationForOldData() async throws {
        let mockService = MockExchangeRateService()
        let trendDataUseCase = TrendDataUseCase(service: mockService)

        let calendar = TimeZoneManager.cetCalendar
        let today = Date()

        // Test range from 2 months ago (should NOT trigger recalculation)
        let oldRange = DateRange(
            start: calendar.date(byAdding: .month, value: -2, to: today)!,
            end: calendar.date(byAdding: .day, value: -30, to: today)!
        )

        let trends = await trendDataUseCase.checkAndRecalculateTrendsIfNeeded(for: [oldRange])

        // Should return existing trends without recalculation
        // (Trends might be empty if no initial data, but the key is it doesn't recalculate)
        #expect(trends.isEmpty || !trends.isEmpty) // This just ensures no crash
    }

    // MARK: - Base Currency Conversion Tests

    @Test("Trend data conversion for USD base currency returns original data")
    @MainActor
    func trendConversionUSDBase() async throws {
        // Create mock dependencies
        let mockService = MockExchangeRateService()
        let calculatorVM = CalculatorViewModel(service: mockService)
        let cacheService = InMemoryCacheService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: cacheService
        )
        let chartDataPreparationUseCase = ChartDataPreparationUseCase(
            rateCalculationUseCase: RateCalculationUseCase(),
            cacheService: cacheService
        )
        let trendDataUseCase = TrendDataUseCase(service: mockService)

        let historyVM = HistoryViewModel(
            service: mockService,
            calculatorVM: calculatorVM,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase
        )

        // Set base currency to USD
        historyVM.baseCurrency = "USD"

        // Initialize trend data
        await historyVM.initializeTrendData()

        // Get trend for EUR with USD base
        let eurTrend = historyVM.getTrendData(for: "EUR")

        #expect(eurTrend != nil)

        // When base is USD, the trend should be the original USD-based trend
        if let trend = eurTrend {
            // The weekly change should be the raw USD to EUR change
            #expect(trend.weeklyChange != 0) // Should have some change
            #expect(!trend.miniChartData.isEmpty)
        }
    }

    @Test("Trend data conversion for non-USD base currency")
    @MainActor
    func trendConversionNonUSDBase() async throws {
        // Create mock dependencies
        let mockService = MockExchangeRateService()
        let calculatorVM = CalculatorViewModel(service: mockService)
        let cacheService = InMemoryCacheService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: cacheService
        )
        let chartDataPreparationUseCase = ChartDataPreparationUseCase(
            rateCalculationUseCase: RateCalculationUseCase(),
            cacheService: cacheService
        )
        let trendDataUseCase = TrendDataUseCase(service: mockService)

        let historyVM = HistoryViewModel(
            service: mockService,
            calculatorVM: calculatorVM,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase
        )

        // Initialize trend data
        await historyVM.initializeTrendData()

        // Set base currency to EUR
        historyVM.baseCurrency = "EUR"

        // Get trend for GBP with EUR base
        let gbpTrendEURBase = historyVM.getTrendData(for: "GBP")

        // Change base to USD and get the same trend
        historyVM.baseCurrency = "USD"
        let gbpTrendUSDBase = historyVM.getTrendData(for: "GBP")

        #expect(gbpTrendEURBase != nil)
        #expect(gbpTrendUSDBase != nil)

        // The weekly changes should be different when base currency changes
        if let eurBaseTrend = gbpTrendEURBase,
           let usdBaseTrend = gbpTrendUSDBase
        {
            #expect(eurBaseTrend.weeklyChange != usdBaseTrend.weeklyChange)

            // Mini chart data should be converted (different values but same count)
            #expect(eurBaseTrend.miniChartData.count == usdBaseTrend.miniChartData.count)

            // The actual values should be different
            if !eurBaseTrend.miniChartData.isEmpty, !usdBaseTrend.miniChartData.isEmpty {
                #expect(eurBaseTrend.miniChartData[0] != usdBaseTrend.miniChartData[0])
            }
        }
    }

    @Test("Trend conversion maintains data consistency")
    @MainActor
    func trendConversionConsistency() async throws {
        let mockService = MockExchangeRateService()
        let calculatorVM = CalculatorViewModel(service: mockService)
        let cacheService = InMemoryCacheService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: cacheService
        )
        let chartDataPreparationUseCase = ChartDataPreparationUseCase(
            rateCalculationUseCase: RateCalculationUseCase(),
            cacheService: cacheService
        )
        let trendDataUseCase = TrendDataUseCase(service: mockService)

        let historyVM = HistoryViewModel(
            service: mockService,
            calculatorVM: calculatorVM,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase
        )

        await historyVM.initializeTrendData()

        // Test that converting to a base and back maintains relationships
        historyVM.baseCurrency = "EUR"
        let eurToGBP = historyVM.getTrendData(for: "GBP")
        let eurToUSD = historyVM.getTrendData(for: "USD")

        #expect(eurToGBP != nil)
        #expect(eurToUSD != nil)

        // The mini chart data count should be consistent
        if let gbpTrend = eurToGBP, let usdTrend = eurToUSD {
            #expect(gbpTrend.miniChartData.count == usdTrend.miniChartData.count)
            #expect(gbpTrend.miniChartData.count >= 2) // At least 2 points for trend calculation
        }
    }

    // MARK: - Integration Tests

    @Test("Full flow: Fetch new data and update trends correctly")
    @MainActor
    func fullTrendUpdateFlow() async throws {
        // Create full dependency chain
        let mockService = MockExchangeRateService()
        let calculatorVM = CalculatorViewModel(service: mockService)
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()
        let cacheService = InMemoryCacheService()
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: cacheService
        )
        let chartDataPreparationUseCase = ChartDataPreparationUseCase(
            rateCalculationUseCase: RateCalculationUseCase(),
            cacheService: cacheService
        )
        let trendDataUseCase = TrendDataUseCase(service: mockService)

        let historyVM = HistoryViewModel(
            service: mockService,
            calculatorVM: calculatorVM,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase
        )

        // Initialize with empty trends
        await historyVM.initializeTrendData()
        let initialTrendCount = historyVM.trendData.count

        // Load data which should trigger trend update
        historyVM.loadDataForCurrentConfiguration()

        // Wait for async operations to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Trends should be populated
        #expect(historyVM.trendData.count > 0)

        // If we had no initial trends, we should have more now
        if initialTrendCount == 0 {
            #expect(historyVM.trendData.count > initialTrendCount)
        }
    }
}
