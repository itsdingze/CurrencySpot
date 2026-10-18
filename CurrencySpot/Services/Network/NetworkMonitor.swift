import Foundation
import Network

@Observable
final class NetworkMonitor {
    private(set) var isConnected: Bool
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    convenience init() {
        self.init(connectionUpdates: Self.systemConnectionUpdates())
    }

    init(isConnected: Bool) {
        self.isConnected = isConnected
    }

    init(connectionUpdates: AsyncStream<Bool>) {
        isConnected = true
        updatesTask = Task { [weak self] in
            for await isConnected in connectionUpdates {
                self?.isConnected = isConnected
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    static func systemConnectionUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let pathUpdates = Task {
                for await path in NWPathMonitor() {
                    continuation.yield(path.status == .satisfied)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in pathUpdates.cancel() }
        }
    }
}
