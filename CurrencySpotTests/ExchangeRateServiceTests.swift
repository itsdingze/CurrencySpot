//
//  ExchangeRateServiceTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 7/17/25.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Exchange Rate Service Tests")
@MainActor
struct ExchangeRateServiceTests {
    let container: ModelContainer
    let networkService: MockNetworkService
    let syncStore: MockHistoricalSyncStore
    let service: DataCoordinator

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: ExchangeRateData.self, HistoricalRateData.self, TrendData.self,
            configurations: config
        )
        networkService = MockNetworkService()
        syncStore = MockHistoricalSyncStore()
        service = DataCoordinator(
            networkService: networkService,
            persistenceService: SwiftDataPersistenceService(modelContainer: container),
            cacheService: InMemoryCacheService(),
            syncStore: syncStore
        )
    }

    private func cetDate(_ y: Int, _ m: Int, _ d: Int) throws -> Date {
        try #require(createCETDate(year: y, month: m, day: d))
    }

    private func setupHistoricalData(_ dateStrings: [String]) async throws {
        for dateString in dateStrings {
            let rates = ["EUR": 1.21, "GBP": 0.85, "JPY": 110.0]
            try await service.saveHistoricalExchangeRates([dateString: rates])
        }
    }

    /// Builds an isolated UserDefaults suite for FrankfurterNetworkService tests.
    private static func makeDefaults() throws -> (defaults: UserDefaults, name: String) {
        let name = "ExchangeRateServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    @Test("clearAllData resets the historical sync coverage window")
    func clearAllDataResetsSyncCoverage() async throws {
        syncStore.record(from: try cetDate(2025, 1, 1), through: try cetDate(2025, 1, 10), at: Date())

        try await service.clearAllData()

        // Otherwise "Clear Cached Data" would leave a coverage claim over an empty store → blank charts.
        #expect(syncStore.from == nil)
        #expect(syncStore.through == nil)
        #expect(syncStore.checkedAt == nil)
    }

    @Test("loadHistoricalRatesForCurrency reads persistence, not a narrower stale in-memory cache")
    func loadHistoricalReadsPersistenceNotStaleCache() async throws {
        // Regression: a successful wide fetch was being shadowed by a narrower cached window,
        // so a 3-month load read back only the ~1-week trend-seed data until the app restarted.
        let cacheService = InMemoryCacheService()
        let coordinator = DataCoordinator(
            networkService: MockNetworkService(),
            persistenceService: SwiftDataPersistenceService(modelContainer: container),
            cacheService: cacheService,
            syncStore: MockHistoricalSyncStore()
        )

        // Persist a wide window: 10 distinct days.
        let wideDates = (3 ... 12).map { String(format: "2025-03-%02d", $0) }
        for dateString in wideDates {
            try await coordinator.saveHistoricalExchangeRates([dateString: ["EUR": 1.21]])
        }

        // Seed the in-memory cache with only a NARROW 2-day window (this used to shadow the read).
        let narrow = try [
            HistoricalRateDataValue(dateString: "2025-03-11", rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21)]),
            HistoricalRateDataValue(dateString: "2025-03-12", rates: [HistoricalRateDataPointValue(currencyCode: "EUR", rate: 1.21)]),
        ]
        await cacheService.cacheHistoricalData(narrow, for: "EUR")

        // Reading the full window must return the 10 persisted rows, not the 2 cached ones.
        let result = try await coordinator.loadHistoricalRatesForCurrency(
            currency: "EUR", startDate: "2025-03-01", endDate: "2025-03-31"
        )
        #expect(result.count == wideDates.count)
    }

    @Test("FrankfurterNetworkService should fetch on first run (no stored fetch date)")
    func shouldFetchOnFirstRun() async throws {
        let (defaults, name) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let networkService = FrankfurterNetworkService(userDefaults: defaults)

        #expect(networkService.getLastFetchDate() == nil)
        let shouldFetch = await networkService.shouldFetchNewRates()
        #expect(shouldFetch == true)
    }

    @Test("FrankfurterNetworkService round-trips the last fetch date through its injected defaults")
    func lastFetchDateRoundTrip() async throws {
        let (defaults, name) = try Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let networkService = FrankfurterNetworkService(userDefaults: defaults)

        let fetchDate = try cetDate(2025, 3, 12)
        networkService.updateLastFetchDate(fetchDate)

        #expect(networkService.getLastFetchDate() == fetchDate)
        #expect(defaults.object(forKey: UserDefaultsKeys.lastFetchDate) as? Date == fetchDate)
    }

    @Test("Get earliest stored date returns correct date")
    func getEarliestStoredDateReturnsCorrectDate() async throws {
        // Multiple dates in random order
        let testDates = ["2025-03-15", "2025-03-01", "2025-03-10", "2025-03-05"]
        try await setupHistoricalData(testDates)

        // WHEN: We get the earliest stored date
        let earliestDate = try #require(try await service.getEarliestStoredDate())

        // THEN: Should return the earliest date.
        // Compare only the date components in CET, matching how dates are stored.
        let calendar = TimeZoneManager.cetCalendar
        let expectedDate = try cetDate(2025, 3, 1)
        let earliestComponents = calendar.dateComponents([.year, .month, .day], from: earliestDate)
        let expectedComponents = calendar.dateComponents([.year, .month, .day], from: expectedDate)
        #expect(earliestComponents == expectedComponents)
    }

    @Test("Get latest stored date returns correct date")
    func getLatestStoredDateReturnsCorrectDate() async throws {
        // Initially should be nil
        let initialDate = try await service.getLatestStoredDate()
        #expect(initialDate == nil)

        // Multiple dates in random order
        let testDates = ["2025-03-15", "2025-03-01", "2025-03-10", "2025-03-05"]
        try await setupHistoricalData(testDates)

        // WHEN: We get the latest stored date
        let latestDate = try await service.getLatestStoredDate()

        // THEN: Should return the latest date
        let expectedDate = try #require(TimeZoneManager.parseAPIDate("2025-03-15"))
        #expect(latestDate == expectedDate)
    }

    @Test("Save and load historical rates")
    func saveAndLoadHistoricalRates() async throws {
        // GIVEN: Historical rates data
        let testRates = [
            "2025-03-15": ["EUR": 1.21, "GBP": 0.85],
            "2025-03-16": ["EUR": 1.22, "GBP": 0.86],
        ]

        // WHEN: We save the rates
        try await service.saveHistoricalExchangeRates(testRates)

        // THEN: We should be able to load them back
        let loadedRates = try await service.loadHistoricalRatesForCurrency(
            currency: "EUR",
            startDate: "2025-03-15",
            endDate: "2025-03-16"
        )

        #expect(loadedRates.count == 2)
        #expect(loadedRates[0].rates.first(where: { $0.currencyCode == "EUR" })?.rate == 1.21)
        #expect(loadedRates[1].rates.first(where: { $0.currencyCode == "EUR" })?.rate == 1.22)
    }

    @Test("Save and load current exchange rates")
    func saveAndLoadCurrentExchangeRates() async throws {
        // GIVEN: Current rates data
        let testRates = ["EUR": 1.21, "GBP": 0.85, "JPY": 110.0]

        // WHEN: We save the rates
        try await service.saveExchangeRates(testRates)

        // THEN: We should be able to load them back
        let loadedRates = try await service.loadExchangeRates()

        #expect(loadedRates.count == 3)
        #expect(loadedRates.contains { $0.currencyCode == "EUR" && $0.rate == 1.21 })
        #expect(loadedRates.contains { $0.currencyCode == "GBP" && $0.rate == 0.85 })
        #expect(loadedRates.contains { $0.currencyCode == "JPY" && $0.rate == 110.0 })
    }

    @Test("Clear all data works correctly")
    func clearAllDataWorksCorrectly() async throws {
        // GIVEN: Some data in the database
        let testRates = ["EUR": 1.21, "GBP": 0.85]
        let historicalRates = ["2025-03-15": ["EUR": 1.21, "GBP": 0.85]]

        try await service.saveExchangeRates(testRates)
        try await service.saveHistoricalExchangeRates(historicalRates)

        // Verify data exists
        let beforeClearCurrent = try await service.loadExchangeRates()
        let beforeClearEarliest = try await service.getEarliestStoredDate()
        #expect(beforeClearCurrent.isEmpty == false)
        #expect(beforeClearEarliest != nil)

        // WHEN: We clear all data
        try await service.clearAllData()

        // THEN: Stored data is gone, and with no local data and a failing (stubbed) network,
        // loadExchangeRates throws instead of silently substituting mock data.
        await #expect(throws: Error.self) {
            _ = try await service.loadExchangeRates()
        }
        let afterClearEarliest = try await service.getEarliestStoredDate()
        #expect(afterClearEarliest == nil)
    }

    @Test("Date range affects trends detection works correctly")
    func dateRangeAffectsTrendsDetection() async throws {
        // The trend window is defined as "the last 7 days from the real clock" inside the
        // persistence layer, so these fixtures are necessarily relative to Date(). The
        // offsets are chosen far from the 7-day boundary, so the outcome is stable
        // regardless of when within a day the test runs.
        let calendar = TimeZoneManager.cetCalendar
        let now = Date()

        func daysFromNow(_ offset: Int) throws -> Date {
            try #require(calendar.date(byAdding: .day, value: offset, to: now))
        }

        // CASE 1: Old historical data (30 days ago) - should NOT affect trends
        let affectsOld = try await service.doesDateRangeAffectTrends(
            startDate: try daysFromNow(-30), endDate: try daysFromNow(-15)
        )
        #expect(affectsOld == false, "Old historical data should not affect trends")

        // CASE 2: Recent data (last 3 days) - should affect trends
        let affectsRecent = try await service.doesDateRangeAffectTrends(
            startDate: try daysFromNow(-3), endDate: now
        )
        #expect(affectsRecent == true, "Recent data should affect trends")

        // CASE 3: Data spanning from old to recent - should affect trends
        let affectsSpan = try await service.doesDateRangeAffectTrends(
            startDate: try daysFromNow(-15), endDate: try daysFromNow(-2)
        )
        #expect(affectsSpan == true, "Data spanning into recent window should affect trends")

        // CASE 4: Future data (edge case) - should not affect current trends
        let affectsFuture = try await service.doesDateRangeAffectTrends(
            startDate: try daysFromNow(1), endDate: try daysFromNow(2)
        )
        #expect(affectsFuture == false, "Future data should not affect current trends")
    }
}
