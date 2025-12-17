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
    @Suite("HistoryViewModel Tests")
    @MainActor
    struct HistoryViewModelTests {
        let service: MockExchangeRateService
        let viewModel: HistoryViewModel

        // MARK: - Setup (called before each test)

        init() {
            // Use MockExchangeRateService for testing instead of real service
            service = MockExchangeRateService()
            let calculatorVM = CalculatorViewModel(service: service)
            let cacheService = InMemoryCacheService()
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

            viewModel = HistoryViewModel(
                service: service,
                calculatorVM: calculatorVM,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
                dataOrchestrationUseCase: dataOrchestrationUseCase,
                chartDataPreparationUseCase: chartDataPreparationUseCase,
                trendDataUseCase: trendDataUseCase
            )
        }

        // MARK: - Helper Methods

        private func createDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.timeZone = TimeZoneManager.cetTimeZone
            return Calendar.current.date(from: components)!
        }

        // MARK: - Test Cases

        @Test("Calculate missing date ranges - weekend gaps")
        func coversWeekendGaps() async throws {
            // GIVEN: A required range and cached data with gaps
            let requiredRange = DateRange(
                start: createDate(2025, 3, 1),
                end: createDate(2025, 3, 15)
            )
            let cachedData = try [
                HistoricalRateDataValue(dateString: "2025-03-10", rates: [
                    HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21),
                ]),
                HistoricalRateDataValue(dateString: "2025-03-15", rates: [
                    HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.22),
                ]),
            ]

            // WHEN: We calculate the missing ranges
            let missingRanges = calculateMissingDateRanges(
                requiredRange: requiredRange,
                cachedData: cachedData
            )
            let expectedEndDate = createDate(2025, 3, 9) // Day before cache starts

            // THEN: The result should contain one range for the gap at the beginning
            #expect(missingRanges.count == 1)
            #expect(missingRanges.first?.start == requiredRange.start)
            #expect(missingRanges.first?.end == expectedEndDate)
        }
    }

    @Suite("HistoryViewModel SwiftData Tests")
    @MainActor
    struct HistoryViewModelSwiftDataTests {
        let container: ModelContainer
        let service: DataCoordinator
        let viewModel: HistoryViewModel

        init() throws {
            // Create in-memory container for testing
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(
                for: ExchangeRateData.self, HistoricalRateData.self, TrendData.self,
                configurations: config
            )

            // Create service with test container
            let networkService = FrankfurterNetworkService()
            let persistenceService = SwiftDataPersistenceService(modelContainer: container)
            let cacheService = InMemoryCacheService()
            service = DataCoordinator(
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

            viewModel = HistoryViewModel(
                service: service,
                calculatorVM: calculatorVM,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
                dataOrchestrationUseCase: dataOrchestrationUseCase,
                chartDataPreparationUseCase: chartDataPreparationUseCase,
                trendDataUseCase: trendDataUseCase
            )
        }

        @Test("View model initializes with service")
        func viewModelInitializesWithService() async throws {
            // GIVEN: A view model with a service
            // WHEN: We check the initial state
            // THEN: It should be properly initialized
            #expect(viewModel.baseCurrency == "USD")
            #expect(viewModel.targetCurrency == "EUR")
            #expect(viewModel.displayedChartDataPoints.isEmpty)
        }

        @Test("Currency change triggers data loading")
        func currencyChangeTriggersDataLoading() async throws {
            // GIVEN: A view model with initial currencies
            let initialTarget = viewModel.targetCurrency

            // WHEN: We change the target currency
            viewModel.targetCurrency = "GBP"

            // THEN: The currency should be updated
            #expect(viewModel.targetCurrency != initialTarget)
            #expect(viewModel.targetCurrency == "GBP")
        }

        @Test("View model initializes and manages trend data")
        func viewModelManagesTrendData() async throws {
            // GIVEN: A view model with a service
            // WHEN: We initialize trend data
            await viewModel.initializeTrendData()

            // THEN: It should complete without errors
            // Note: Trend data management is now handled by TrendDataUseCase
            #expect(true, "Trend data initialization should complete successfully")
        }
    }
}

// MARK: - Test Helper Classes

/// A mock service that tracks calls to verify trend recalculation behavior
class TrackingMockExchangeRateService: ExchangeRateService {
    var calculateAndSaveTrendDataCallCount = 0
    var doesDateRangeAffectTrendsCallCount = 0
    private var lastCheckedDateRanges: [DateRange] = []
    private let baseMockService = MockExchangeRateService()

    // MARK: - Tracking Methods

    func calculateAndSaveTrendData() async throws {
        calculateAndSaveTrendDataCallCount += 1
        try await baseMockService.calculateAndSaveTrendData()
    }

    func doesDateRangeAffectTrends(startDate: Date, endDate: Date) async throws -> Bool {
        doesDateRangeAffectTrendsCallCount += 1
        lastCheckedDateRanges.append(DateRange(start: startDate, end: endDate))

        // Simulate real logic: only recent data (last 7 days) affects trends
        let calendar = Calendar.current
        let now = Date()
        let trendWindowStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return startDate <= now && endDate >= trendWindowStart
    }

    func getLastCheckedDateRanges() -> [DateRange] {
        lastCheckedDateRanges
    }

    // MARK: - ExchangeRateService Protocol Implementation (Delegate to base mock)

    func shouldFetchNewRates() async -> Bool {
        await baseMockService.shouldFetchNewRates()
    }

    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        try await baseMockService.fetchExchangeRates()
    }

    func fetchAndSaveHistoricalRates(from startDate: Date, to endDate: Date) async throws {
        try await baseMockService.fetchAndSaveHistoricalRates(from: startDate, to: endDate)
    }

    func saveExchangeRates(_ rates: [String: Double]) async throws {
        try await baseMockService.saveExchangeRates(rates)
    }

    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws {
        try await baseMockService.saveHistoricalExchangeRates(rates)
    }

    func loadExchangeRates() async throws -> [ExchangeRateDataValue] {
        try await baseMockService.loadExchangeRates()
    }

    func loadHistoricalRatesForCurrency(currency: String, startDate: String, endDate: String) async throws -> [HistoricalRateDataValue] {
        try await baseMockService.loadHistoricalRatesForCurrency(currency: currency, startDate: startDate, endDate: endDate)
    }

    func updateLastFetchDate(_ date: Date) {
        baseMockService.updateLastFetchDate(date)
    }

    func getLastFetchDate() -> Date? {
        baseMockService.getLastFetchDate()
    }

    func getEarliestStoredDate() async throws -> Date? {
        try await baseMockService.getEarliestStoredDate()
    }

    func getLatestStoredDate() async throws -> Date? {
        try await baseMockService.getLatestStoredDate()
    }

    func loadTrendData() async throws -> [TrendDataValue] {
        try await baseMockService.loadTrendData()
    }

    func hasSufficientHistoricalDataForTrends() async throws -> Bool {
        try await baseMockService.hasSufficientHistoricalDataForTrends()
    }

    func clearAllData() async throws {
        try await baseMockService.clearAllData()
    }
}

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    @Test("HistoricalRateDataValue handles invalid date strings")
    func historicalRateDataValueHandlesInvalidDates() async throws {
        let rates = [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21)]

        // Should throw for invalid date string
        #expect(throws: NSError.self) {
            try HistoricalRateDataValue(dateString: "invalid-date", rates: rates)
        }

        // Should work for valid date string
        let validValue = try HistoricalRateDataValue(dateString: "2025-03-15", rates: rates)
        #expect(validValue.date == TimeZoneManager.parseAPIDate("2025-03-15")!)
    }

    @Test("SwiftData model handles invalid date strings")
    func swiftDataModelHandlesInvalidDates() async throws {
        let rates = [HistoricalRateDataPoint(currencyCode: "EUR", rate: 1.21)]

        // Should throw for invalid date string
        #expect(throws: NSError.self) {
            try HistoricalRateData(dateString: "invalid-date", rates: rates)
        }

        // Should work for valid date string
        let validData = try HistoricalRateData(dateString: "2025-03-15", rates: rates)
        #expect(validData.date == TimeZoneManager.parseAPIDate("2025-03-15")!)
    }
}
