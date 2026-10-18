@testable import CurrencySpot
import Foundation
import Synchronization

nonisolated final class GatedClock: ClockService, Sendable {
    private nonisolated struct RequestWatcher {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private nonisolated struct State {
        var sleepRequestCount = 0
        var cancelledSleepCount = 0
        var isReleased = false
        var suspendedSleeps: [Int: CheckedContinuation<Void, Never>] = [:]
        var cancelledSleeps: Set<Int> = []
        var nextWatcherID = 0
        var requestWatchers: [Int: RequestWatcher] = [:]
        var cancelledWatchers: Set<Int> = []
    }

    private let state = Mutex(State())

    var sleepRequestCount: Int {
        state.withLock { $0.sleepRequestCount }
    }

    var cancelledSleepCount: Int {
        state.withLock { $0.cancelledSleepCount }
    }

    func sleep(for _: Duration) async {
        let (sleepNumber, satisfiedWatchers) = state.withLock { state in
            state.sleepRequestCount += 1
            let count = state.sleepRequestCount
            let satisfied = state.requestWatchers.filter { $0.value.count <= count }
            satisfied.keys.forEach { state.requestWatchers[$0] = nil }
            return (count, satisfied.values.map(\.continuation))
        }
        satisfiedWatchers.forEach { $0.resume() }

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let resumesNow = state.withLock { state in
                    guard !state.isReleased, !state.cancelledSleeps.contains(sleepNumber) else { return true }
                    state.suspendedSleeps[sleepNumber] = continuation
                    return false
                }
                if resumesNow {
                    continuation.resume()
                }
            }
        } onCancel: {
            let suspended = state.withLock { state in
                state.cancelledSleepCount += 1
                state.cancelledSleeps.insert(sleepNumber)
                return state.suspendedSleeps.removeValue(forKey: sleepNumber)
            }
            suspended?.resume()
        }
    }

    func waitForSleepRequests(_ count: Int) async {
        let watcherID = state.withLock { state in
            state.nextWatcherID += 1
            return state.nextWatcherID
        }

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let resumesNow = state.withLock { state in
                    guard state.sleepRequestCount < count, !state.cancelledWatchers.contains(watcherID) else { return true }
                    state.requestWatchers[watcherID] = RequestWatcher(count: count, continuation: continuation)
                    return false
                }
                if resumesNow {
                    continuation.resume()
                }
            }
        } onCancel: {
            let watcher = state.withLock { state in
                state.cancelledWatchers.insert(watcherID)
                return state.requestWatchers.removeValue(forKey: watcherID)
            }
            watcher?.continuation.resume()
        }
    }

    func release() {
        let suspended = state.withLock { state in
            state.isReleased = true
            let suspended = Array(state.suspendedSleeps.values)
            state.suspendedSleeps.removeAll()
            return suspended
        }
        suspended.forEach { $0.resume() }
    }
}
