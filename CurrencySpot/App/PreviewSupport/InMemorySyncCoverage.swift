#if DEBUG

    import Foundation

    final class InMemorySyncCoverage: SyncCoverageRepository {
        private(set) var coveredFrom: Date?
        private(set) var coveredThrough: Date?
        private(set) var coverageCheckedAt: Date?

        init(from: Date? = nil, through: Date? = nil, checkedAt: Date? = nil) {
            coveredFrom = from
            coveredThrough = through
            coverageCheckedAt = checkedAt
        }

        func recordCoverage(from: Date, through: Date, at now: Date) {
            coveredFrom = Swift.min(coveredFrom ?? from, from)
            coveredThrough = Swift.max(coveredThrough ?? through, through)
            coverageCheckedAt = now
        }
    }

#endif
