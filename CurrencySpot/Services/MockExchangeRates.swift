//
//  MockExchangeRates.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/24/25.
//

import Foundation

/// Static sample rates. Lives in the production target on purpose: the calculator's
/// offline-with-no-cache fallback (`CalculatorViewModel.useMockData`, with its
/// "Using mock data" banner) consumes these in release builds.
enum MockExchangeRates {
    static let rates: [String: Double] = [
        "USD": 1.0,
        "EUR": 0.85,
        "GBP": 0.73,
        "JPY": 110.0,
        "CAD": 1.25,
        "AUD": 1.35,
        "CNY": 6.45,
        "INR": 74.5,
        "CHF": 0.92,
        "MXN": 20.0,
        "BRL": 5.4,
        "RUB": 75.0,
    ]

    static func getCurrencyRates() -> [ExchangeRate] {
        rates.compactMap { code, rate in
            CurrencyCode(code).map { ExchangeRate(currencyCode: $0, rate: rate) }
        }
    }

    static let trendData: [String: Trend] = [
        "AUD": makeTrend("AUD", weeklyChange: 2.3, miniChartData: [1.52, 1.53, 1.54, 1.55, 1.56, 1.57, 1.55]),
        "BRL": makeTrend("BRL", weeklyChange: -1.8, miniChartData: [5.65, 5.63, 5.61, 5.59, 5.57, 5.55, 5.58]),
        "GBP": makeTrend("GBP", weeklyChange: -0.5, miniChartData: [0.76, 0.755, 0.753, 0.751, 0.749, 0.748, 0.75]),
        "BGN": makeTrend("BGN", weeklyChange: 1.2, miniChartData: [1.67, 1.675, 1.68, 1.685, 1.69, 1.692, 1.69]),
        "CAD": makeTrend("CAD", weeklyChange: 0.8, miniChartData: [1.37, 1.375, 1.378, 1.38, 1.382, 1.385, 1.38]),
        "CNY": makeTrend("CNY", weeklyChange: -0.3, miniChartData: [7.20, 7.19, 7.18, 7.17, 7.16, 7.15, 7.18]),
        "CZK": makeTrend("CZK", weeklyChange: 3.1, miniChartData: [20.5, 20.8, 21.1, 21.4, 21.7, 21.9, 21.28]),
        "DKK": makeTrend("DKK", weeklyChange: -1.2, miniChartData: [6.55, 6.53, 6.51, 6.49, 6.47, 6.44, 6.45]),
        "EUR": makeTrend("EUR", weeklyChange: 0.1, miniChartData: [0.85, 0.855, 0.857, 0.858, 0.859, 0.860, 0.86]),
        "HKD": makeTrend("HKD", weeklyChange: 0.6, miniChartData: [7.80, 7.81, 7.82, 7.83, 7.84, 7.85, 7.85]),
        "USD": makeTrend("USD", weeklyChange: 0.0, miniChartData: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]),
    ]

    /// Fixture builder: codes here are compile-time constants, so force-validation is safe.
    private static func makeTrend(_ code: String, weeklyChange: Double, miniChartData: [Double]) -> Trend {
        Trend(
            currencyCode: CurrencyCode(code) ?? .usd,
            weeklyChange: weeklyChange,
            miniChartData: miniChartData
        )
    }
}
