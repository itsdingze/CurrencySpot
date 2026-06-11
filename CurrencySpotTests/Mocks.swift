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

    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse {
        fetchHistoricalRatesCalls.append((from: startDate, to: endDate))
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
    var fetchExchangeRatesResult: Result<[ExchangeRateDataValue], AppError> = .success([
        ExchangeRateDataValue(currencyCode: "USD", rate: 1.0),
        ExchangeRateDataValue(currencyCode: "EUR", rate: 0.9),
    ])
    var loadExchangeRatesResult: Result<[ExchangeRateDataValue], AppError> = .success([])

    private(set) var fetchExchangeRatesCallCount = 0
    private(set) var loadExchangeRatesCallCount = 0
    private(set) var stampedFetchDate: Date?

    func shouldRefreshRates() async -> Bool {
        shouldRefreshRatesResult
    }

    func fetchExchangeRates() async throws -> [ExchangeRateDataValue] {
        fetchExchangeRatesCallCount += 1
        let rates = try fetchExchangeRatesResult.get()
        stampedFetchDate = Date()
        return rates
    }

    func loadExchangeRates() async throws -> [ExchangeRateDataValue] {
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
    var historicalDataToReturn: [HistoricalRateDataValue] = []
    var shouldThrowErrorOnFetch = false
    var shouldThrowErrorOnLoad = false
    var errorToThrow: Error = AppError.networkError("Mock error")

    private(set) var fetchAndSaveHistoricalRatesCalls: [(from: Date, to: Date)] = []
    private(set) var loadHistoricalRatesCallCount = 0
    private(set) var cachedData: [CurrencyCode: [HistoricalRateDataValue]] = [:]
    private(set) var replaceCachedCallCount = 0
    private(set) var cachedReadCount = 0

    var fetchAndSaveHistoricalRatesCallCount: Int {
        fetchAndSaveHistoricalRatesCalls.count
    }

    func seedCache(_ data: [HistoricalRateDataValue], for currency: CurrencyCode) {
        cachedData[currency] = data
    }

    func fetchAndSaveHistoricalRates(from startDate: Date, to endDate: Date) async throws {
        // Record the attempt before any throw so failed fetches remain observable.
        fetchAndSaveHistoricalRatesCalls.append((from: startDate, to: endDate))
        if shouldThrowErrorOnFetch {
            throw errorToThrow
        }
    }

    func loadHistoricalRates(for _: CurrencyCode, in _: DateRange) async throws -> [HistoricalRateDataValue] {
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

    func cachedHistoricalRates(for currency: CurrencyCode) async -> [HistoricalRateDataValue] {
        cachedReadCount += 1
        return cachedData[currency] ?? []
    }

    func replaceCachedHistoricalRates(_ data: [HistoricalRateDataValue], for currency: CurrencyCode) async {
        replaceCachedCallCount += 1
        cachedData[currency] = data
    }
}

// MARK: - MockTrendRepository

/// Configurable TrendRepository double. `saveTrendData` replaces the stored set,
/// mirroring the production replace-all semantics.
final class MockTrendRepository: TrendRepository {
    var trendsToReturn: [TrendDataValue]
    var historicalWindowData: [HistoricalRateDataValue] = []
    var shouldThrowOnLoadTrends = false
    var shouldThrowOnSave = false
    var errorToThrow: Error = AppError.unknownError("Mock trend error")

    private(set) var loadTrendDataCallCount = 0
    private(set) var saveTrendDataCallCount = 0
    private(set) var loadHistoricalRatesCallCount = 0
    private(set) var lastSavedTrends: [TrendDataValue]?

    init(trends: [TrendDataValue] = []) {
        trendsToReturn = trends
    }

    func loadTrendData() async throws -> [TrendDataValue] {
        loadTrendDataCallCount += 1
        if shouldThrowOnLoadTrends {
            throw errorToThrow
        }
        return trendsToReturn
    }

    func saveTrendData(_ trends: [TrendDataValue]) async throws {
        saveTrendDataCallCount += 1
        if shouldThrowOnSave {
            throw errorToThrow
        }
        lastSavedTrends = trends
        trendsToReturn = trends
    }

    func loadHistoricalRates(from _: Date, to _: Date) async throws -> [HistoricalRateDataValue] {
        loadHistoricalRatesCallCount += 1
        return historicalWindowData
    }
}
