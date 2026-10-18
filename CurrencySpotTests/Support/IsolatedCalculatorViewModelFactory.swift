@testable import CurrencySpot
import Foundation

func makeIsolatedCalculatorViewModel(
    repository: (ExchangeRateRepository)? = nil,
    ratesStore: ExchangeRatesStore? = nil,
    appState: AppState? = nil
) -> CalculatorViewModel {
    let repository = repository ?? PreviewExchangeRateRepository()
    return CalculatorViewModel(
        loadExchangeRatesUseCase: LoadExchangeRatesUseCase(
            repository: repository,
            dateProvider: FixedDateProvider(MockExchangeRateRepository.now)
        ),
        ratesStore: ratesStore ?? ExchangeRatesStore(),
        preferences: InMemoryPreferencesStore(),
        appState: appState ?? AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false))
    )
}
