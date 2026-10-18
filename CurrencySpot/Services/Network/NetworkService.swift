import Foundation

// MARK: - NetworkService Protocol

protocol NetworkService {
    func fetchExchangeRates() async throws -> ExchangeRatesResponse

    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse

    func fetchHistoricalRates(from startDate: Date, to endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse
}

// MARK: - NetworkService Implementation

final class FrankfurterNetworkService: NetworkService {
    // MARK: - Dependencies

    private let api: FrankfurterAPI

    // MARK: - Initialization

    init(api: FrankfurterAPI) {
        self.api = api
    }

    // MARK: - Network Data Fetching Methods

    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        try await api.fetchExchangeRates()
    }

    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse {
        try await api.fetchHistoricalRatesForRange(
            startDate: startDate,
            endDate: endDate
        )
    }

    func fetchHistoricalRates(from startDate: Date, to endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse {
        try await api.fetchHistoricalRatesForRange(
            startDate: startDate,
            endDate: endDate,
            quotes: quotes
        )
    }
}
