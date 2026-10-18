@testable import CurrencySpot
import Foundation

final class MockHistoricalRateRepository: HistoricalRateRepository, ArchiveRepository {
    var earliestStoredDateResult: Date?
    var latestStoredDateResult: Date?
    var storedRows: [HistoricalRateSnapshot] = []
    var fetchedDataToReturn: [HistoricalRateSnapshot] = []
    var fetchedDataProvider: ((Date, Date) -> [HistoricalRateSnapshot])?
    var transientDataToReturn: [HistoricalRateSnapshot] = []
    var shouldThrowErrorOnFetch = false
    var shouldThrowErrorOnLoad = false
    var errorToThrow: Error = AppError.networkError("Mock error")
    var fetchBarrier: (() async -> Void)?

    private(set) var series: [HistoricalRateSnapshot] = []
    private(set) var fetchHistoricalRatesCalls: [(from: Date, to: Date)] = []
    private(set) var fetchTransientCalls: [(currencies: [CurrencyCode], from: Date, to: Date)] = []

    var fetchHistoricalRatesCallCount: Int {
        fetchHistoricalRatesCalls.count
    }

    func seedSeries(_ data: [HistoricalRateSnapshot]) {
        series = data
    }

    func cachedHistoricalRates() async -> [HistoricalRateSnapshot] {
        series
    }

    func fetchAndMergeHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        fetchHistoricalRatesCalls.append((from: range.start, to: range.end))
        await fetchBarrier?()
        if shouldThrowErrorOnFetch {
            throw errorToThrow
        }
        let fetched = fetchedDataProvider?(range.start, range.end) ?? fetchedDataToReturn
        series = HistoricalRateSnapshot.merge(existing: series, new: fetched)
        return fetched
    }

    func loadAndMergeStoredHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        let rows = try await loadStoredHistoricalRates(in: range)
        series = HistoricalRateSnapshot.merge(existing: series, new: rows)
        return rows
    }

    func loadStoredHistoricalRates(in _: DateRange) async throws -> [HistoricalRateSnapshot] {
        if shouldThrowErrorOnLoad {
            throw errorToThrow
        }
        return storedRows
    }

    func earliestStoredDate() async throws -> Date? {
        earliestStoredDateResult
    }

    func latestStoredDate() async throws -> Date? {
        latestStoredDateResult
    }

    func fetchTransientHistoricalRates(for currencies: [CurrencyCode], in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        fetchTransientCalls.append((currencies: currencies, from: range.start, to: range.end))
        if shouldThrowErrorOnFetch {
            throw errorToThrow
        }
        return transientDataToReturn
    }

    private(set) var fetchAndPersistCalls: [(from: Date, to: Date)] = []
    var fetchAndPersistFailAtCall: Int?
    var coverageSkippedAtCall: Int?
    var syncStoreForPersist: MockHistoricalSyncStore?

    func fetchAndPersistHistoricalRates(in range: DateRange) async throws {
        fetchAndPersistCalls.append((from: range.start, to: range.end))
        await fetchBarrier?()
        if shouldThrowErrorOnFetch || fetchAndPersistCalls.count == fetchAndPersistFailAtCall {
            throw errorToThrow
        }
        guard fetchAndPersistCalls.count != coverageSkippedAtCall, let syncStoreForPersist else { return }
        syncStoreForPersist.record(from: range.start, through: range.end, at: range.end)
        earliestStoredDateResult = Swift.min(earliestStoredDateResult ?? range.start, range.start)
        latestStoredDateResult = Swift.max(latestStoredDateResult ?? range.end, range.end)
    }

    func pruneHistoricalRates(before cutoff: Date) async throws {
        guard let earliest = earliestStoredDateResult, earliest < cutoff else { return }
        earliestStoredDateResult = cutoff
    }

    var inFlightMergingFetchesSettle: (() -> Void)?

    func archiveStoredBounds() async throws -> (earliest: Date?, latest: Date?) {
        inFlightMergingFetchesSettle?()
        return (earliestStoredDateResult, latestStoredDateResult)
    }
}
