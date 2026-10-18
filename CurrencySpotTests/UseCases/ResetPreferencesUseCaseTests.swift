@testable import CurrencySpot
import Foundation
import IdentifiedCollections
import Testing

@Suite("ResetPreferencesUseCase Tests")
struct ResetPreferencesUseCaseTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let defaults: UserDefaults
    private let preferences = InMemoryPreferencesStore(
        accentColor: .pink,
        appearanceMode: .dark,
        defaultBaseCurrency: "GBP",
        defaultTargetCurrency: "JPY",
        hasSeenOnboarding: true,
        hasSeenChartOnboarding: true
    )
    private let favorites: CurrencyCodeListStore
    private let watchlist: CurrencyCodeListStore
    private let language = InMemoryAppLanguageStore(systemIdentifier: "en")
    private let useCase: ResetPreferencesUseCase

    init() throws {
        defaults = try isolatedDefaults.make()
        favorites = CurrencyCodeListStore(defaults: defaults, key: UserDefaultsKeys.favoriteCurrencies, seed: ["CHF"])
        watchlist = CurrencyCodeListStore(defaults: defaults, key: UserDefaultsKeys.historyWatchlist, seed: ["NZD", "SEK"])
        language.selectedLanguage = AppLanguage(identifier: "zh-Hans")
        useCase = ResetPreferencesUseCase(preferences: preferences, favorites: favorites, watchlist: watchlist, language: language)
    }

    @Test("every preference returns to its out-of-box value")
    func restoresEveryPreference() {
        useCase.execute()

        #expect(preferences.accentColor == .cyan)
        #expect(preferences.appearanceMode == .system)
        #expect(preferences.defaultBaseCurrency == "USD")
        #expect(preferences.defaultTargetCurrency == "EUR")
        #expect(preferences.hasSeenOnboarding == false)
        #expect(preferences.hasSeenChartOnboarding == false)
    }

    @Test("favorites return to the defaults and persist under the favorites key")
    func resetsFavorites() {
        useCase.execute()

        #expect(favorites.codes.elements == CurrencyDefaults.favoriteCurrencies)
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies) == CurrencyDefaults.favoriteCurrencies.map(\.rawValue))
    }

    @Test("the watchlist is re-seeded from the default favorites, not the customized ones")
    func reseedsWatchlistFromDefaultFavorites() {
        useCase.execute()

        #expect(watchlist.codes.elements == CurrencyDefaults.favoriteCurrencies)
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) == CurrencyDefaults.favoriteCurrencies.map(\.rawValue))
    }

    @Test("a chosen app language goes back to the system language")
    func languageReturnsToSystem() {
        useCase.execute()

        #expect(language.selectedLanguage == AppLanguage(identifier: "en"))
    }
}
