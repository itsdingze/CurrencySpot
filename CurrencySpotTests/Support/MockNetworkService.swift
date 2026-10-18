@testable import CurrencySpot
import Foundation

final class MockNetworkService: NetworkService {
    var exchangeRatesResult: Result<ExchangeRatesResponse, Error> =
        .failure(AppError.networkError("MockNetworkService: no exchange rates stubbed"))
    var historicalRatesResult: Result<HistoricalRatesResponse, Error> =
        .failure(AppError.networkError("MockNetworkService: no historical rates stubbed"))
    var historicalRatesProvider: ((Date, Date) -> HistoricalRatesResponse)?

    private(set) var fetchExchangeRatesCallCount = 0
    private(set) var fetchHistoricalRatesCalls: [(from: Date, to: Date)] = []
    private(set) var cancelledHistoricalFetchCount = 0

    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        fetchExchangeRatesCallCount += 1
        return try exchangeRatesResult.get()
    }

    var historicalFetchBarrier: (() async -> Void)?

    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse {
        fetchHistoricalRatesCalls.append((from: startDate, to: endDate))
        await historicalFetchBarrier?()
        if Task.isCancelled {
            cancelledHistoricalFetchCount += 1
            throw CancellationError()
        }
        if let historicalRatesProvider {
            return historicalRatesProvider(startDate, endDate)
        }
        return try historicalRatesResult.get()
    }

    private(set) var fetchHistoricalRatesQuotesCalls: [(from: Date, to: Date, quotes: [String])] = []

    func fetchHistoricalRates(from startDate: Date, to endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse {
        fetchHistoricalRatesQuotesCalls.append((from: startDate, to: endDate, quotes: quotes))
        await historicalFetchBarrier?()
        return try historicalRatesResult.get()
    }
}
