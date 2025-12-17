//
//  IntegrationTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 7/9/25.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

// MARK: - Legacy Test File

// This file contains legacy tests that are being migrated to separate files
// New tests should be added to appropriate test files in the Tests directory

// MARK: - Integration Tests

@Suite("Integration Tests")
@MainActor
struct IntegrationTests {
    @Test("Full integration test with real data flow")
    func fullIntegrationTestWithRealDataFlow() async throws {
        // This test verifies the complete data flow from service to view model
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ExchangeRateData.self, HistoricalRateData.self, TrendData.self,
            configurations: config
        )

        let networkService = FrankfurterNetworkService()
        let persistenceService = SwiftDataPersistenceService(modelContainer: container)
        let cacheService = InMemoryCacheService()
        let service = DataCoordinator(
            networkService: networkService,
            persistenceService: persistenceService,
            cacheService: cacheService
        )
        let calculatorVM = CalculatorViewModel(service: service)
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()
        let dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: service,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: cacheService
        )
        let rateCalculationUseCase = RateCalculationUseCase()
        let chartDataPreparationUseCase = ChartDataPreparationUseCase(
            rateCalculationUseCase: rateCalculationUseCase,
            cacheService: cacheService
        )
        let trendDataUseCase = TrendDataUseCase(service: service)

        let viewModel = HistoryViewModel(
            service: service,
            calculatorVM: calculatorVM,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase
        )

        // Verify initial state
        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.targetCurrency == "EUR")
        #expect(viewModel.displayedChartDataPoints.isEmpty)

        // Test service operations
        try await service.clearAllData()
        let initialEarliest = try await service.getEarliestStoredDate()
        #expect(initialEarliest == nil)

        // Add some test data
        let testRates = ["2025-03-15": ["EUR": 1.21, "GBP": 0.85]]
        try await service.saveHistoricalExchangeRates(testRates)

        let finalEarliest = try await service.getEarliestStoredDate()
        // Use CET calendar to match how dates are stored
        let calendar = TimeZoneManager.cetCalendar
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 15
        components.timeZone = TimeZoneManager.cetTimeZone
        let expectedDate = calendar.date(from: components)!

        // Compare only the date components, ignoring time differences
        let actualComponents = calendar.dateComponents([.year, .month, .day], from: finalEarliest!)
        let expectedComponents = calendar.dateComponents([.year, .month, .day], from: expectedDate)
        #expect(actualComponents == expectedComponents)
    }
}
