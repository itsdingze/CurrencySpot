@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Launch rates fetch")
struct LaunchRatesFetchTests {
    private let isolatedDefaults = IsolatedDefaults()

    @Test("a first launch with nothing saved fetches the rates once", .timeLimit(.minutes(1)))
    func firstLaunchWithNothingSavedFetchesOnce() async throws {
        let network = MockNetworkService()
        network.exchangeRatesResult = .success(ExchangeRatesResponse(base: "USD", date: "2026-06-12", rates: ["EUR": 0.9]))
        let container = DependencyContainer(
            modelContainer: try ModelContainer.inMemoryCurrencySpot(),
            appState: AppState(networkMonitor: NetworkMonitor(isConnected: true)),
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
        let calculator = container.calculatorViewModel

        await calculator.checkIfShouldFetch()
        await waitUntil { calculator.loadState == .loaded(calculator.availableRates) && !calculator.availableRates.isEmpty }

        #expect(network.fetchExchangeRatesCallCount == 1)
    }
}
