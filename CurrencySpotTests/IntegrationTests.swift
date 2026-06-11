//
//  IntegrationTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 7/9/25.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

/// Deterministic end-to-end tests over the real DataCoordinator + SwiftData persistence +
/// orchestration/chart-preparation use cases, with a mock network and isolated UserDefaults.
/// Covers only what the per-layer suites don't: the layers working together.
@Suite("Integration Tests")
@MainActor
struct IntegrationTests {
    private let container: ModelContainer
    private let service: DataCoordinator
    private let cacheService = InMemoryCacheService()

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: ExchangeRateData.self, HistoricalRateData.self, TrendData.self,
            configurations: config
        )
        service = DataCoordinator(
            networkService: MockNetworkService(), // default-fails: any network reach fails loudly
            persistenceService: SwiftDataPersistenceService(modelContainer: container),
            cacheService: cacheService,
            syncStore: MockHistoricalSyncStore()
        )
    }

    @Test("full save → load → analyze workflow produces chart data without any network fetch")
    func saveLoadAnalyzeWorkflow() async throws {
        // GIVEN: persisted EUR rates for 2025-03-03 ... 2025-03-14 with a known drift
        let allDates = (3 ... 14).map { String(format: "2025-03-%02d", $0) }
        for (index, dateString) in allDates.enumerated() {
            try await service.saveHistoricalExchangeRates([dateString: ["EUR": 1.0 + Double(index) * 0.01]])
        }

        // AND: the orchestration + chart preparation pipeline wired over the same coordinator
        let analysisUseCase = HistoricalDataAnalysisUseCase(syncStore: MockHistoricalSyncStore())
        let orchestrationUseCase = DataOrchestrationUseCase(
            service: service,
            historicalDataAnalysisUseCase: analysisUseCase,
            cacheService: cacheService
        )
        let chartUseCase = ChartDataPreparationUseCase(
            rateCalculationUseCase: RateCalculationUseCase(),
            cacheService: cacheService
        )

        // WHEN: loading a sub-range covered by persistence (2025-03-05 ... 2025-03-12)
        let rangeStart = try #require(createCETDate(year: 2025, month: 3, day: 5))
        let rangeEnd = try #require(createCETDate(year: 2025, month: 3, day: 12))
        let dateRange = DateRange(start: rangeStart, end: rangeEnd)
        let loaded = try await orchestrationUseCase.loadHistoricalData(for: "EUR", dateRange: dateRange)

        // THEN: persistence satisfies the load; nothing was fetched from the (failing) network
        #expect(loaded.newDataFetched == false)
        #expect(loaded.fetchedRanges.isEmpty)
        #expect(loaded.dataPoints.count == 8) // 2025-03-05 ... 2025-03-12 inclusive

        // AND: the loaded points flow through chart preparation into statistics
        let chartPoints = await chartUseCase.processHistoricalRateData(
            historicalData: loaded.dataPoints,
            baseCurrency: "USD",
            targetCurrency: "EUR",
            dateRange: dateRange,
            exchangeRates: []
        )
        #expect(chartPoints.count == 8)

        let statistics = await chartUseCase.calculateStatistics(from: chartPoints)
        // Saved drift: index 2 (03-05) → 1.02, index 9 (03-12) → 1.09.
        #expect(abs(statistics.lowestRate - 1.02) < 0.0001)
        #expect(abs(statistics.currentRate - 1.09) < 0.0001)
        #expect(statistics.trendDirection == .up)
    }

    @Test("earliest and latest stored dates round-trip through save and clear")
    func earliestLatestStoredDateRoundTrip() async throws {
        // Initially empty
        let initialEarliest = try await service.getEarliestStoredDate()
        #expect(initialEarliest == nil)

        // Save out-of-order dates
        for dateString in ["2025-03-15", "2025-03-01", "2025-03-08"] {
            try await service.saveHistoricalExchangeRates([dateString: ["EUR": 1.21]])
        }

        let earliest = try #require(try await service.getEarliestStoredDate())
        let latest = try #require(try await service.getLatestStoredDate())
        #expect(earliest == TimeZoneManager.parseAPIDate("2025-03-01"))
        #expect(latest == TimeZoneManager.parseAPIDate("2025-03-15"))

        // Clearing returns the store to its empty state
        try await service.clearAllData()
        let clearedEarliest = try await service.getEarliestStoredDate()
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
            service: MockExchangeRateService(),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            userDefaults: defaults
        )

        #expect(viewModel.baseCurrency == "GBP")
        #expect(viewModel.targetCurrency == "JPY")
    }
}
