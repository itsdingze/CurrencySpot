import Foundation

protocol ExchangeRateRepository {
    func shouldRefreshRates() async -> Bool

    func fetchExchangeRates() async throws -> [ExchangeRate]

    func loadExchangeRates() async throws -> [ExchangeRate]

    func lastFetchDate() -> Date?
}
