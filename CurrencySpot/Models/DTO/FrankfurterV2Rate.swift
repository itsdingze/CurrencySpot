//
//  FrankfurterV2Rate.swift
//  CurrencySpot
//

import Foundation

/// A single rate entry from the Frankfurter v2 API.
/// v2 returns a flat array of these (one per currency), unlike v1's keyed `rates` object.
nonisolated struct FrankfurterV2Rate: Codable, Sendable {
    let date: String
    let base: String
    let quote: String
    let rate: Double
}
