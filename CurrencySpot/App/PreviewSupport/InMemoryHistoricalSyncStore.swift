#if DEBUG

    import Foundation

    final class InMemoryHistoricalSyncStore: HistoricalSyncStore {
        private(set) var from: Date?
        private(set) var through: Date?
        private(set) var checkedAt: Date?

        func record(from newFrom: Date, through newThrough: Date, at now: Date) {
            from = Swift.min(from ?? newFrom, newFrom)
            through = Swift.max(through ?? newThrough, newThrough)
            checkedAt = now
        }

        func reset() {
            from = nil
            through = nil
            checkedAt = nil
        }
    }

#endif
