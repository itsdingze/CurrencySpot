import Foundation
import Network

@Observable
final class NetworkMonitor {
    var isConnected = true
    private let monitor = NWPathMonitor()
    private let isMonitoring: Bool

    init(monitorsPathUpdates: Bool = true) {
        isMonitoring = monitorsPathUpdates
        guard monitorsPathUpdates else { return }

        Task { [weak self, monitor] in
            for await path in monitor {
                self?.isConnected = path.status == .satisfied
            }
        }
    }

    deinit {
        if isMonitoring {
            monitor.cancel()
        }
    }
}
