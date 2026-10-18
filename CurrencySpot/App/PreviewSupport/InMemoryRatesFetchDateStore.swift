#if DEBUG

    import Foundation

    final class InMemoryRatesFetchDateStore: RatesFetchDateStore {
        var lastFetchDate: Date?

        init(lastFetchDate: Date? = nil) {
            self.lastFetchDate = lastFetchDate
        }
    }

#endif
