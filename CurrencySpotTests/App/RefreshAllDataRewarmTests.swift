@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Refresh-all-data rewarm wiring")
struct RefreshAllDataRewarmTests {
    private let isolatedDefaults = IsolatedDefaults()

    @Test("refreshing all data refetches the rates and re-runs the history warm-up", .timeLimit(.minutes(1)))
    func refreshRewarms() async throws {
        let network = MockNetworkService()
        network.exchangeRatesResult = .success(ExchangeRatesResponse(base: "USD", date: "2026-06-12", rates: ["EUR": 0.9]))
        network.historicalRatesResult = .success(HistoricalRatesResponse(base: "USD", startDate: "", endDate: "", rates: [:]))

        let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))
        let container = DependencyContainer(
            modelContainer: try ModelContainer.inMemoryCurrencySpot(),
            appState: appState,
            userDefaults: try isolatedDefaults.make(),
            preferences: InMemoryPreferencesStore(),
            networkService: network,
            syncStore: MockHistoricalSyncStore(),
            fetchDateStore: InMemoryRatesFetchDateStore(),
            dateProvider: FixedDateProvider(try #require(createCETDate(year: 2026, month: 6, day: 12))),
            clockService: ImmediateClock(),
            cameraPermissionService: StubCameraPermissionService(status: .authorized),
            stillTextRecognizer: StubStillTextRecognizer(),
            torchService: InMemoryTorchService()
        )
        #expect(network.fetchHistoricalRatesCalls.isEmpty)

        container.settingsViewModel.confirmAlert(.refreshAllData)

        await waitUntil { appState.dataResetCount == 1 }
        await waitUntil {
            network.fetchExchangeRatesCallCount > 0 && network.fetchHistoricalRatesCalls.isEmpty == false
        }
        #expect(appState.errorHandler.currentError == nil)
    }
}
