import Foundation

nonisolated enum AmountFractionDigits {
    private static let maximumDigits = 6

    static func usual(for currency: CurrencyCode) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        return formatter.maximumFractionDigits
    }

    static func showing(_ amount: Decimal, in currency: CurrencyCode) -> Int {
        max(usual(for: currency), ownDigits(of: amount))
    }

    private static func ownDigits(of amount: Decimal) -> Int {
        var scaled = amount
        var digits = 0
        while digits < maximumDigits, !isWhole(scaled) {
            scaled *= 10
            digits += 1
        }
        return digits
    }

    private static func isWhole(_ value: Decimal) -> Bool {
        var value = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded == value
    }
}
