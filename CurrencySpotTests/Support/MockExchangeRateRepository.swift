@testable import CurrencySpot
import Foundation

final class MockExchangeRateRepository: ExchangeRateRepository {
    static let now = Date(timeIntervalSince1970: 1_750_000_000)

    var fetchExchangeRatesResult: Result<[ExchangeRate], AppError> = .success([
        ExchangeRate(currencyCode: "USD", rate: 1.0),
        ExchangeRate(currencyCode: "EUR", rate: 0.9),
    ])
    var loadExchangeRatesResult: Result<[ExchangeRate], AppError> = .success([])

    private(set) var fetchExchangeRatesCallCount = 0
    private(set) var loadExchangeRatesCallCount = 0
    private var lastFetch: Date? = MockExchangeRateRepository.now

    var ratesAreStale: Bool {
        get { lastFetch == nil }
        set { lastFetch = newValue ? nil : Self.now }
    }

    func fetchExchangeRates() async throws -> [ExchangeRate] {
        await Task.yield()
        fetchExchangeRatesCallCount += 1
        let rates = try fetchExchangeRatesResult.get()
        lastFetch = Self.now
        return rates
    }

    func loadExchangeRates() async throws -> [ExchangeRate] {
        loadExchangeRatesCallCount += 1
        return try loadExchangeRatesResult.get()
    }

    func lastFetchDate() -> Date? {
        lastFetch
    }
}
