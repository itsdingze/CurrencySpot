//
//  ExchangeRate.swift
//  CurrencySpot
//

import Foundation

/// A current USD-normalized exchange rate for one currency.
nonisolated struct ExchangeRate: Identifiable, Equatable, Sendable {
    let currencyCode: CurrencyCode
    let rate: Double

    var id: CurrencyCode { currencyCode }
}
