//
//  ExchangeRatesStore.swift
//  CurrencySpot
//

import Foundation
import Observation

// MARK: - ExchangeRatesStore

/// Shared, observable snapshot of the currently displayed exchange rates.
///
/// CalculatorViewModel is the single writer — it owns the fetch/cache/mock-fallback
/// policy and publishes its result here. Camera and History features read this store
/// instead of reaching into a sibling ViewModel, which keeps the mock-data offline
/// path (which exists only in the calculator) visible to every feature.
@MainActor
@Observable
final class ExchangeRatesStore {
    private(set) var rates: [ExchangeRate] = []
    private(set) var lastUpdated: Date?
    private(set) var isUsingMockData = false

    /// The calculator's selected base currency, shared so History can follow it
    /// without view-driven syncing.
    private(set) var baseCurrency: String = CurrencyCode.usd.rawValue

    var formattedLastUpdated: String {
        guard let date = lastUpdated else { return "Not updated yet" }
        return "Last updated: \(TimeZoneManager.formatLastUpdated(date))"
    }

    func update(rates: [ExchangeRate], lastUpdated: Date?, isUsingMockData: Bool) {
        self.rates = rates
        self.lastUpdated = lastUpdated
        self.isUsingMockData = isUsingMockData
    }

    func updateBaseCurrency(_ currency: String) {
        baseCurrency = currency
    }
}
