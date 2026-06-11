//
//  DateProvider.swift
//  CurrencySpot
//

import Foundation

/// Seam for "now" so business logic is deterministic under test.
protocol DateProvider: Sendable {
    func now() -> Date
}

/// Live implementation backed by the system clock.
struct SystemDateProvider: DateProvider {
    func now() -> Date {
        Date()
    }
}
