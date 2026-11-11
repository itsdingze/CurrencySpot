import Foundation
import Observation

final class SharedSettingsMirror {
    private let favorites: CurrencyCodeListStore
    private let preferences: PreferencesStore
    private let ratesStore: ExchangeRatesStore
    private let language: AppLanguageStore
    private let shared: UserDefaults
    private let favoritesChanged: () -> Void
    private let ratesRefreshed: () -> Void
    private let languageChanged: () -> Void

    private var sharedFavorites: [String]?

    init(
        favorites: CurrencyCodeListStore,
        preferences: PreferencesStore,
        ratesStore: ExchangeRatesStore,
        language: AppLanguageStore,
        shared: UserDefaults,
        favoritesChanged: @escaping () -> Void,
        ratesRefreshed: @escaping () -> Void,
        languageChanged: @escaping () -> Void
    ) {
        self.favorites = favorites
        self.preferences = preferences
        self.ratesStore = ratesStore
        self.language = language
        self.shared = shared
        self.favoritesChanged = favoritesChanged
        self.ratesRefreshed = ratesRefreshed
        self.languageChanged = languageChanged
    }

    func start() {
        withObservationTracking {
            share()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.start() }
        }
    }

    private func share() {
        shareFavorites(favorites.codes.map(\.rawValue))
        shared.set(preferences.defaultBaseCurrency.rawValue, forKey: UserDefaultsKeys.defaultBaseCurrency)
        shared.set(preferences.defaultTargetCurrency.rawValue, forKey: UserDefaultsKeys.defaultTargetCurrency)
        if !ratesStore.isShowingSampleRates, !ratesStore.rates.isEmpty {
            shared.set(ratesStore.rates.map(\.currencyCode.rawValue).sorted(), forKey: UserDefaultsKeys.rateCurrencies)
            shareRatesUpdate(ratesStore.lastUpdated)
        }
        shareLanguage(language.followsSystemLanguage ? nil : language.selectedLanguage.identifier)
    }

    private func shareFavorites(_ codes: [String]) {
        guard codes != sharedFavorites else { return }
        sharedFavorites = codes
        shared.set(codes, forKey: UserDefaultsKeys.favoriteCurrencies)
        favoritesChanged()
    }

    private func shareRatesUpdate(_ lastUpdated: Date?) {
        guard let lastUpdated else { return }
        if let sharedUpdate = shared.object(forKey: UserDefaultsKeys.sharedRatesUpdatedAt) as? Date, sharedUpdate >= lastUpdated {
            return
        }
        shared.set(lastUpdated, forKey: UserDefaultsKeys.sharedRatesUpdatedAt)
        ratesRefreshed()
    }

    private func shareLanguage(_ identifier: String?) {
        guard identifier != shared.string(forKey: UserDefaultsKeys.appLanguage) else { return }
        shared.set(identifier, forKey: UserDefaultsKeys.appLanguage)
        languageChanged()
    }
}
