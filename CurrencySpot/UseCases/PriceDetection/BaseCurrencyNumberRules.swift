import Foundation

enum BaseCurrencyNumberRules {
    private static let thousandsShorthandBases: Set<String> = ["VND", "IDR"]

    static func readsThousandsShorthand(under baseCurrency: CurrencyCode?) -> Bool {
        baseCurrency.map { thousandsShorthandBases.contains($0.rawValue) } ?? false
    }
}
