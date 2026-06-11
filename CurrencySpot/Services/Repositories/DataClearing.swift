//
//  DataClearing.swift
//  CurrencySpot
//

import Foundation

/// Cross-aggregate wipe: persistence, in-memory caches, fetch stamps, and sync coverage.
protocol DataClearing {
    func clearAllData() async throws
}
