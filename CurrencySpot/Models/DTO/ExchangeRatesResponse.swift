//
//  ExchangeRatesResponse.swift
//  CurrencySpot
//

import Foundation

/// Network DTO: latest USD-normalized rates keyed by currency code.
/// Never leaks above the data coordinator; the repository surface speaks domain types.
nonisolated struct ExchangeRatesResponse: Codable, Sendable {
    let base: String
    let date: String
    let rates: [String: Double]
}
