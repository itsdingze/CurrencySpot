#if DEBUG

    import Foundation
    import IdentifiedCollections
    import Observation

    @Observable
    final class InMemoryPreferencesStore: PreferencesStore {
        var accentColor: AccentColorOption
        var appearanceMode: AppearanceMode
        var defaultBaseCurrency: CurrencyCode
        var defaultTargetCurrency: CurrencyCode
        private(set) var favoriteCurrencies: CurrencyCodeList
        var hasSeenOnboarding: Bool
        var hasSeenChartOnboarding: Bool

        init(
            accentColor: AccentColorOption = PreferenceDefaults.accentColor,
            appearanceMode: AppearanceMode = PreferenceDefaults.appearanceMode,
            defaultBaseCurrency: CurrencyCode = PreferenceDefaults.baseCurrency,
            defaultTargetCurrency: CurrencyCode = PreferenceDefaults.targetCurrency,
            favoriteCurrencies: [CurrencyCode] = PreferenceDefaults.favoriteCurrencies,
            hasSeenOnboarding: Bool = PreferenceDefaults.hasSeenOnboarding,
            hasSeenChartOnboarding: Bool = PreferenceDefaults.hasSeenChartOnboarding
        ) {
            self.accentColor = accentColor
            self.appearanceMode = appearanceMode
            self.defaultBaseCurrency = defaultBaseCurrency
            self.defaultTargetCurrency = defaultTargetCurrency
            self.favoriteCurrencies = .deduplicating(favoriteCurrencies)
            self.hasSeenOnboarding = hasSeenOnboarding
            self.hasSeenChartOnboarding = hasSeenChartOnboarding
        }

        @discardableResult
        func addFavorite(_ code: CurrencyCode) -> Bool {
            let (inserted, _) = favoriteCurrencies.append(code)
            return inserted
        }

        @discardableResult
        func removeFavorite(_ code: CurrencyCode) -> Bool {
            favoriteCurrencies.remove(id: code) != nil
        }

        func moveFavorites(from: IndexSet, to: Int) {
            favoriteCurrencies.move(fromOffsets: from, toOffset: to)
        }

        func resetToDefaults() {
            accentColor = PreferenceDefaults.accentColor
            appearanceMode = PreferenceDefaults.appearanceMode
            defaultBaseCurrency = PreferenceDefaults.baseCurrency
            defaultTargetCurrency = PreferenceDefaults.targetCurrency
            favoriteCurrencies = .deduplicating(PreferenceDefaults.favoriteCurrencies)
            hasSeenOnboarding = PreferenceDefaults.hasSeenOnboarding
            hasSeenChartOnboarding = PreferenceDefaults.hasSeenChartOnboarding
        }
    }

#endif
