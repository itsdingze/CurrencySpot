import Foundation

enum CurrencyNameLookup {
    private static var currencyNameCache = [CurrencyCode: String]()

    static func name(for code: CurrencyCode) -> String {
        if let cachedName = currencyNameCache[code] {
            return cachedName
        }

        let name = Locale.current.localizedString(forCurrencyCode: code.rawValue)
            ?? Locale(identifier: "en_US").localizedString(forCurrencyCode: code.rawValue)
            ?? code.rawValue

        currencyNameCache[code] = name
        return name
    }
}
