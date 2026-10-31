import Foundation

enum CurrencyCatalog {
    private static let commonCurrencies: [CurrencyCode] = Set(Locale.commonISOCurrencyCodes.compactMap { CurrencyCode($0) }).sorted()

    static func currencies(in shared: UserDefaults) -> [CurrencyCode] {
        let rated = shared.stringArray(forKey: UserDefaultsKeys.rateCurrencies)?.compactMap { CurrencyCode($0) } ?? []
        return rated.isEmpty ? commonCurrencies : rated
    }

    static func search(_ text: String, in shared: UserDefaults) -> [CurrencyCode] {
        currencies(in: shared).filter { CurrencySearch.matches(code: $0, name: $0.localizedName, searchText: text) }
    }

    static func suggested(in defaults: UserDefaults) -> [CurrencyCode] {
        let favorites = defaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies)?.compactMap { CurrencyCode($0) } ?? []
        return favorites.isEmpty ? CurrencyDefaults.favoriteCurrencies : favorites
    }
}
