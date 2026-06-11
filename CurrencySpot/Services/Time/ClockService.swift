//
//  ClockService.swift
//  CurrencySpot
//

import Foundation

/// Seam for time-based suspension so delays are controllable under test.
protocol ClockService: Sendable {
    func sleep(for duration: Duration) async throws
}

/// Live implementation backed by `ContinuousClock`.
struct ContinuousClockService: ClockService {
    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}
