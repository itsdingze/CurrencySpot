//
//  ViewModelTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 7/17/25.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("ViewModel Tests")
@MainActor
struct ViewModelTests {
    // Builds a HistoryViewModel backed entirely by MockExchangeRateService so trend
    // data is the deterministic MockExchangeRates.trendData fixture and no network runs.
    private static func makeHistoryViewModel() -> HistoryViewModel {
        let service = MockExchangeRateService()
        let cacheService = InMemoryCacheService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()
        return HistoryViewModel(
            service: service,
            calculatorVM: CalculatorViewModel(service: service),
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: DataOrchestrationUseCase(
                service: service,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
                cacheService: cacheService
            ),
            chartDataPreparationUseCase: ChartDataPreparationUseCase(
                rateCalculationUseCase: RateCalculationUseCase(),
                cacheService: cacheService
            ),
            trendDataUseCase: TrendDataUseCase(service: service)
        )
    }

    @Suite("HistoryViewModel Tests")
    @MainActor
    struct HistoryViewModelTests {
        let viewModel = ViewModelTests.makeHistoryViewModel()

        @Test("Initializes with default currencies and no chart data")
        func initializesWithDefaults() {
            #expect(viewModel.baseCurrency == "USD")
            #expect(viewModel.targetCurrency == "EUR")
            #expect(viewModel.displayedChartDataPoints.isEmpty)
        }

        @Test("initializeTrendData loads the full fixture trend set")
        func initializeTrendDataLoadsFixture() async {
            await viewModel.initializeTrendData()

            // MockExchangeRateService.loadTrendData() returns the MockExchangeRates.trendData fixture.
            #expect(viewModel.trendData.count == MockExchangeRates.trendData.count)
        }

        @Test("getTrendData returns the raw USD-based trend unchanged when base is USD")
        func getTrendDataUSDBasePassthrough() async {
            await viewModel.initializeTrendData()
            // Default base currency is USD, so trends come straight from the fixture.

            let gbp = viewModel.getTrendData(for: "GBP")
            #expect(gbp?.weeklyChange == -0.5)
            #expect(gbp?.miniChartData == [0.76, 0.755, 0.753, 0.751, 0.749, 0.748, 0.75])

            let eur = viewModel.getTrendData(for: "EUR")
            #expect(eur?.weeklyChange == 0.1)
        }

        @Test("Loading the current configuration populates displayed chart data")
        func loadPopulatesChartData() async {
            #expect(viewModel.displayedChartDataPoints.isEmpty)
            await viewModel.loadCurrentConfigurationAndWait()
            #expect(!viewModel.displayedChartDataPoints.isEmpty)
        }
    }
}

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    /// Asserts the value's date is exactly midnight 2025-03-15 in the CET (Europe/Paris) calendar,
    /// decomposed from the value itself rather than re-running the parser the init uses.
    private func assertIsMarch15CET(_ date: Date) {
        let components = TimeZoneManager.cetCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        #expect(components.year == 2025)
        #expect(components.month == 3)
        #expect(components.day == 15)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }

    @Test("HistoricalRateDataValue rejects invalid dates and parses valid ones")
    func historicalRateDataValueHandlesInvalidDates() throws {
        let rates = [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21)]

        let error = try #require(throws: AppError.self) {
            try HistoricalRateDataValue(dateString: "invalid-date", rates: rates)
        }
        guard case .dataValidationError = error else {
            Issue.record("Expected .dataValidationError, got \(error)")
            return
        }

        let validValue = try HistoricalRateDataValue(dateString: "2025-03-15", rates: rates)
        assertIsMarch15CET(validValue.date)
    }

    @Test("SwiftData model rejects invalid dates and parses valid ones")
    func swiftDataModelHandlesInvalidDates() throws {
        let rates = [HistoricalRateDataPoint(currencyCode: "EUR", rate: 1.21)]

        let error = try #require(throws: AppError.self) {
            try HistoricalRateData(dateString: "invalid-date", rates: rates)
        }
        guard case .dataValidationError = error else {
            Issue.record("Expected .dataValidationError, got \(error)")
            return
        }

        let validData = try HistoricalRateData(dateString: "2025-03-15", rates: rates)
        assertIsMarch15CET(validData.date)
    }
}
