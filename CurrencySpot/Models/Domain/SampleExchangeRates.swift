import Foundation

enum SampleExchangeRates {
    static let rates: [CurrencyCode: Double] = [
        .usd: 1.0,
        .eur: 0.85,
        .gbp: 0.73,
        .jpy: 110.0,
        .cad: 1.25,
        .aud: 1.35,
        .cny: 6.45,
        .inr: 74.5,
        .chf: 0.92,
        .mxn: 20.0,
        .brl: 5.4,
        .rub: 75.0,
    ]

    static func getCurrencyRates() -> [ExchangeRate] {
        rates.map { code, rate in
            ExchangeRate(currencyCode: code, rate: rate)
        }
    }
}
