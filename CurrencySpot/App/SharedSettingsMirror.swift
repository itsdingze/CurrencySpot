import Foundation
import Observation

final class SharedSettingsMirror {
    private let favorites: CurrencyCodeListStore
    private let preferences: PreferencesStore
    private let ratesStore: ExchangeRatesStore
    private let shared: UserDefaults
    private let favoritesChanged: () -> Void
    private let ratesRefreshed: () -> Void

    private var sharedFavorites: [String]?

    init(
        favorites: CurrencyCodeListStore,
        preferences: PreferencesStore,
        ratesStore: ExchangeRatesStore,
        shared: UserDefaults,
        favoritesChanged: @escaping () -> Void,
        ratesRefreshed: @escaping () -> Void
    ) {
        self.favorites = favorites
        self.preferences = preferences
        self.ratesStore = ratesStore
        self.shared = shared
        self.favoritesChanged = favoritesChanged
        self.ratesRefreshed = ratesRefreshed
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
}
