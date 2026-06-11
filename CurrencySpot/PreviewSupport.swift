//
//  PreviewSupport.swift
//  CurrencySpot
//
//  Preview-only factories, compiled out of release builds.
//

#if DEBUG

    import Foundation
    import SwiftData
    import SwiftUI

    // MARK: - DependencyContainer Preview Factory

    extension DependencyContainer {
        /// Creates a preview-ready dependency container with in-memory storage.
        @MainActor
        static func preview() -> DependencyContainer {
            do {
                return DependencyContainer(modelContainer: try ModelContainer.inMemoryCurrencySpot())
            } catch {
                OSLogLoggerService().fault("Failed to create preview ModelContainer: \(error)", category: .app)
                fatalError("Preview ModelContainer creation failed: \(error)")
            }
        }
    }

    // MARK: - ViewModel Preview Factories

    extension CalculatorViewModel {
        static func preview() -> CalculatorViewModel {
            CalculatorViewModel(
                repository: MockExchangeRateService(),
                ratesStore: ExchangeRatesStore()
            )
        }
    }

    extension HistoryViewModel {
        static func preview() -> HistoryViewModel {
            let mockService = MockExchangeRateService()
            let syncStore = UserDefaultsHistoricalSyncStore()
            let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncStore: syncStore)
            let dataOrchestrationUseCase = DataOrchestrationUseCase(
                repository: mockService,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase
            )
            let chartDataPreparationUseCase = ChartDataPreparationUseCase(cacheService: InMemoryCacheService())
            let trendDataUseCase = TrendDataUseCase(
                trendRepository: mockService,
                historicalRateRepository: mockService
            )

            return HistoryViewModel(
                ratesStore: ExchangeRatesStore(),
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
                dataOrchestrationUseCase: dataOrchestrationUseCase,
                chartDataPreparationUseCase: chartDataPreparationUseCase,
                trendDataUseCase: trendDataUseCase
            )
        }
    }

    extension SettingsViewModel {
        static func preview() -> SettingsViewModel {
            SettingsViewModel(clearAllDataUseCase: ClearAllDataUseCase(repository: MockExchangeRateService()))
        }
    }

#endif
