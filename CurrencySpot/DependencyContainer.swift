//
//  DependencyContainer.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation
import SwiftData

// MARK: - DependencyContainer

/// Centralized dependency injection container for Clean Architecture
/// Manages all Use Cases and services with proper initialization order
final class DependencyContainer {
    // MARK: - Core Services

    /// Network service for API operations
    let networkService: NetworkService

    /// Persistence service for SwiftData operations
    let persistenceService: PersistenceService

    /// Cache service for in-memory caching
    let cacheService: CacheService

    /// Data coordinator (orchestrates the three services above)
    let dataCoordinator: DataCoordinator

    /// Model container for SwiftData
    let modelContainer: ModelContainer

    // MARK: - Use Cases

    /// Historical data analysis business logic
    let historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase

    /// Data orchestration and loading coordination
    let dataOrchestrationUseCase: DataOrchestrationUseCase

    /// Currency rate calculation logic
    let rateCalculationUseCase: RateCalculationUseCase

    /// Chart data preparation and processing
    let chartDataPreparationUseCase: ChartDataPreparationUseCase

    /// Trend data management
    let trendDataUseCase: TrendDataUseCase

    // MARK: - ViewModels

    /// Calculator ViewModel (single source of truth)
    let calculatorViewModel: CalculatorViewModel

    /// History ViewModel (single source of truth)
    let historyViewModel: HistoryViewModel

    /// Settings ViewModel (single source of truth)
    let settingsViewModel: SettingsViewModel

    // MARK: - Initialization

    /// Initialize dependency container with optional ModelContainer
    /// - Parameter modelContainer: Optional ModelContainer for testing
    @MainActor
    init(modelContainer: ModelContainer? = nil) throws {
        // STEP 1: Initialize ModelContainer
        if let providedContainer = modelContainer {
            self.modelContainer = providedContainer
        } else {
            // Create default ModelContainer for production
            self.modelContainer = try ModelContainer(
                for: ExchangeRateData.self, HistoricalRateData.self, TrendData.self
            )
        }

        // STEP 2: Initialize Core Services
        networkService = FrankfurterNetworkService()
        persistenceService = SwiftDataPersistenceService(modelContainer: self.modelContainer)
        cacheService = InMemoryCacheService()

        // STEP 3: Initialize Data Coordination Layer
        dataCoordinator = DataCoordinator(
            networkService: networkService,
            persistenceService: persistenceService,
            cacheService: cacheService
        )

        // STEP 4: Initialize Use Cases (Business Logic Layer)
        historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()

        dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: dataCoordinator,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: cacheService
        )

        // STEP 5: Initialize ViewModels (Presentation Layer)
        calculatorViewModel = CalculatorViewModel(service: dataCoordinator)

        // STEP 6: Initialize Remaining Use Cases
        rateCalculationUseCase = RateCalculationUseCase()

        chartDataPreparationUseCase = ChartDataPreparationUseCase(
            rateCalculationUseCase: rateCalculationUseCase,
            cacheService: cacheService
        )

        trendDataUseCase = TrendDataUseCase(service: dataCoordinator)

        historyViewModel = HistoryViewModel(
            service: dataCoordinator,
            calculatorVM: calculatorViewModel,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase
        )

        settingsViewModel = SettingsViewModel(
            service: dataCoordinator,
            calculatorViewModel: calculatorViewModel,
            historyViewModel: historyViewModel
        )
    }

    /// Fallback initializer with mock service for critical errors
    /// Used when both regular and in-memory containers fail
    @MainActor
    init(mockService: ExchangeRateService) {
        // STEP 1: Create minimal in-memory container
        do {
            let configuration = ModelConfiguration(
                for: ExchangeRateData.self,
                HistoricalRateData.self,
                TrendData.self,
                isStoredInMemoryOnly: true
            )
            modelContainer = try ModelContainer(
                for: ExchangeRateData.self,
                HistoricalRateData.self,
                TrendData.self,
                configurations: configuration
            )
        } catch {
            // If even in-memory fails, create empty container with minimal schema
            modelContainer = try! ModelContainer(for: Schema([]))
        }

        // STEP 2: Use mock services
        networkService = FrankfurterNetworkService()
        persistenceService = SwiftDataPersistenceService(modelContainer: modelContainer)
        cacheService = InMemoryCacheService()

        // Use the provided mock service as the data coordinator
        dataCoordinator = mockService as? DataCoordinator ?? DataCoordinator(
            networkService: networkService,
            persistenceService: persistenceService,
            cacheService: cacheService
        )

        // STEP 3: Initialize Use Cases
        historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase()

        dataOrchestrationUseCase = DataOrchestrationUseCase(
            service: mockService,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            cacheService: cacheService
        )

        rateCalculationUseCase = RateCalculationUseCase()

        chartDataPreparationUseCase = ChartDataPreparationUseCase(
            rateCalculationUseCase: rateCalculationUseCase,
            cacheService: cacheService
        )

        trendDataUseCase = TrendDataUseCase(service: mockService)

        // STEP 4: Initialize ViewModels with mock service
        calculatorViewModel = CalculatorViewModel(service: mockService)

        historyViewModel = HistoryViewModel(
            service: mockService,
            calculatorVM: calculatorViewModel,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase
        )

        settingsViewModel = SettingsViewModel(
            service: mockService,
            calculatorViewModel: calculatorViewModel,
            historyViewModel: historyViewModel
        )
    }
}
