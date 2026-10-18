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

    static let trendData: [Trend] = [
        Trend(currencyCode: .aud, weeklyChange: 2.3, miniChartData: [1.52, 1.53, 1.54, 1.55, 1.56, 1.57, 1.55]),
        Trend(currencyCode: .brl, weeklyChange: -1.8, miniChartData: [5.65, 5.63, 5.61, 5.59, 5.57, 5.55, 5.58]),
        Trend(currencyCode: .gbp, weeklyChange: -0.5, miniChartData: [0.76, 0.755, 0.753, 0.751, 0.749, 0.748, 0.75]),
        Trend(currencyCode: .bgn, weeklyChange: 1.2, miniChartData: [1.67, 1.675, 1.68, 1.685, 1.69, 1.692, 1.69]),
        Trend(currencyCode: .cad, weeklyChange: 0.8, miniChartData: [1.37, 1.375, 1.378, 1.38, 1.382, 1.385, 1.38]),
        Trend(currencyCode: .cny, weeklyChange: -0.3, miniChartData: [7.20, 7.19, 7.18, 7.17, 7.16, 7.15, 7.18]),
        Trend(currencyCode: .czk, weeklyChange: 3.1, miniChartData: [20.5, 20.8, 21.1, 21.4, 21.7, 21.9, 21.28]),
        Trend(currencyCode: .dkk, weeklyChange: -1.2, miniChartData: [6.55, 6.53, 6.51, 6.49, 6.47, 6.44, 6.45]),
        Trend(currencyCode: .eur, weeklyChange: 0.1, miniChartData: [0.85, 0.855, 0.857, 0.858, 0.859, 0.860, 0.86]),
        Trend(currencyCode: .hkd, weeklyChange: 0.6, miniChartData: [7.80, 7.81, 7.82, 7.83, 7.84, 7.85, 7.85]),
        Trend(currencyCode: .usd, weeklyChange: 0.0, miniChartData: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]),
    ]
}
