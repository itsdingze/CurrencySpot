@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Refresh-all-data rewarm wiring")
struct RefreshAllDataRewarmTests {
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

        try await container.refreshAllDataUseCase.execute()

        await waitUntil {
            network.fetchExchangeRatesCallCount > 0 && network.fetchHistoricalRatesCalls.isEmpty == false
        }

        await waitUntil {
            if case .loaded = container.historyViewModel.chartData { return true }
            return false
        }
    }
}
