//
//  Mocks.swift
//  CurrencySpotTests
//
//  Shared test doubles consumed by multiple test files.
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
