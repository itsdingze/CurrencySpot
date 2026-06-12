//
//  Mocks.swift
//  CurrencySpotTests
//
//  Shared configurable test doubles, one per repository/service protocol.
//

@testable import CurrencySpot
import Foundation

// MARK: - MockHistoricalSyncStore

/// In-memory test double for HistoricalSyncStore.
final class MockHistoricalSyncStore: HistoricalSyncStore {
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

    func reset() {
        from = nil
        through = nil
        checkedAt = nil
    }
}

// MARK: - MockNetworkService

/// Configurable in-memory NetworkService double. Defaults fail every request,
/// so a test that forgets to stub a response can never reach the live API.
final class MockNetworkService: NetworkService {
    var shouldFetchNewRatesResult = true
    var exchangeRatesResult: Result<ExchangeRatesResponse, Error> =
        .failure(AppError.networkError("MockNetworkService: no exchange rates stubbed"))
    var historicalRatesResult: Result<HistoricalRatesResponse, Error> =
        .failure(AppError.networkError("MockNetworkService: no historical rates stubbed"))

    private(set) var lastFetchDate: Date?
    private(set) var fetchExchangeRatesCallCount = 0
    private(set) var fetchHistoricalRatesCalls: [(from: Date, to: Date)] = []

    func shouldFetchNewRates() async -> Bool {
        shouldFetchNewRatesResult
    }

    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        fetchExchangeRatesCallCount += 1
        return try exchangeRatesResult.get()
    }

    /// When set, historical fetches suspend here until the test releases it — lets
    /// tests run other work (e.g. clearAllData) while a fetch is in flight.
    var historicalFetchBarrier: (() async -> Void)?

    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse {
        fetchHistoricalRatesCalls.append((from: startDate, to: endDate))
        await historicalFetchBarrier?()
        return try historicalRatesResult.get()
    }

    func updateLastFetchDate(_ date: Date) {
        lastFetchDate = date
    }

    func getLastFetchDate() -> Date? {
        lastFetchDate
    }
}

// MARK: - MockExchangeRateRepository

/// Configurable ExchangeRateRepository double mirroring the production contract:
/// a successful fetch stamps the last-fetch date (the repository owns bookkeeping).
final class MockExchangeRateRepository: ExchangeRateRepository {
    var shouldRefreshRatesResult = false
    var fetchExchangeRatesResult: Result<[ExchangeRate], AppError> = .success([
        ExchangeRate(currencyCode: "USD", rate: 1.0),
        ExchangeRate(currencyCode: "EUR", rate: 0.9),
    ])
    var loadExchangeRatesResult: Result<[ExchangeRate], AppError> = .success([])

    private(set) var fetchExchangeRatesCallCount = 0
    private(set) var loadExchangeRatesCallCount = 0
    private(set) var stampedFetchDate: Date?

    func shouldRefreshRates() async -> Bool {
        shouldRefreshRatesResult
    }

    func fetchExchangeRates() async throws -> [ExchangeRate] {
        fetchExchangeRatesCallCount += 1
        let rates = try fetchExchangeRatesResult.get()
        stampedFetchDate = Date()
        return rates
    }

    func loadExchangeRates() async throws -> [ExchangeRate] {
        loadExchangeRatesCallCount += 1
        return try loadExchangeRatesResult.get()
    }

    func lastFetchDate() -> Date? {
        stampedFetchDate
    }
}

// MARK: - MockHistoricalRateRepository

/// Configurable HistoricalRateRepository double with the repository-owned
/// in-memory cache modeled as a plain dictionary.
final class MockHistoricalRateRepository: HistoricalRateRepository {
    var earliestStoredDateResult: Date?
    var latestStoredDateResult: Date?
    /// Returned by persistence read-backs (`loadHistoricalRates`).
    var historicalDataToReturn: [HistoricalRateSnapshot] = []
    /// Returned by network fetches (`fetchHistoricalRates`).
    var fetchedDataToReturn: [HistoricalRateSnapshot] = []
    /// When set, takes precedence over `fetchedDataToReturn` so each fetch can
    /// return range-specific rows.
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

    /// When set, every fetch suspends here until the test releases it — lets tests
    /// hold a fetch in flight while a second load races it.
    var fetchBarrier: (() async -> Void)?

    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        // Record the attempt before any throw so failed fetches remain observable.
        fetchHistoricalRatesCalls.append((from: startDate, to: endDate))
        await fetchBarrier?()
        if shouldThrowErrorOnFetch {
            throw errorToThrow
        }
        return fetchedDataProvider?(startDate, endDate) ?? fetchedDataToReturn
    }

    func waitForPendingHistoricalWrites() async {
        waitForPendingWritesCallCount += 1
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

// MARK: - MockPersistenceService

/// Configurable PersistenceService double. An actor (like the production `@ModelActor`)
/// so it satisfies the protocol's `Sendable` requirement without unchecked state.
actor MockPersistenceService: PersistenceService {
    private(set) var savedHistoricalRates: [[String: [String: Double]]] = []
    private(set) var clearAllDataCallCount = 0
    /// True when a historical save landed after `clearAllData` — the resurrection
    /// hazard deferred writes must never produce.
    private(set) var savedHistoricalAfterClear = false

    private var saveHistoricalError: Error?

    func stubSaveHistoricalError(_ error: Error?) {
        saveHistoricalError = error
    }

    func saveExchangeRates(_: [String: Double]) async throws {}

    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws {
        if let saveHistoricalError {
            throw saveHistoricalError
        }
        if clearAllDataCallCount > 0 {
            savedHistoricalAfterClear = true
        }
        savedHistoricalRates.append(rates)
    }

    func loadExchangeRates() async throws -> [ExchangeRate] { [] }

    func loadHistoricalRates(currency _: String, from _: Date, to _: Date) async throws -> [HistoricalRateSnapshot] { [] }

    func loadHistoricalRates(from _: Date, to _: Date) async throws -> [HistoricalRateSnapshot] { [] }

    func getEarliestStoredDate() async throws -> Date? { nil }

    func getLatestStoredDate() async throws -> Date? { nil }

    func loadTrendData() async throws -> [Trend] { [] }

    func saveTrendData(_: [Trend]) async throws {}

    func clearAllData() async throws {
        clearAllDataCallCount += 1
    }
}

// MARK: - MockTrendRepository

/// Configurable TrendRepository double. `saveTrendData` replaces the stored set,
/// mirroring the production replace-all semantics.
final class MockTrendRepository: TrendRepository {
    var trendsToReturn: [Trend]
    var historicalWindowData: [HistoricalRateSnapshot] = []
    var shouldThrowOnLoadTrends = false
    var shouldThrowOnSave = false
    var errorToThrow: Error = AppError.unknownError("Mock trend error")

    private(set) var loadTrendDataCallCount = 0
    private(set) var saveTrendDataCallCount = 0
    private(set) var loadHistoricalRatesCallCount = 0
    private(set) var lastSavedTrends: [Trend]?

    init(trends: [Trend] = []) {
        trendsToReturn = trends
    }

    func loadTrendData() async throws -> [Trend] {
        loadTrendDataCallCount += 1
        if shouldThrowOnLoadTrends {
            throw errorToThrow
        }
        return trendsToReturn
    }

    func saveTrendData(_ trends: [Trend]) async throws {
        saveTrendDataCallCount += 1
        if shouldThrowOnSave {
            throw errorToThrow
        }
        lastSavedTrends = trends
        trendsToReturn = trends
    }

    func loadHistoricalRates(from _: Date, to _: Date) async throws -> [HistoricalRateSnapshot] {
        loadHistoricalRatesCallCount += 1
        return historicalWindowData
    }
}
