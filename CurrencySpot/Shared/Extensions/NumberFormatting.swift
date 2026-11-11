import Foundation

extension Double {
    var rateText: String {
        rateText(matching: self)
    }

    func rateText(in locale: Locale) -> String {
        rateText(matching: self, locale: locale)
    }

    func rateText(matching rate: Double, locale: Locale = .autoupdatingCurrent) -> String {
        formatted(.number.precision(.fractionLength(rate.rateFractionDigits)).locale(locale))
    }

    private var rateFractionDigits: Int {
        let magnitude = abs(self)
        guard magnitude.isNormal else { return 0 }
        let significantDigits = magnitude < 1 ? 4 : 5
        let wholeDigits = Int(log10(magnitude).rounded(.down)) + 1
        return max(0, significantDigits - wholeDigits)
    }

    func axisLabel(across span: Double) -> String {
        formatted(.number.precision(.fractionLength(0 ... Self.axisFractionDigits(across: span))))
    }

    private static func axisFractionDigits(across span: Double) -> Int {
        guard span > 0 else { return 2 }
        return max(0, Int((-log10(span / 10)).rounded(.up)))
    }
}

extension Decimal {
    func amountText(in currency: CurrencyCode, locale: Locale = .autoupdatingCurrent) -> String {
        "\(formatted(.number.locale(locale).precision(.fractionLength(2)))) \(currency.rawValue)"
    }
}

extension FormatStyle where Self == Decimal.FormatStyle {
    static var compactAmount: Self {
        .number.notation(.compactName).precision(.fractionLength(0 ... 1))
    }
}
