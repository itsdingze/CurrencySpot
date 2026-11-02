@testable import CurrencySpot
import Foundation
import Synchronization

nonisolated final class ManualClock: ClockService, Sendable {
    private nonisolated struct Sleeper {
        let deadline: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }

    private nonisolated struct State {
        var now = Duration.zero
        var nextSleeperID = 0
        var sleepers: [Int: Sleeper] = [:]
        var cancelledSleepers: Set<Int> = []
    }

    private let state = Mutex(State())

    var pendingSleepCount: Int {
        state.withLock { $0.sleepers.count }
    }

    func sleep(for duration: Duration) async throws {
        let id = state.withLock { state in
            state.nextSleeperID += 1
            return state.nextSleeperID
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let outcome: Result<Void, any Error>? = state.withLock { state in
                    if state.cancelledSleepers.contains(id) { return .failure(CancellationError()) }
                    let deadline = state.now + duration
                    if deadline <= state.now { return .success(()) }
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return nil
                }
                if let outcome {
                    continuation.resume(with: outcome)
                }
            }
        } onCancel: {
            let sleeper = state.withLock { state in
                state.cancelledSleepers.insert(id)
                return state.sleepers.removeValue(forKey: id)
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(by duration: Duration) {
        let due = state.withLock { state in
            state.now += duration
            let now = state.now
            let due = state.sleepers.filter { $0.value.deadline <= now }
            due.keys.forEach { state.sleepers[$0] = nil }
            return due.values.map(\.continuation)
        }
        due.forEach { $0.resume() }
    }
}
