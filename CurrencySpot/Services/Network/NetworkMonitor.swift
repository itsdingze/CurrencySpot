import Foundation
import Network

@Observable
final class NetworkMonitor {
    nonisolated struct Path: Equatable, Sendable {
        let isConnected: Bool
        let isConstrained: Bool
    }

    private(set) var isConnected: Bool
    private(set) var isConstrained: Bool
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    convenience init() {
        self.init(pathUpdates: Self.systemPathUpdates())
    }

    init(isConnected: Bool, isConstrained: Bool = false) {
        self.isConnected = isConnected
        self.isConstrained = isConstrained
    }

    init(pathUpdates: AsyncStream<Path>) {
        isConnected = true
        isConstrained = false
        updatesTask = Task { [weak self] in
            for await path in pathUpdates {
                self?.isConnected = path.isConnected
                self?.isConstrained = path.isConstrained
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    static func systemPathUpdates() -> AsyncStream<Path> {
        AsyncStream { continuation in
            let pathUpdates = Task {
                for await path in NWPathMonitor() {
                    continuation.yield(Path(isConnected: path.status == .satisfied, isConstrained: path.isConstrained))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in pathUpdates.cancel() }
        }
    }
}
