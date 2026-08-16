#if DEBUG

    import Foundation
    import SwiftUI

    // MARK: - Container Preview Factory

    extension DependencyContainer {
        static func preview() -> DependencyContainer {
            DependencyContainer(
                userDefaults: .previewSuite,
                preferences: InMemoryPreferencesStore(),
                networkService: PreviewNetworkService(),
                syncStore: InMemoryHistoricalSyncStore()
            )
        }
    }

    extension UserDefaults {
        static let previewSuite: UserDefaults = {
            let suite = UserDefaults(suiteName: "CurrencySpot.previews") ?? .standard
            suite.removePersistentDomain(forName: "CurrencySpot.previews")
            return suite
        }()
    }

    // MARK: - ViewModel Preview Factories

    extension HistoryViewModel {
        static func preview() -> HistoryViewModel {
            let mockService = PreviewExchangeRateRepository()
            let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncCoverage: InMemorySyncCoverage())
            let dataOrchestrationUseCase = DataOrchestrationUseCase(
                repository: mockService,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase
            )
            let chartDataPreparationUseCase = ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache())
            let trendDataUseCase = TrendDataUseCase(
                trendRepository: mockService,
                historicalRateRepository: mockService
            )

            return HistoryViewModel(
                ratesStore: ExchangeRatesStore(),
                watchlist: WatchlistStore(userDefaults: .previewSuite),
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
                dataOrchestrationUseCase: dataOrchestrationUseCase,
                chartDataPreparationUseCase: chartDataPreparationUseCase,
                trendDataUseCase: trendDataUseCase,
                preferences: InMemoryPreferencesStore()
            )
        }
    }

    // MARK: - Loadable State Stubs

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
                loadExchangeRatesUseCase: LoadExchangeRatesUseCase(repository: StubExchangeRateRepository(behavior: behavior)),
                ratesStore: ExchangeRatesStore(),
                preferences: InMemoryPreferencesStore()
            )
        }
    }

    struct StubHistoricalRateRepository: HistoricalRateRepository {
        enum Behavior {
            case stalled
            case failing
        }

        let behavior: Behavior

        func fetchHistoricalRates(in _: DateRange) async throws -> [HistoricalRateSnapshot] {
            try await stall()
            return []
        }

        func waitForPendingHistoricalWrites() async {}

        func fetchTransientHistoricalRates(for _: [CurrencyCode], in _: DateRange) async throws -> [HistoricalRateSnapshot] {
            try await stall()
            return []
        }

        func fetchAndPersistHistoricalRates(in _: DateRange) async throws { try await stall() }

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

        private func stall() async throws {
            switch behavior {
            case .stalled: try await Task.sleep(for: .seconds(86_400))
            case .failing: throw AppError.networkError("Preview failure")
            }
        }
    }

    extension HistoryViewModel {
        static func previewLoading() -> HistoryViewModel {
            preview(.stalled)
        }

        static func previewFailed() -> HistoryViewModel {
            preview(.failing)
        }

        private static func preview(_ behavior: StubHistoricalRateRepository.Behavior) -> HistoryViewModel {
            let mockService = PreviewExchangeRateRepository()
            let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncCoverage: InMemorySyncCoverage())

            return HistoryViewModel(
                ratesStore: ExchangeRatesStore(),
                watchlist: WatchlistStore(userDefaults: .previewSuite),
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
                dataOrchestrationUseCase: DataOrchestrationUseCase(
                    repository: StubHistoricalRateRepository(behavior: behavior),
                    historicalDataAnalysisUseCase: historicalDataAnalysisUseCase
                ),
                chartDataPreparationUseCase: ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache()),
                trendDataUseCase: TrendDataUseCase(
                    trendRepository: mockService,
                    historicalRateRepository: mockService
                ),
                preferences: InMemoryPreferencesStore()
            )
        }
    }

#endif
