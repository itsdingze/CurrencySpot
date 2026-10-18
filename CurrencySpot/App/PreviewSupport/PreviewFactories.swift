#if DEBUG

    import Foundation
    import SwiftUI

    // MARK: - Container Preview Factories

    extension DependencyContainer {
        static func preview() -> DependencyContainer {
            makePreview(exchangeRateRepository: nil, historicalRepository: nil)
        }

        static func preview(exchangeRateRepository: ExchangeRateRepository) -> DependencyContainer {
            makePreview(exchangeRateRepository: exchangeRateRepository, historicalRepository: nil)
        }

        fileprivate static func preview(historicalRepository: any HistoricalRateRepository & ArchiveRepository) -> DependencyContainer {
            makePreview(exchangeRateRepository: nil, historicalRepository: historicalRepository)
        }

        private static func makePreview(
            exchangeRateRepository: ExchangeRateRepository?,
            historicalRepository: (any HistoricalRateRepository & ArchiveRepository)?
        ) -> DependencyContainer {
            DependencyContainer(
                appState: AppState(networkMonitor: NetworkMonitor(isConnected: true)),
                userDefaults: .previewSuite,
                preferences: InMemoryPreferencesStore(),
                languageStore: InMemoryAppLanguageStore(),
                networkService: PreviewNetworkService(today: .now),
                syncStore: InMemoryHistoricalSyncStore(),
                fetchDateStore: InMemoryRatesFetchDateStore(),
                exchangeRateRepository: exchangeRateRepository,
                historicalRepository: historicalRepository,
                cameraPermissionService: StubCameraPermissionService(status: .authorized),
                stillTextRecognizer: StubStillTextRecognizer(),
                torchService: InMemoryTorchService()
            )
        }
    }

    extension UserDefaults {
        fileprivate static let previewSuite: UserDefaults = {
            let suite = UserDefaults(suiteName: "CurrencySpot.previews") ?? .standard
            suite.removePersistentDomain(forName: "CurrencySpot.previews")
            return suite
        }()
    }

    // MARK: - History Preview Factories

    extension CurrencyHistoryViewModel {
        static func preview() -> CurrencyHistoryViewModel {
            DependencyContainer.preview().makeCurrencyHistoryViewModel(base: .usd, target: .eur)
        }

        static func previewLoading() -> CurrencyHistoryViewModel {
            DependencyContainer.preview(historicalRepository: StubHistoricalRateRepository(behavior: .stalled))
                .makeCurrencyHistoryViewModel(base: .usd, target: .eur)
        }

        static func previewFailed() -> CurrencyHistoryViewModel {
            let viewModel = DependencyContainer.preview(historicalRepository: StubHistoricalRateRepository(behavior: .failing))
                .makeCurrencyHistoryViewModel(base: .usd, target: .eur)
            viewModel.selectedTimeRange = .fiveYears
            return viewModel
        }
    }

    // MARK: - Loadable State Stubs

    struct StubExchangeRateRepository: ExchangeRateRepository {
        enum Behavior {
            case stalled
            case failing
        }

        let behavior: Behavior

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

    private struct StubHistoricalRateRepository: HistoricalRateRepository, ArchiveRepository {
        enum Behavior {
            case stalled
            case failing
        }

        let behavior: Behavior

        func cachedHistoricalRates() async -> [HistoricalRateSnapshot] {
            try? await stall()
            return []
        }

        func fetchAndMergeHistoricalRates(in _: DateRange) async throws -> [HistoricalRateSnapshot] {
            try await stall()
            return []
        }

        func loadAndMergeStoredHistoricalRates(in _: DateRange) async throws -> [HistoricalRateSnapshot] {
            try await stall()
            return []
        }

        func loadStoredHistoricalRates(in _: DateRange) async throws -> [HistoricalRateSnapshot] {
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

        func fetchTransientHistoricalRates(for _: [CurrencyCode], in _: DateRange) async throws -> [HistoricalRateSnapshot] {
            try await stall()
            return []
        }

        func fetchAndPersistHistoricalRates(in _: DateRange) async throws {
            try await stall()
        }

        func pruneHistoricalRates(before _: Date) async throws {}

        func archiveStoredBounds() async throws -> (earliest: Date?, latest: Date?) {
            try await stall()
            return (nil, nil)
        }

        private func stall() async throws {
            switch behavior {
            case .stalled: try await Task.sleep(for: .seconds(86_400))
            case .failing: throw AppError.networkError("Preview failure")
            }
        }
    }

#endif
