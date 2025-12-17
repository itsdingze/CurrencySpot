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
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
