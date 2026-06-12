//
//  ClockService.swift
//  CurrencySpot
//

import Foundation

/// Seam for time-based suspension so delays are controllable under test.
/// nonisolated so off-main callers (the network retry path) can use it too.
nonisolated protocol ClockService: Sendable {
    func sleep(for duration: Duration) async throws
}

/// Live implementation backed by `ContinuousClock`.
nonisolated struct ContinuousClockService: ClockService {
    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}
