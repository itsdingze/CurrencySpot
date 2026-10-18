import Foundation
import SwiftUI

struct PendingConversion: Equatable, Sendable {
    let baseCurrency: CurrencyCode
    let targetCurrency: CurrencyCode
    let amountInput: String
}

@Observable
final class AppState {
    static let shared = AppState(networkMonitor: NetworkMonitor())

    private(set) var errorHandler = ErrorHandler()
    private(set) var networkMonitor: NetworkMonitor

    var selectedTab = AppTab.convert

    var pendingConversion: PendingConversion?

    private(set) var dataResetCount = 0

    init(networkMonitor: NetworkMonitor) {
        self.networkMonitor = networkMonitor
    }

    func dataWasReset() {
        dataResetCount += 1
    }
}
