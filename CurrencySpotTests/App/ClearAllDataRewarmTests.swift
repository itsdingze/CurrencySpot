//
//  ClearAllDataRewarmTests.swift
//  CurrencySpotTests
//
//  "Refresh All Data" is recovery, not data-lessness: after the wipe, the container's
//  wiring must immediately rebuild — rates for the currency list, then the tiered
//  history warm-up — instead of leaving the app dead until the next launch.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Clear-all-data rewarm wiring")
struct ClearAllDataRewarmTests {
    @Test("refreshing all data kicks the rate refetch and the history warm-up", .timeLimit(.minutes(1)))
    func clearKicksRewarm() async throws {
        let network = MockNetworkService()
        network.exchangeRatesResult = .success(ExchangeRatesResponse(base: "USD", date: "2026-06-12", rates: ["EUR": 0.9]))
        network.historicalRatesResult = .success(HistoricalRatesResponse(base: "USD", startDate: "", endDate: "", rates: [:]))

        let container = DependencyContainer(
            modelContainer: try ModelContainer.inMemoryCurrencySpot(),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            networkService: network,
            syncStore: MockHistoricalSyncStore()
        )

        try await container.clearAllDataUseCase.execute()

        // Both rebuild paths reach the network without waiting for a relaunch.
        while network.fetchExchangeRatesCallCount == 0 || network.fetchHistoricalRatesCalls.isEmpty {
            await Task.yield()
        }

        // The visible chart recovers too: the reset's .idle must not strand an open
        // chart on an infinite spinner after the rewarm completes.
        while true {
            if case .loaded = container.historyViewModel.chartData { break }
            await Task.yield()
        }
    }
}
