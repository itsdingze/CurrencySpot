import Foundation

struct FormattedConversion {
    let amount: String
    let converted: String

    init(_ conversion: ConvertCurrencyUseCase.Conversion) {
        amount = "\(conversion.amount.formatted(.number.precision(.fractionLength(0 ... 2)))) \(conversion.from.rawValue)"
        converted = "\(conversion.converted.formatted(.number.precision(.fractionLength(2)))) \(conversion.to.rawValue)"
    }
}
