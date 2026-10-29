import Foundation

enum CurrencyCatalog {
    static let allCurrencies: [CurrencyCode] = Set(Locale.commonISOCurrencyCodes.compactMap { CurrencyCode($0) }).sorted()

    static func search(_ text: String) -> [CurrencyCode] {
        allCurrencies.filter { CurrencySearch.matches(code: $0, name: $0.localizedName, searchText: text) }
    }

    static func suggested(in defaults: UserDefaults) -> [CurrencyCode] {
        defaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies)?.compactMap { CurrencyCode($0) }
            ?? CurrencyDefaults.favoriteCurrencies
    }
}
