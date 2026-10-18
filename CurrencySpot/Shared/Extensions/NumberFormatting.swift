import Foundation

extension Double {
    var toStringMax4Decimals: String {
        formatted(.number.precision(.fractionLength(0 ... 4)))
    }

    func axisLabel(across span: Double) -> String {
        formatted(.number.precision(.fractionLength(0 ... Self.axisFractionDigits(across: span))))
    }

    private static func axisFractionDigits(across span: Double) -> Int {
        guard span > 0 else { return 2 }
        return max(0, Int((-log10(span / 10)).rounded(.up)))
    }
}

extension FormatStyle where Self == Decimal.FormatStyle {
    static var compactAmount: Self {
        .number.notation(.compactName).precision(.fractionLength(0 ... 1))
    }
}
