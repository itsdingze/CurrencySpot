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
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncStore: MockHistoricalSyncStore())
        return HistoryViewModel(
            calculatorVM: makeIsolatedCalculatorViewModel(service: service),
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
            #expect(viewModel.displayedChartDataPoints.isEmpty == false)
        }
    }
}
