//
//  AppState.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/24/25.
//

import Foundation
import SwiftUI

/// A request to prefill the calculator with a conversion (e.g. from the camera's
/// "open in converter"); consumed by CalculatorViewModel when it appears.
struct PendingConversion: Equatable, Sendable {
    let baseCurrency: String
    let targetCurrency: String
    /// Implied-cents digit string, the calculator's input format ("120000" → 1200.00).
    let amountInput: String
}

@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    private(set) var errorHandler = ErrorHandler()
    private(set) var networkMonitor: NetworkMonitor

    /// App-wide tab selection, so features can deep-link into other tabs.
    var selectedTab = AppTab.convert

    /// Cross-feature conversion handoff into the calculator.
    var pendingConversion: PendingConversion?

    /// Production code uses `shared`; tests create isolated instances so
    /// parallel runs can't clobber each other's state. Tests inject a
    /// non-monitoring `NetworkMonitor` to pin connectivity deterministically.
    init(networkMonitor: NetworkMonitor? = nil) {
        // Constructed here (not as a default argument) because the monitor's
        // init is main-actor-isolated and default arguments are nonisolated.
        self.networkMonitor = networkMonitor ?? NetworkMonitor()
    }
}
