import Foundation

nonisolated struct RateSeries: Equatable, Sendable, Codable {
    let currency: CurrencyCode
    let rates: [Double]

    var latestRate: Double? { rates.last }

    var averageRate: Double? {
        rates.isEmpty ? nil : rates.reduce(0, +) / Double(rates.count)
    }

    var percentChange: Double? {
        guard let first = rates.first, let last = rates.last else { return nil }
        return RateMath.percentChange(from: first, to: last)
    }

    var direction: TrendDirection? {
        percentChange.map(TrendDirection.init(percentChange:))
    }

    static func series(for currencies: [CurrencyCode], in response: HistoricalRatesResponse) -> [RateSeries] {
        let days = response.rates.keys.sorted().compactMap { response.rates[$0] }
        return currencies.map { currency in
            let rates = currency.rawValue == response.base
                ? days.map { _ in 1.0 }
                : days.compactMap { $0[currency.rawValue] }
            return RateSeries(currency: currency, rates: rates)
        }
    }
}
