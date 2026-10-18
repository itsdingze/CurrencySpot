import Foundation
import Synchronization

nonisolated final class SharedHistoricalFetch: Sendable {
    private nonisolated struct Waiters {
        var count = 0
        var isAbandoned = false
    }

    private let task: Task<[HistoricalRateSnapshot], Error>
    private let waiters = Mutex(Waiters())

    init(task: Task<[HistoricalRateSnapshot], Error>) {
        self.task = task
    }

    func join() -> Bool {
        waiters.withLock { waiters in
            guard !waiters.isAbandoned else { return false }
            waiters.count += 1
            return true
        }
    }

    func value() async throws -> [HistoricalRateSnapshot] {
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            leave()
        }
    }

    func waitUntilFinished() async {
        _ = await task.result
    }

    func abandon() {
        waiters.withLock { $0.isAbandoned = true }
        task.cancel()
    }

    private func leave() {
        let isAbandoned = waiters.withLock { waiters in
            waiters.count -= 1
            if waiters.count == 0 {
                waiters.isAbandoned = true
            }
            return waiters.isAbandoned
        }
        if isAbandoned {
            task.cancel()
        }
    }
}
