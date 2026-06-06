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

    init() {
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
        monitor.cancel()
    }
}
