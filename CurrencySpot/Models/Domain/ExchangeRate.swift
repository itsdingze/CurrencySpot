import Foundation

nonisolated struct ExchangeRate: Identifiable, Equatable, Sendable {
    let currencyCode: CurrencyCode
    let rate: Double

    var id: CurrencyCode { currencyCode }
}
