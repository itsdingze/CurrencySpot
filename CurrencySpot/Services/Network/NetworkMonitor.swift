//
//  NetworkMonitor.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/23/25.
//

import Foundation
import Network

@Observable
@MainActor
final class NetworkMonitor {
    var isConnected = true
    private let monitor = NWPathMonitor()
    private let isMonitoring: Bool

    /// Pass `monitorsPathUpdates: false` in tests to pin `isConnected` manually,
    /// so an asynchronous path update can never flip it mid-test.
    init(monitorsPathUpdates: Bool = true) {
        isMonitoring = monitorsPathUpdates
        guard monitorsPathUpdates else { return }

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        // NWPathMonitor.start(queue:) requires a DispatchQueue by API contract; the callback
        // immediately hops back to the main actor, so this is not legacy GCD to migrate away.
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }

    deinit {
        if isMonitoring {
            monitor.cancel()
        }
    }
}
