@testable import CurrencySpot
import Foundation

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
        await Task.yield()
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
