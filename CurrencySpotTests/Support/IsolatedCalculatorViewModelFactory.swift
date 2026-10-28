@testable import CurrencySpot
import Foundation

func makeIsolatedCalculatorViewModel(
    defaults: UserDefaults,
    appState: AppState,
    history: ConversionHistoryStore? = nil,
    dateProvider: DateProvider = FixedDateProvider(MockExchangeRateRepository.now)
) -> CalculatorViewModel {
    CalculatorViewModel(
        loadExchangeRatesUseCase: LoadExchangeRatesUseCase(
            repository: PreviewExchangeRateRepository(today: MockExchangeRateRepository.now),
            dateProvider: FixedDateProvider(MockExchangeRateRepository.now)
        ),
        calculateConversionUseCase: CalculateConversionUseCase(),
        ratesStore: ExchangeRatesStore(),
        preferences: InMemoryPreferencesStore(),
        favorites: .favorites(in: defaults),
        history: history ?? ConversionHistoryStore(defaults: defaults),
        dateProvider: dateProvider,
        appState: appState
    )
}
