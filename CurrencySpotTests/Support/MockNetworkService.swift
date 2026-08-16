@testable import CurrencySpot
import Foundation

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

    var historicalFetchBarrier: (() async -> Void)?

    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse {
        fetchHistoricalRatesCalls.append((from: startDate, to: endDate))
        await historicalFetchBarrier?()
        return try historicalRatesResult.get()
    }

    private(set) var fetchHistoricalRatesQuotesCalls: [(from: Date, to: Date, quotes: [String])] = []

    func fetchHistoricalRates(from startDate: Date, to endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse {
        fetchHistoricalRatesQuotesCalls.append((from: startDate, to: endDate, quotes: quotes))
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
