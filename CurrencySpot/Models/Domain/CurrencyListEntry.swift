//
//  CurrencyListEntry.swift
//  CurrencySpot
//

import Foundation

/// One row of the History currency list: code, display name, and the rate
/// already adjusted to the user's base currency.
struct CurrencyListEntry: Identifiable, Equatable, Sendable {
    let code: String
    let name: String
    let rate: Double

    var id: String { code }
}
