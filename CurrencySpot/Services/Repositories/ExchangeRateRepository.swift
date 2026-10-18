import Foundation

protocol ExchangeRateRepository {
    func fetchExchangeRates() async throws -> [ExchangeRate]

    func loadExchangeRates() async throws -> [ExchangeRate]

    func lastFetchDate() -> Date?
}
