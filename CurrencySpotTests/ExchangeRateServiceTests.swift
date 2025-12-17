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
    let service: DataCoordinator

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: ExchangeRateData.self, HistoricalRateData.self, TrendData.self,
            configurations: config
        )
        let networkService = FrankfurterNetworkService()
        let persistenceService = SwiftDataPersistenceService(modelContainer: container)
        let cacheService = InMemoryCacheService()
        service = DataCoordinator(
            networkService: networkService,
            persistenceService: persistenceService,
            cacheService: cacheService
        )
    }

    private func createCETDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        TimeZoneManager.createCETDate(year: y, month: m, day: d)!
    }

    private func setupHistoricalData(_ dateStrings: [String]) async throws {
        for dateString in dateStrings {
            let rates = ["EUR": 1.21, "GBP": 0.85, "JPY": 110.0]
            try await service.saveHistoricalExchangeRates([dateString: rates])
        }
    }

    private func clearAllData() async throws {
        try await service.clearAllData()
    }

    @Test("Service initializes correctly")
    func serviceInitializesCorrectly() async throws {
        // Clear UserDefaults to ensure clean state
        UserDefaults.standard.removeObject(forKey: "LastFetchDateKey")

        // Test basic operations don't crash
        let shouldFetch = await service.shouldFetchNewRates()
        #expect(shouldFetch == true) // Should fetch on first run
    }

    @Test("Get latest stored date works")
    func getLatestStoredDateWorks() async throws {
        // Clear data first
        try await clearAllData()

        // Initially should be nil
        let initialDate = try await service.getLatestStoredDate()
        #expect(initialDate == nil)

        // Add some test data
        let testRates = [
            "2025-03-15": ["EUR": 1.21, "GBP": 0.85],
        ]

        try await service.saveHistoricalExchangeRates(testRates)

        // Now should have a date
        let latestDate = try await service.getLatestStoredDate()
        #expect(latestDate != nil)
    }

    @Test("Get earliest stored date returns correct date")
    func getEarliestStoredDateReturnsCorrectDate() async throws {
        // Clear data first
        try await clearAllData()

        // Multiple dates in random order
        let testDates = ["2025-03-15", "2025-03-01", "2025-03-10", "2025-03-05"]
        try await setupHistoricalData(testDates)

        // WHEN: We get the earliest stored date
        let earliestDate = try await service.getEarliestStoredDate()

        // THEN: Should return the earliest date
        // Use CET calendar to match how dates are stored
        let calendar = TimeZoneManager.cetCalendar
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 1
        components.timeZone = TimeZoneManager.cetTimeZone
        let expectedDate = calendar.date(from: components)!

        // Compare only the date components, ignoring time differences
        let earliestComponents = calendar.dateComponents([.year, .month, .day], from: earliestDate!)
        let expectedComponents = calendar.dateComponents([.year, .month, .day], from: expectedDate)
        #expect(earliestComponents == expectedComponents)
    }

    @Test("Get latest stored date returns correct date")
    func getLatestStoredDateReturnsCorrectDate() async throws {
        // Clear data first
        try await clearAllData()

        // Multiple dates in random order
        let testDates = ["2025-03-15", "2025-03-01", "2025-03-10", "2025-03-05"]
        try await setupHistoricalData(testDates)

        // WHEN: We get the latest stored date
        let latestDate = try await service.getLatestStoredDate()

        // THEN: Should return the latest date
        let expectedDate = TimeZoneManager.parseAPIDate("2025-03-15")!
        #expect(latestDate == expectedDate)
    }

    @Test("Save and load historical rates")
    func saveAndLoadHistoricalRates() async throws {
        // Clear data first
        try await clearAllData()

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
        // Clear data first
        try await clearAllData()

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
        #expect(beforeClearCurrent.count > 0)
        #expect(beforeClearEarliest != nil)

        // WHEN: We clear all data
        try await service.clearAllData()

        // THEN: Stored data should be gone, but loadExchangeRates returns mock data as fallback
        let afterClearCurrent = try await service.loadExchangeRates()
        let afterClearEarliest = try await service.getEarliestStoredDate()

        // After clearing, loadExchangeRates should return mock data (graceful degradation)
        #expect(afterClearCurrent.count > 0) // Mock data is returned as fallback
        #expect(afterClearEarliest == nil) // But stored data is actually cleared
    }

    @Test("Date range affects trends detection works correctly")
    func dateRangeAffectsTrendsDetection() async throws {
        // Clear data first
        try await clearAllData()

        let calendar = TimeZoneManager.cetCalendar
        let now = Date()

        // Test cases with different date ranges

        // CASE 1: Old historical data (30 days ago) - should NOT affect trends
        let oldStartDate = calendar.date(byAdding: .day, value: -30, to: now)!
        let oldEndDate = calendar.date(byAdding: .day, value: -15, to: now)!
        let affectsOld = try await service.doesDateRangeAffectTrends(startDate: oldStartDate, endDate: oldEndDate)
        #expect(affectsOld == false, "Old historical data should not affect trends")

        // CASE 2: Recent data (last 3 days) - should affect trends
        let recentStartDate = calendar.date(byAdding: .day, value: -3, to: now)!
        let recentEndDate = now
        let affectsRecent = try await service.doesDateRangeAffectTrends(startDate: recentStartDate, endDate: recentEndDate)
        #expect(affectsRecent == true, "Recent data should affect trends")

        // CASE 3: Data spanning from old to recent - should affect trends
        let spanStartDate = calendar.date(byAdding: .day, value: -15, to: now)!
        let spanEndDate = calendar.date(byAdding: .day, value: -2, to: now)!
        let affectsSpan = try await service.doesDateRangeAffectTrends(startDate: spanStartDate, endDate: spanEndDate)
        #expect(affectsSpan == true, "Data spanning into recent window should affect trends")

        // CASE 4: Future data (edge case) - should affect trends
        let futureStartDate = calendar.date(byAdding: .day, value: 1, to: now)!
        let futureEndDate = calendar.date(byAdding: .day, value: 2, to: now)!
        let affectsFuture = try await service.doesDateRangeAffectTrends(startDate: futureStartDate, endDate: futureEndDate)
        #expect(affectsFuture == false, "Future data should not affect current trends")
    }
}
