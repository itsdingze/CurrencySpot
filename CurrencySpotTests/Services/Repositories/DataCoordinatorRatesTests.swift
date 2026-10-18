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
    private let isolatedDefaults = IsolatedDefaults()

    private static let now = Date(timeIntervalSince1970: 1_750_000_000)

    init() throws {
        container = try ModelContainer.inMemoryCurrencySpot()
        networkService = MockNetworkService()
        syncStore = MockHistoricalSyncStore()
        persistence = SwiftDataPersistenceService(modelContainer: container)
        service = DataCoordinator(
            networkService: networkService,
            persistenceService: persistence,
            cacheService: InMemoryCacheService(),
            syncStore: syncStore,
            fetchDateStore: InMemoryRatesFetchDateStore(),
            dateProvider: FixedDateProvider(Self.now)
        )
    }

    private func cetDate(_ y: Int, _ m: Int, _ d: Int) throws -> Date {
        try #require(createCETDate(year: y, month: m, day: d))
    }

    private func range(_ start: String, _ end: String) throws -> DateRange {
        try DateRange.make(
            start: #require(CETCalendar.date(fromDayString: start)),
            end: #require(CETCalendar.date(fromDayString: end))
        )
    }

    private func setupHistoricalData(_ dateStrings: [String]) async throws {
        for dateString in dateStrings {
            let rates = ["EUR": 1.21, "GBP": 0.85, "JPY": 110.0]
            try await persistence.saveHistoricalExchangeRates([dateString: rates])
        }
    }

    @Test("clearAllData resets the historical sync coverage window")
    func clearAllDataResetsSyncCoverage() async throws {
        syncStore.record(from: try cetDate(2025, 1, 1), through: try cetDate(2025, 1, 10), at: Self.now)

        try await service.clearAllData()

        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
        #expect(syncStore.checkedAt == nil)
    }

    @Test("a stored read returns persisted days beyond a narrower series and widens the series with them")
    func storedReadServesPersistenceNotTheNarrowerSeries() async throws {
        let cacheService = InMemoryCacheService()
        let coordinator = DataCoordinator(
            networkService: MockNetworkService(),
            persistenceService: persistence,
            cacheService: cacheService,
            syncStore: MockHistoricalSyncStore(),
            fetchDateStore: InMemoryRatesFetchDateStore(),
            dateProvider: FixedDateProvider(Self.now)
        )

        let wideDates = (3 ... 12).map { String(format: "2025-03-%02d", $0) }
        for dateString in wideDates {
            try await persistence.saveHistoricalExchangeRates([dateString: ["EUR": 1.21]])
        }

        let narrow = try [
            HistoricalRateSnapshot(dateString: "2025-03-11", rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.21)]),
            HistoricalRateSnapshot(dateString: "2025-03-12", rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.21)]),
        ]
        await cacheService.cacheHistoricalData(narrow)

        let result = try await coordinator.loadAndMergeStoredHistoricalRates(in: try range("2025-03-01", "2025-03-31"))

        #expect(result.count == wideDates.count)
        #expect(await coordinator.cachedHistoricalRates().count == wideDates.count)
    }

    @Test("processed chart data round-trips by key and misses for any other key")
    func chartDataRoundTripsByKey() async throws {
        let points = [ChartDataPoint(date: try cetDate(2025, 3, 12), rate: 0.92)]
        let window = try range("2025-03-01", "2025-03-12")
        let key = ChartCacheKey(base: "USD", target: "EUR", range: window, snapshotCount: 1, firstSnapshot: nil, lastSnapshot: nil)
        let otherKey = ChartCacheKey(base: "USD", target: "GBP", range: window, snapshotCount: 1, firstSnapshot: nil, lastSnapshot: nil)

        await service.storeChartData(points, for: key)

        #expect(await service.cachedChartData(for: key) == points)
        #expect(await service.cachedChartData(for: otherKey) == nil)
    }

    @Test("the fetch date store starts empty and round-trips a date through its injected defaults")
    func lastFetchDateRoundTrip() async throws {
        let defaults = try isolatedDefaults.make()
        let store = UserDefaultsRatesFetchDateStore(defaults: defaults)
        #expect(store.lastFetchDate == nil)

        let fetchDate = try cetDate(2025, 3, 12)
        store.lastFetchDate = fetchDate

        #expect(UserDefaultsRatesFetchDateStore(defaults: defaults).lastFetchDate == fetchDate)
    }

    @Test("clearAllData forgets the rates fetch date")
    func clearAllDataForgetsFetchDate() async throws {
        networkService.exchangeRatesResult = .success(
            ExchangeRatesResponse(base: "USD", date: "2025-03-12", rates: ["EUR": 0.9])
        )
        _ = try await service.fetchExchangeRates()
        try #require(service.lastFetchDate() != nil)

        try await service.clearAllData()

        #expect(service.lastFetchDate() == nil)
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
        #expect(service.lastFetchDate() != nil)
    }

    @Test("fetchExchangeRates throws on network failure instead of silently substituting saved rates")
    func fetchThrowsOnNetworkFailureWithoutSilentFallback() async throws {
        try await persistence.saveExchangeRates([ExchangeRate(currencyCode: "EUR", rate: 0.9)])
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

        let calendar = CETCalendar.calendar
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

        let expectedDate = try #require(CETCalendar.date(fromDayString: "2025-03-15"))
        #expect(latestDate == expectedDate)
    }

    @Test("Save and load historical rates")
    func saveAndLoadHistoricalRates() async throws {
        let testRates = [
            "2025-03-15": ["EUR": 1.21, "GBP": 0.85],
            "2025-03-16": ["EUR": 1.22, "GBP": 0.86],
        ]

        try await persistence.saveHistoricalExchangeRates(testRates)

        let loadedRates = try await service.loadStoredHistoricalRates(in: try range("2025-03-15", "2025-03-16"))

        #expect(loadedRates.count == 2)
        #expect(loadedRates[0].rates.first(where: { $0.currencyCode == "EUR" })?.rate == 1.21)
        #expect(loadedRates[1].rates.first(where: { $0.currencyCode == "EUR" })?.rate == 1.22)
    }

    @Test("an undecodable blob row is purged so the next save can repair its date")
    func corruptBlobRowIsPurgedAndRepairable() async throws {
        let context = container.mainContext
        context.insert(HistoricalRateData(date: try #require(CETCalendar.date(fromDayString: "2025-03-15")), ratesData: Data("garbage".utf8)))
        context.insert(try HistoricalRateData(date: #require(CETCalendar.date(fromDayString: "2025-03-16")), rates: ["EUR": 1.22]))
        try context.save()

        await #expect(throws: (any Error).self) {
            _ = try await persistence.loadHistoricalRates(
                from: try #require(CETCalendar.date(fromDayString: "2025-03-15")),
                to: try #require(CETCalendar.date(fromDayString: "2025-03-16"))
            )
        }

        try await persistence.saveHistoricalExchangeRates(["2025-03-15": ["EUR": 1.21]])

        let reloaded = try await persistence.loadHistoricalRates(
            from: try #require(CETCalendar.date(fromDayString: "2025-03-15")),
            to: try #require(CETCalendar.date(fromDayString: "2025-03-16"))
        )
        #expect(reloaded.count == 2)
    }

    @Test("purging an undecodable row reopens the covered window so the next backfill refills it")
    func corruptRowPurgeResetsCoverage() async throws {
        let corruptDay = try #require(CETCalendar.date(fromDayString: "2025-03-15"))
        let context = container.mainContext
        context.insert(HistoricalRateData(date: corruptDay, ratesData: Data("garbage".utf8)))
        try context.save()
        syncStore.record(from: try cetDate(2025, 3, 1), through: try cetDate(2025, 3, 31), at: Date(timeIntervalSince1970: 0))

        _ = try? await service.loadStoredHistoricalRates(in: try range("2025-03-01", "2025-03-31"))

        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
    }

    @Test("pruning removes only the days before the cutoff")
    func pruneRemovesOnlyOlderDays() async throws {
        try await setupHistoricalData(["2025-03-10", "2025-03-11", "2025-03-12"])

        try await service.pruneHistoricalRates(before: try cetDate(2025, 3, 11))

        let remaining = try await persistence.loadHistoricalRates(from: try cetDate(2025, 3, 1), to: try cetDate(2025, 3, 31))
        #expect(remaining.map(\.date) == [try cetDate(2025, 3, 11), try cetDate(2025, 3, 12)])
    }

    @Test("re-saving a stored day keeps the stored row and still adds the new days")
    func resaveKeepsStoredDayAndAddsNewOnes() async throws {
        try await persistence.saveHistoricalExchangeRates(["2025-03-15": ["EUR": 1.21]])
        try await persistence.saveHistoricalExchangeRates([
            "2025-03-15": ["EUR": 9.99],
            "2025-03-16": ["EUR": 1.22],
        ])

        let stored = try await persistence.loadHistoricalRates(
            from: try #require(CETCalendar.date(fromDayString: "2025-03-15")),
            to: try #require(CETCalendar.date(fromDayString: "2025-03-16"))
        )

        #expect(stored.count == 2)
        #expect(stored.first?.rates == [HistoricalRatePoint(currencyCode: "EUR", rate: 1.21)])
    }

    @Test("Save and load current exchange rates")
    func saveAndLoadCurrentExchangeRates() async throws {
        let testRates = [
            ExchangeRate(currencyCode: "EUR", rate: 1.21),
            ExchangeRate(currencyCode: "GBP", rate: 0.85),
            ExchangeRate(currencyCode: "JPY", rate: 110.0),
        ]

        try await persistence.saveExchangeRates(testRates)

        let loadedRates = try await service.loadExchangeRates()

        #expect(loadedRates.count == 3)
        #expect(loadedRates.contains { $0.currencyCode == "EUR" && $0.rate == 1.21 })
        #expect(loadedRates.contains { $0.currencyCode == "GBP" && $0.rate == 0.85 })
        #expect(loadedRates.contains { $0.currencyCode == "JPY" && $0.rate == 110.0 })
    }

    @Test("Clear all data works correctly")
    func clearAllDataWorksCorrectly() async throws {
        let testRates = [ExchangeRate(currencyCode: "EUR", rate: 1.21), ExchangeRate(currencyCode: "GBP", rate: 0.85)]
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
