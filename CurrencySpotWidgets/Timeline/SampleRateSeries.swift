import Foundation

enum SampleRateSeries {
    private static let usdRates: [CurrencyCode: Double] = [
        .usd: 1, .eur: 0.8612, .gbp: 0.7498, .jpy: 152.37, .cny: 7.124, .cad: 1.3912,
        .aud: 1.5236, .chf: 0.7981, .inr: 87.84, .hkd: 7.7712, .mxn: 18.42, .brl: 5.41,
    ]

    static func entry(for request: RateSeriesRequest) -> RateSeriesEntry {
        RateSeriesEntry(
            date: .now,
            request: request,
            snapshot: RateSeriesSnapshot(series: request.currencies.map { series(for: $0, base: request.base) })
        )
    }

    private static func series(for currency: CurrencyCode, base: CurrencyCode) -> RateSeries {
        guard let target = usdRates[currency], let baseRate = usdRates[base] else {
            return RateSeries(currency: currency, rates: [])
        }
        let latest: Double = target / baseRate
        let drift: Double = Double(seed(for: currency) % 7 - 3) * 0.004
        let rates: [Double] = (0 ..< 22).map { day in
            let remaining: Double = 1 - Double(day) / 21
            let wobble: Double = 0.0012 * sin(Double(day) * 0.7)
            return latest * (1 - drift * remaining + wobble)
        }
        return RateSeries(currency: currency, rates: rates)
    }

    private static func seed(for currency: CurrencyCode) -> Int {
        currency.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }
}
