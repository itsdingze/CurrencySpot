import Foundation

enum CurrencyNameLookup {
    private static var currencyNameCache = [CurrencyCode: String]()

    static func name(for code: CurrencyCode) -> String {
        if let cachedName = currencyNameCache[code] {
            return cachedName
        }

        let name: String
        if let localName = NSLocale.current.localizedString(forCurrencyCode: code.rawValue) {
            name = localName
        } else {
            let enLocale = NSLocale(localeIdentifier: "en_US")
            name = enLocale.displayName(forKey: .currencyCode, value: code.rawValue) ?? code.rawValue
        }

        currencyNameCache[code] = name
        return name
    }
}
