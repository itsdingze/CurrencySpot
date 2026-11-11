import Foundation

enum BaseCurrencyNumberRules {
    private static let thousandsShorthandBases: Set<String> = ["VND", "IDR"]
    private static let singleDigitFuelBases: Set<String> = ["EUR", "CHF", "GBP", "USD", "CAD", "AUD", "NZD", "SGD", "BRL"]

    static func readsThousandsShorthand(under baseCurrency: CurrencyCode?) -> Bool {
        baseCurrency.map { thousandsShorthandBases.contains($0.rawValue) } ?? false
    }

    static func readsPerLitreFraction(under baseCurrency: CurrencyCode?) -> Bool {
        baseCurrency.map { singleDigitFuelBases.contains($0.rawValue) } ?? false
    }
}
