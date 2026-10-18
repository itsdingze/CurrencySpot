#if DEBUG

    import Foundation
    import Observation

    @Observable
    final class InMemoryPreferencesStore: PreferencesStore {
        var accentColor: AccentColorOption
        var appearanceMode: AppearanceMode
        var defaultBaseCurrency: CurrencyCode
        var defaultTargetCurrency: CurrencyCode
        var hasSeenOnboarding: Bool
        var hasSeenChartOnboarding: Bool

        init(
            accentColor: AccentColorOption = PreferenceDefaults.accentColor,
            appearanceMode: AppearanceMode = PreferenceDefaults.appearanceMode,
            defaultBaseCurrency: CurrencyCode = PreferenceDefaults.baseCurrency,
            defaultTargetCurrency: CurrencyCode = PreferenceDefaults.targetCurrency,
            hasSeenOnboarding: Bool = PreferenceDefaults.hasSeenOnboarding,
            hasSeenChartOnboarding: Bool = PreferenceDefaults.hasSeenChartOnboarding
        ) {
            self.accentColor = accentColor
            self.appearanceMode = appearanceMode
            self.defaultBaseCurrency = defaultBaseCurrency
            self.defaultTargetCurrency = defaultTargetCurrency
            self.hasSeenOnboarding = hasSeenOnboarding
            self.hasSeenChartOnboarding = hasSeenChartOnboarding
        }
    }

#endif
