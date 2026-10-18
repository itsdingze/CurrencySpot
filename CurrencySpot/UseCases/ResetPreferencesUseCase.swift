import Foundation

// MARK: - ResetPreferencesUseCase

final class ResetPreferencesUseCase {
    private let preferences: PreferencesStore
    private let favorites: CurrencyCodeListStore
    private let watchlist: CurrencyCodeListStore
    private let language: AppLanguageStore

    init(
        preferences: PreferencesStore,
        favorites: CurrencyCodeListStore,
        watchlist: CurrencyCodeListStore,
        language: AppLanguageStore
    ) {
        self.preferences = preferences
        self.favorites = favorites
        self.watchlist = watchlist
        self.language = language
    }

    func execute() {
        preferences.accentColor = PreferenceDefaults.accentColor
        preferences.appearanceMode = PreferenceDefaults.appearanceMode
        preferences.defaultBaseCurrency = PreferenceDefaults.baseCurrency
        preferences.defaultTargetCurrency = PreferenceDefaults.targetCurrency
        preferences.hasSeenOnboarding = PreferenceDefaults.hasSeenOnboarding
        preferences.hasSeenChartOnboarding = PreferenceDefaults.hasSeenChartOnboarding

        favorites.reset(to: CurrencyDefaults.favoriteCurrencies)
        watchlist.reset(to: CurrencyDefaults.favoriteCurrencies)
        language.resetToSystem()
    }
}
