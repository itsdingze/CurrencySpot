@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Data Coordinator Repository Tests")
struct DataCoordinatorRatesTests {
    let container: ModelContainer
    let networkService: MockNetworkService
    let syncStore: MockHistoricalSyncStore
    let persistence: SwiftDataPersistenceService
    let service: DataCoordinator

    init() throws {
        container = try ModelContainer.inMemoryCurrencySpot()
        networkService = MockNetworkService()
        syncStore = MockHistoricalSyncStore()
        persistence = SwiftDataPersistenceService(modelContainer: container)
        service = DataCoordinator(
            networkService: networkService,
            persistenceService: persistence,
            cacheService: InMemoryCacheService(),
            syncStore: syncStore
        )
    }

    private func cetDate(_ y: Int, _ m: Int, _ d: Int) throws -> Date {
        try #require(createCETDate(year: y, month: m, day: d))
    }

    private func range(_ start: String, _ end: String) throws -> DateRange {
        try DateRange.make(
            start: #require(TimeZoneManager.parseAPIDate(start)),
            end: #require(TimeZoneManager.parseAPIDate(end))
        )
    }

    private func setupHistoricalData(_ dateStrings: [String]) async throws {
        for dateString in dateStrings {
            let rates = ["EUR": 1.21, "GBP": 0.85, "JPY": 110.0]
            try await persistence.saveHistoricalExchangeRates([dateString: rates])
        }
    }

    private static func makeDefaults() throws -> (defaults: UserDefaults, name: String) {
        let name = "DataCoordinatorRatesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    @Test("clearAllData resets the historical sync coverage window")
    func clearAllDataResetsSyncCoverage() async throws {
        syncStore.record(from: try cetDate(2025, 1, 1), through: try cetDate(2025, 1, 10), at: Date())

        try await service.clearAllData()

        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
        #expect(syncStore.checkedAt == nil)
    }

    @Test("loadHistoricalRates reads persistence, not a narrower stale in-memory cache")
    func loadHistoricalReadsPersistenceNotStaleCache() async throws {
        let cacheService = InMemoryCacheService()
        let coordinator = DataCoordinator(
            networkService: MockNetworkService(),
            persistenceService: persistence,
            cacheService: cacheService,
            syncStore: MockHistoricalSyncStore()
        )

        let wideDates = (3 ... 12).map { String(format: "2025-03-%02d", $0) }
        for dateString in wideDates {
            try await persistence.saveHistoricalExchangeRates([dateString: ["EUR": 1.21]])
        }

        let narrow = try [
            HistoricalRateSnapshot(dateString: "2025-03-11", rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.21)]),
            HistoricalRateSnapshot(dateString: "2025-03-12", rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.21)]),
        ]
        _ = await coordinator.mergeCachedHistoricalRates(narrow)

        let result = try await coordinator.loadHistoricalRates(in: try range("2025-03-01", "2025-03-31"))
        #expect(result.count == wideDates.count)
    }

    @Test("FrankfurterNetworkService should fetch on first run (no stored fetch date)")
    func shouldFetchOnFirstRun() async throws {
        let (defaults, name) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let networkService = FrankfurterNetworkService(api: FrankfurterAPI(retryManager: RetryManager()), userDefaults: defaults)

        #expect(networkService.getLastFetchDate() == nil)
        let shouldFetch = await networkService.shouldFetchNewRates()
        #expect(shouldFetch == true)
    }

    @Test("FrankfurterNetworkService round-trips the last fetch date through its injected defaults")
    func lastFetchDateRoundTrip() async throws {
        let (defaults, name) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let networkService = FrankfurterNetworkService(api: FrankfurterAPI(retryManager: RetryManager()), userDefaults: defaults)

        let fetchDate = try cetDate(2025, 3, 12)
        networkService.updateLastFetchDate(fetchDate)

        #expect(networkService.getLastFetchDate() == fetchDate)
        #expect(defaults.object(forKey: UserDefaultsKeys.lastFetchDate) as? Date == fetchDate)
    }

    @Test("fetchExchangeRates maps the DTO to domain values, persists, and stamps the fetch date")
    func fetchExchangeRatesOwnsPostFetchBookkeeping() async throws {
        networkService.exchangeRatesResult = .success(
            ExchangeRatesResponse(base: "USD", date: "2025-03-12", rates: ["EUR": 0.9, "GBP": 0.75])
        )

        let rates = try await service.fetchExchangeRates()

        #expect(rates.contains { $0.currencyCode == "USD" && $0.rate == 1.0 })
        #expect(rates.contains { $0.currencyCode == "EUR" && $0.rate == 0.9 })

        let persisted = try await persistence.loadExchangeRates()
        #expect(persisted.count == 3)
        #expect(networkService.lastFetchDate != nil)
        #expect(service.lastFetchDate() != nil)
    }

    @Test("fetchExchangeRates throws on network failure instead of silently substituting saved rates")
    func fetchThrowsOnNetworkFailureWithoutSilentFallback() async throws {
        try await persistence.saveExchangeRates(["EUR": 0.9])
        networkService.exchangeRatesResult = .failure(AppError.networkError("server down"))

        await #expect(throws: AppError.self) {
            _ = try await service.fetchExchangeRates()
        }
        #expect(service.lastFetchDate() == nil)
    }

    @Test("Get earliest stored date returns correct date")
    func getEarliestStoredDateReturnsCorrectDate() async throws {
        let testDates = ["2025-03-15", "2025-03-01", "2025-03-10", "2025-03-05"]
        try await setupHistoricalData(testDates)

        let earliestDate = try #require(try await service.earliestStoredDate())

        let calendar = TimeZoneManager.cetCalendar
        let expectedDate = try cetDate(2025, 3, 1)
        let earliestComponents = calendar.dateComponents([.year, .month, .day], from: earliestDate)
        let expectedComponents = calendar.dateComponents([.year, .month, .day], from: expectedDate)
        #expect(earliestComponents == expectedComponents)
    }

    @Test("Get latest stored date returns correct date")
    func getLatestStoredDateReturnsCorrectDate() async throws {
        let initialDate = try await service.latestStoredDate()
        #expect(initialDate == nil)

        let testDates = ["2025-03-15", "2025-03-01", "2025-03-10", "2025-03-05"]
        try await setupHistoricalData(testDates)

        let latestDate = try await service.latestStoredDate()

        let expectedDate = try #require(TimeZoneManager.parseAPIDate("2025-03-15"))
        #expect(latestDate == expectedDate)
    }

    @Test("Save and load historical rates")
    func saveAndLoadHistoricalRates() async throws {
        let testRates = [
            "2025-03-15": ["EUR": 1.21, "GBP": 0.85],
            "2025-03-16": ["EUR": 1.22, "GBP": 0.86],
        ]

        try await persistence.saveHistoricalExchangeRates(testRates)

        let loadedRates = try await service.loadHistoricalRates(in: try range("2025-03-15", "2025-03-16"))

        #expect(loadedRates.count == 2)
        #expect(loadedRates[0].rates.first(where: { $0.currencyCode == "EUR" })?.rate == 1.21)
        #expect(loadedRates[1].rates.first(where: { $0.currencyCode == "EUR" })?.rate == 1.22)
    }

    @Test("an undecodable blob row is purged so the next save can repair its date")
    func corruptBlobRowIsPurgedAndRepairable() async throws {
        let context = container.mainContext
        context.insert(HistoricalRateData(date: try #require(TimeZoneManager.parseAPIDate("2025-03-15")), ratesData: Data("garbage".utf8)))
        context.insert(try HistoricalRateData(dateString: "2025-03-16", rates: ["EUR": 1.22]))
        try context.save()

        await #expect(throws: (any Error).self) {
            _ = try await persistence.loadHistoricalRates(
                from: try #require(TimeZoneManager.parseAPIDate("2025-03-15")),
                to: try #require(TimeZoneManager.parseAPIDate("2025-03-16"))
            )
        }

        try await persistence.saveHistoricalExchangeRates(["2025-03-15": ["EUR": 1.21]])

        let reloaded = try await persistence.loadHistoricalRates(
            from: try #require(TimeZoneManager.parseAPIDate("2025-03-15")),
            to: try #require(TimeZoneManager.parseAPIDate("2025-03-16"))
        )
        #expect(reloaded.count == 2)
    }

    @Test("Save and load current exchange rates")
    func saveAndLoadCurrentExchangeRates() async throws {
        let testRates = ["EUR": 1.21, "GBP": 0.85, "JPY": 110.0]

        try await persistence.saveExchangeRates(testRates)

        let loadedRates = try await service.loadExchangeRates()

        #expect(loadedRates.count == 3)
        #expect(loadedRates.contains { $0.currencyCode == "EUR" && $0.rate == 1.21 })
        #expect(loadedRates.contains { $0.currencyCode == "GBP" && $0.rate == 0.85 })
        #expect(loadedRates.contains { $0.currencyCode == "JPY" && $0.rate == 110.0 })
    }

    @Test("Clear all data works correctly")
    func clearAllDataWorksCorrectly() async throws {
        let testRates = ["EUR": 1.21, "GBP": 0.85]
        let historicalRates = ["2025-03-15": ["EUR": 1.21, "GBP": 0.85]]

        try await persistence.saveExchangeRates(testRates)
        try await persistence.saveHistoricalExchangeRates(historicalRates)

        let beforeClearCurrent = try await service.loadExchangeRates()
        let beforeClearEarliest = try await service.earliestStoredDate()
        #expect(beforeClearCurrent.isEmpty == false)
        #expect(beforeClearEarliest != nil)

        try await service.clearAllData()

        await #expect(throws: AppError.self) {
            _ = try await service.loadExchangeRates()
        }
        let afterClearEarliest = try await service.earliestStoredDate()
        #expect(afterClearEarliest == nil)
    }

    @Test("Persisted trend data survives a save/load round trip with validation")
    func trendDataSaveLoadRoundTrip() async throws {
        let trends = [
            Trend(currencyCode: "EUR", weeklyChange: 2.5, miniChartData: [1.0, 1.02, 1.025]),
            Trend(currencyCode: "GBP", weeklyChange: -1.0, miniChartData: [0.8, 0.79]),
        ]

        try await service.saveTrendData(trends)
        let loaded = try await service.loadTrendData()

        #expect(Set(loaded.map(\.currencyCode)) == Set(["EUR", "GBP"]))
        #expect(loaded.first { $0.currencyCode == "EUR" }?.miniChartData == [1.0, 1.02, 1.025])
    }
}
