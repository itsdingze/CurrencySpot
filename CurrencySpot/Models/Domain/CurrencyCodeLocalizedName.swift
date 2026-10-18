import Foundation

extension CurrencyCode {
    private static var localizedNames = [CurrencyCode: String]()

    var localizedName: String {
        if let cached = Self.localizedNames[self] {
            return cached
        }

        let name = Locale.current.localizedString(forCurrencyCode: rawValue)
            ?? Locale(identifier: "en_US").localizedString(forCurrencyCode: rawValue)
            ?? rawValue

        Self.localizedNames[self] = name
        return name
    }
}
