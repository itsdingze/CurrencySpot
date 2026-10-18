@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Integration Tests")
struct IntegrationTests {
    private static let now = createCETDate(year: 2025, month: 3, day: 14)!

    private let container: ModelContainer
    private let persistence: SwiftDataPersistenceService
    private let service: DataCoordinator
    private let isolatedDefaults = IsolatedDefaults()

    init() throws {
        container = try ModelContainer.inMemoryCurrencySpot()
        persistence = SwiftDataPersistenceService(modelContainer: container)
        service = DataCoordinator(
            networkService: MockNetworkService(),
            persistenceService: persistence,
            cacheService: InMemoryCacheService(),
            syncStore: MockHistoricalSyncStore(),
            fetchDateStore: InMemoryRatesFetchDateStore(),
            dateProvider: FixedDateProvider(Self.now)
        )
    }

    @Test("full save → load → analyze workflow produces chart data without any network fetch")
    func saveLoadAnalyzeWorkflow() async throws {
        let allDates = (3 ... 14).map { String(format: "2025-03-%02d", $0) }
        for (index, dateString) in allDates.enumerated() {
            try await persistence.saveHistoricalExchangeRates([dateString: ["EUR": 1.0 + Double(index) * 0.01]])
        }

        let analysisUseCase = HistoricalDataAnalysisUseCase(
            syncCoverage: MockHistoricalSyncStore(),
            dateProvider: FixedDateProvider(Self.now)
        )
        let loadUseCase = LoadHistoricalRatesUseCase(
            repository: service,
            archive: service,
            backfill: BackfillArchiveUseCase(archive: service, analysis: analysisUseCase, clock: GatedClock()),
            analysis: analysisUseCase
        )
        let chartUseCase = ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache())

        let rangeStart = try #require(createCETDate(year: 2025, month: 3, day: 5))
        let rangeEnd = try #require(createCETDate(year: 2025, month: 3, day: 12))
        let dateRange = DateRange.spanning(rangeStart, rangeEnd)
        let loaded = try await loadUseCase.loadHistoricalData(for: "EUR", base: "USD", dateRange: dateRange)

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

        let statistics = try #require(chartUseCase.calculateStatistics(from: chartPoints))
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
        #expect(earliest == CETCalendar.date(fromDayString: "2025-03-01"))
        #expect(latest == CETCalendar.date(fromDayString: "2025-03-15"))

        try await service.clearAllData()
        let clearedEarliest = try await service.earliestStoredDate()
        #expect(clearedEarliest == nil)
    }

    @Test("CalculatorViewModel default currencies come from the injected defaults, not the environment")
    func calculatorDefaultsAreEnvironmentIndependent() throws {
        let defaults = try isolatedDefaults.make()
        defaults.set("GBP", forKey: UserDefaultsKeys.defaultBaseCurrency)
        defaults.set("JPY", forKey: UserDefaultsKeys.defaultTargetCurrency)

        let viewModel = CalculatorViewModel(
            loadExchangeRatesUseCase: LoadExchangeRatesUseCase(
                repository: PreviewExchangeRateRepository(today: MockExchangeRateRepository.now),
                dateProvider: FixedDateProvider(MockExchangeRateRepository.now)
            ),
            calculateConversionUseCase: CalculateConversionUseCase(),
            ratesStore: ExchangeRatesStore(),
            preferences: UserDefaultsPreferencesStore(userDefaults: defaults),
            favorites: CurrencyCodeListStore(
                defaults: defaults,
                key: UserDefaultsKeys.favoriteCurrencies,
                seed: CurrencyDefaults.favoriteCurrencies
            ),
            appState: AppState(networkMonitor: NetworkMonitor(isConnected: true))
        )

        #expect(viewModel.baseCurrency == "GBP")
        #expect(viewModel.targetCurrency == "JPY")
    }

    @Test("RefreshAllDataUseCase wipes the repository and resets the archive backfill")
    func refreshAllDataUseCaseClearsAndResets() async throws {
        try await persistence.saveExchangeRates([ExchangeRate(currencyCode: "EUR", rate: 0.9)])
        let backfill = SpyBackfillReset()

        try await RefreshAllDataUseCase(repository: service, backfill: backfill).execute()

        #expect(backfill.resetCount == 1)
        #expect(try await persistence.loadExchangeRates().isEmpty)
    }
}

private final class SpyBackfillReset: ArchiveBackfillResetting {
    private(set) var resetCount = 0

    func reset() {
        resetCount += 1
    }
}
