@testable import CurrencySpot
import Foundation

final class MockHistoricalRateRepository: HistoricalRateRepository {
    var earliestStoredDateResult: Date?
    var latestStoredDateResult: Date?
    var historicalDataToReturn: [HistoricalRateSnapshot] = []
    var fetchedDataToReturn: [HistoricalRateSnapshot] = []
    var fetchedDataProvider: ((Date, Date) -> [HistoricalRateSnapshot])?
    var shouldThrowErrorOnFetch = false
    var shouldThrowErrorOnLoad = false
    var errorToThrow: Error = AppError.networkError("Mock error")

    private(set) var fetchHistoricalRatesCalls: [(from: Date, to: Date)] = []
    private(set) var loadHistoricalRatesCallCount = 0
    private(set) var waitForPendingWritesCallCount = 0
    private(set) var cachedData: [HistoricalRateSnapshot] = []
    private(set) var mergeCachedCallCount = 0
    private(set) var cachedReadCount = 0

    var fetchHistoricalRatesCallCount: Int {
        fetchHistoricalRatesCalls.count
    }

    func seedCache(_ data: [HistoricalRateSnapshot]) {
        cachedData = data
    }

    var fetchBarrier: (() async -> Void)?

    func fetchHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        fetchHistoricalRatesCalls.append((from: range.start, to: range.end))
        await fetchBarrier?()
        if shouldThrowErrorOnFetch {
            throw errorToThrow
        }
        return fetchedDataProvider?(range.start, range.end) ?? fetchedDataToReturn
    }

    func waitForPendingHistoricalWrites() async {
        waitForPendingWritesCallCount += 1
        drainPendingPersists()
    }

    var transientDataToReturn: [HistoricalRateSnapshot] = []
    private(set) var fetchTransientCalls: [(currencies: [CurrencyCode], from: Date, to: Date)] = []

    func fetchTransientHistoricalRates(for currencies: [CurrencyCode], in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        fetchTransientCalls.append((currencies: currencies, from: range.start, to: range.end))
        if shouldThrowErrorOnFetch {
            throw errorToThrow
        }
        return transientDataToReturn
    }

    private(set) var fetchAndPersistCalls: [(from: Date, to: Date)] = []
    var fetchAndPersistFailAtCall: Int?
    var persistFailAtCall: Int?
    var syncStoreForPersist: MockHistoricalSyncStore?

    private var pendingPersists: [(from: Date, to: Date)] = []
    private var persistDrainCount = 0

    func fetchAndPersistHistoricalRates(in range: DateRange) async throws {
        drainPendingPersists()
        fetchAndPersistCalls.append((from: range.start, to: range.end))
        await fetchBarrier?()
        if shouldThrowErrorOnFetch || fetchAndPersistCalls.count == fetchAndPersistFailAtCall {
            throw errorToThrow
        }
        pendingPersists.append((from: range.start, to: range.end))
    }

    private func drainPendingPersists() {
        for persist in pendingPersists {
            persistDrainCount += 1
            if persistDrainCount == persistFailAtCall { continue }
            if let syncStoreForPersist {
                syncStoreForPersist.record(from: persist.from, through: persist.to, at: persist.to)
                earliestStoredDateResult = Swift.min(earliestStoredDateResult ?? persist.from, persist.from)
                latestStoredDateResult = Swift.max(latestStoredDateResult ?? persist.to, persist.to)
            }
        }
        pendingPersists.removeAll()
    }

    func loadHistoricalRates(in _: DateRange) async throws -> [HistoricalRateSnapshot] {
        if shouldThrowErrorOnLoad {
            throw errorToThrow
        }
        loadHistoricalRatesCallCount += 1
        return historicalDataToReturn
    }

    func earliestStoredDate() async throws -> Date? {
        earliestStoredDateResult
    }

    func latestStoredDate() async throws -> Date? {
        latestStoredDateResult
    }

    func cachedHistoricalRates() async -> [HistoricalRateSnapshot] {
        cachedReadCount += 1
        return cachedData
    }

    func mergeCachedHistoricalRates(_ new: [HistoricalRateSnapshot]) async -> [HistoricalRateSnapshot] {
        mergeCachedCallCount += 1
        cachedData = HistoricalRateSnapshot.merge(existing: cachedData, new: new)
        return cachedData
    }
}
