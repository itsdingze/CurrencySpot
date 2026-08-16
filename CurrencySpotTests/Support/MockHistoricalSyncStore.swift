@testable import CurrencySpot
import Foundation

final class MockHistoricalSyncStore: HistoricalSyncStore, SyncCoverageRepository {
    var from: Date?
    var through: Date?
    var checkedAt: Date?
    private(set) var recordCallCount = 0

    init(from: Date? = nil, through: Date? = nil, checkedAt: Date? = nil) {
        self.from = from
        self.through = through
        self.checkedAt = checkedAt
    }

    func record(from newFrom: Date, through newThrough: Date, at now: Date) {
        recordCallCount += 1
        from = Swift.min(from ?? newFrom, newFrom)
        through = Swift.max(through ?? newThrough, newThrough)
        checkedAt = now
    }

    var coveredFrom: Date? { from }
    var coveredThrough: Date? { through }
    var coverageCheckedAt: Date? { checkedAt }

    func recordCoverage(from newFrom: Date, through newThrough: Date, at now: Date) {
        record(from: newFrom, through: newThrough, at: now)
    }

    func reset() {
        from = nil
        through = nil
        checkedAt = nil
    }
}
