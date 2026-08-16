import Foundation
import SwiftUI

struct PendingConversion: Equatable, Sendable {
    let baseCurrency: CurrencyCode
    let targetCurrency: CurrencyCode
    let amountInput: String
}

@Observable
final class AppState {
    static let shared = AppState()

    private(set) var errorHandler = ErrorHandler()
    private(set) var networkMonitor: NetworkMonitor

    var selectedTab = AppTab.convert

    var pendingConversion: PendingConversion?

    init(networkMonitor: NetworkMonitor? = nil) {
        self.networkMonitor = networkMonitor ?? NetworkMonitor()
    }
}
