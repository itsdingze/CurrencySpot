@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Integration Tests")
struct IntegrationTests {
    private let container: ModelContainer
    private let persistence: SwiftDataPersistenceService
    private let service: DataCoordinator

    init() throws {
        container = try ModelContainer.inMemoryCurrencySpot()
        persistence = SwiftDataPersistenceService(modelContainer: container)
        service = DataCoordinator(
            networkService: MockNetworkService(),
            persistenceService: persistence,
            cacheService: InMemoryCacheService(),
            syncStore: MockHistoricalSyncStore()
        )
    }

    @Test("full save → load → analyze workflow produces chart data without any network fetch")
    func saveLoadAnalyzeWorkflow() async throws {
        let allDates = (3 ... 14).map { String(format: "2025-03-%02d", $0) }
        for (index, dateString) in allDates.enumerated() {
            try await persistence.saveHistoricalExchangeRates([dateString: ["EUR": 1.0 + Double(index) * 0.01]])
        }

        let analysisUseCase = HistoricalDataAnalysisUseCase(syncCoverage: MockHistoricalSyncStore())
        let orchestrationUseCase = DataOrchestrationUseCase(
            repository: service,
            historicalDataAnalysisUseCase: analysisUseCase
        )
        let chartUseCase = ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache())

        let rangeStart = try #require(createCETDate(year: 2025, month: 3, day: 5))
        let rangeEnd = try #require(createCETDate(year: 2025, month: 3, day: 12))
        let dateRange = DateRange.spanning(rangeStart, rangeEnd)
        let loaded = try await orchestrationUseCase.loadHistoricalData(for: "EUR", dateRange: dateRange)

        #expect(loaded.newDataFetched == false)
        #expect(loaded.fetchedRanges.isEmpty)
        #expect(loaded.snapshots.count == 8)

        let chartPoints = await chartUseCase.processHistoricalRateData(
            historicalData: loaded.snapshots,
            baseCurrency: "USD",
            targetCurrency: "EUR",
            dateRange: dateRange,
            exchangeRates: []
        )
        #expect(chartPoints.count == 8)

        let statistics = chartUseCase.calculateStatistics(from: chartPoints)
        #expect(abs(statistics.lowestRate - 1.02) < 0.0001)
        #expect(abs(statistics.currentRate - 1.09) < 0.0001)
        #expect(statistics.trendDirection == .up)
    }

    @Test("earliest and latest stored dates round-trip through save and clear")
    func earliestLatestStoredDateRoundTrip() async throws {
        let initialEarliest = try await service.earliestStoredDate()
        #expect(initialEarliest == nil)

        for dateString in ["2025-03-15", "2025-03-01", "2025-03-08"] {
            try await persistence.saveHistoricalExchangeRates([dateString: ["EUR": 1.21]])
        }

        let earliest = try #require(try await service.earliestStoredDate())
        let latest = try #require(try await service.latestStoredDate())
        #expect(earliest == TimeZoneManager.parseAPIDate("2025-03-01"))
        #expect(latest == TimeZoneManager.parseAPIDate("2025-03-15"))

        try await service.clearAllData()
        let clearedEarliest = try await service.earliestStoredDate()
        #expect(clearedEarliest == nil)
    }

    @Test("CalculatorViewModel default currencies come from the injected defaults, not the environment")
    func calculatorDefaultsAreEnvironmentIndependent() throws {
        let suiteName = "IntegrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("GBP", forKey: UserDefaultsKeys.defaultBaseCurrency)
        defaults.set("JPY", forKey: UserDefaultsKeys.defaultTargetCurrency)

        let viewModel = CalculatorViewModel(
            loadExchangeRatesUseCase: LoadExchangeRatesUseCase(repository: PreviewExchangeRateRepository()),
            ratesStore: ExchangeRatesStore(),
            preferences: UserDefaultsPreferencesStore(userDefaults: defaults),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false))
        )

        #expect(viewModel.baseCurrency == "GBP")
        #expect(viewModel.targetCurrency == "JPY")
    }

    @Test("RefreshAllDataUseCase wipes the repository and signals registered feature resets")
    func refreshAllDataUseCaseClearsAndSignals() async throws {
        try await persistence.saveExchangeRates(["EUR": 0.9])

        let useCase = RefreshAllDataUseCase(repository: service)
        var resetSignals = 0
        useCase.registerResetHandler { resetSignals += 1 }
        useCase.registerResetHandler { resetSignals += 1 }

        try await useCase.execute()

        #expect(resetSignals == 2)
        let persisted = try await persistence.loadExchangeRates()
        #expect(persisted.isEmpty)
    }
}
