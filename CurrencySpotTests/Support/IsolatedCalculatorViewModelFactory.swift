@testable import CurrencySpot
import Foundation

func makeIsolatedCalculatorViewModel(defaults: UserDefaults, appState: AppState) -> CalculatorViewModel {
    CalculatorViewModel(
        loadExchangeRatesUseCase: LoadExchangeRatesUseCase(
            repository: PreviewExchangeRateRepository(today: MockExchangeRateRepository.now),
            dateProvider: FixedDateProvider(MockExchangeRateRepository.now)
        ),
        calculateConversionUseCase: CalculateConversionUseCase(),
        ratesStore: ExchangeRatesStore(),
        preferences: InMemoryPreferencesStore(),
        favorites: .favorites(in: defaults),
        appState: appState
    )
}
