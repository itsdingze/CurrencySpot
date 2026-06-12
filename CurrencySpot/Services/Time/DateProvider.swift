//
//  DateProvider.swift
//  CurrencySpot
//

import Foundation

/// Seam for "now" so business logic is deterministic under test.
/// Nonisolated so @concurrent network code can read the clock off the main actor.
nonisolated protocol DateProvider: Sendable {
    func now() -> Date
}

/// Live implementation backed by the system clock.
nonisolated struct SystemDateProvider: DateProvider {
    func now() -> Date {
        Date()
    }
}
