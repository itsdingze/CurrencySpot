import Foundation

// MARK: - CalculateConversionUseCase

nonisolated struct CalculateConversionUseCase: Sendable {
    struct Conversion: Equatable, Sendable {
        let amount: Decimal
        let rate: Double
        let converted: Decimal
    }

    func callAsFunction(
        impliedCentsDigits digits: String,
        from base: CurrencyCode,
        to target: CurrencyCode,
        in table: RateTable
    ) -> Conversion {
        let amount = (Decimal(string: digits) ?? 0) / 100

        return Conversion(
            amount: amount,
            rate: table.crossRate(from: base, to: target),
            converted: table.convert(amount, from: base, to: target)
        )
    }

    func impliedCentsDigits(for amount: Decimal) -> String {
        var cents = amount * 100
        var whole = Decimal()
        NSDecimalRound(&whole, &cents, 0, .plain)
        return NSDecimalNumber(decimal: whole).stringValue
    }
}
