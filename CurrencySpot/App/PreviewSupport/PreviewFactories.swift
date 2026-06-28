//
//  PreviewFactories.swift
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
                watchlist: WatchlistStore(),
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
                dataOrchestrationUseCase: dataOrchestrationUseCase,
                chartDataPreparationUseCase: chartDataPreparationUseCase,
                trendDataUseCase: trendDataUseCase
            )
        }
    }

    extension SettingsViewModel {
        static func preview() -> SettingsViewModel {
            SettingsViewModel(refreshAllDataUseCase: RefreshAllDataUseCase(repository: MockExchangeRateService()))
        }
    }

    // MARK: - Loadable State Stubs

    /// Pins CalculatorView's load state: `.stalled` never finishes (loading),
    /// `.failing` always throws (failed).
    struct StubExchangeRateRepository: ExchangeRateRepository {
        enum Behavior {
            case stalled
            case failing
        }

        let behavior: Behavior

        func shouldRefreshRates() async -> Bool { true }

        func fetchExchangeRates() async throws -> [ExchangeRate] {
            switch behavior {
            case .stalled:
                try await Task.sleep(for: .seconds(86_400))
                return []
            case .failing:
                throw AppError.networkError("Could not reach the exchange rate server.")
            }
        }

        func loadExchangeRates() async throws -> [ExchangeRate] {
            try await fetchExchangeRates()
        }

        func lastFetchDate() -> Date? { nil }
    }

    extension CalculatorViewModel {
        static func preview(_ behavior: StubExchangeRateRepository.Behavior) -> CalculatorViewModel {
            CalculatorViewModel(
                repository: StubExchangeRateRepository(behavior: behavior),
                ratesStore: ExchangeRatesStore()
            )
        }
    }

    /// Never finishes, so a chart preview stays in `.loading` indefinitely.
    struct StalledHistoricalRateRepository: HistoricalRateRepository {
        func fetchHistoricalRates(from _: Date, to _: Date) async throws -> [HistoricalRateSnapshot] {
            try await stall()
            return []
        }

        func waitForPendingHistoricalWrites() async {}

        func fetchTransientHistoricalRates(for _: [CurrencyCode], from _: Date, to _: Date) async throws -> [HistoricalRateSnapshot] {
            try await stall()
            return []
        }

        func fetchAndPersistHistoricalRates(from _: Date, to _: Date) async throws { try await stall() }

        func loadHistoricalRates(in _: DateRange) async throws -> [HistoricalRateSnapshot] {
            try await stall()
            return []
        }

        func earliestStoredDate() async throws -> Date? {
            try await stall()
            return nil
        }

        func latestStoredDate() async throws -> Date? {
            try await stall()
            return nil
        }

        func cachedHistoricalRates() async -> [HistoricalRateSnapshot] {
            try? await stall()
            return []
        }

        func mergeCachedHistoricalRates(_: [HistoricalRateSnapshot]) async -> [HistoricalRateSnapshot] { [] }

        private func stall() async throws { try await Task.sleep(for: .seconds(86_400)) }
    }

    extension HistoryViewModel {
        /// A view model whose chart load never finishes, pinning `.loading`.
        static func previewLoading() -> HistoryViewModel {
            let mockService = MockExchangeRateService()
            let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncStore: UserDefaultsHistoricalSyncStore())

            return HistoryViewModel(
                ratesStore: ExchangeRatesStore(),
                watchlist: WatchlistStore(),
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
                dataOrchestrationUseCase: DataOrchestrationUseCase(
                    repository: StalledHistoricalRateRepository(),
                    historicalDataAnalysisUseCase: historicalDataAnalysisUseCase
                ),
                chartDataPreparationUseCase: ChartDataPreparationUseCase(cacheService: InMemoryCacheService()),
                trendDataUseCase: TrendDataUseCase(
                    trendRepository: mockService,
                    historicalRateRepository: mockService
                )
            )
        }
    }

#endif
