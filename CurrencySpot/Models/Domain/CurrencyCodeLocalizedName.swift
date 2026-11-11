import Foundation

extension CurrencyCode {
    private static var localizedNames = [CurrencyCode: String]()

    var localizedName: String {
        if let cached = Self.localizedNames[self] {
            return cached
        }

        let name = uncachedLocalizedName
        Self.localizedNames[self] = name
        return name
    }

    nonisolated var uncachedLocalizedName: String {
        localizedName(in: .current)
    }

    nonisolated func localizedName(in locale: Locale) -> String {
        locale.localizedString(forCurrencyCode: rawValue)
            ?? Locale(identifier: "en_US").localizedString(forCurrencyCode: rawValue)
            ?? rawValue
    }
}
