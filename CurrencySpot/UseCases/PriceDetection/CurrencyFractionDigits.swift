import Foundation

enum CurrencyFractionDigits {
    private static let threeDigitCurrencies: Set<String> = ["KWD", "BHD", "OMR", "JOD", "TND", "LYD"]

    static func count(for currency: CurrencyCode?) -> Int {
        currency.map { threeDigitCurrencies.contains($0.rawValue) } == true ? 3 : 2
    }
}
