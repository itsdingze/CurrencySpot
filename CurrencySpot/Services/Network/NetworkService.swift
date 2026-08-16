import Foundation

// MARK: - NetworkService Protocol

protocol NetworkService {
    func shouldFetchNewRates() async -> Bool

    func fetchExchangeRates() async throws -> ExchangeRatesResponse

    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse

    func fetchHistoricalRates(from startDate: Date, to endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse

    func updateLastFetchDate(_ date: Date)

    func getLastFetchDate() -> Date?
}

// MARK: - NetworkService Implementation

final class FrankfurterNetworkService: NetworkService {
    // MARK: - Constants

    private let lastFetchDateKey = UserDefaultsKeys.lastFetchDate

    // MARK: - Dependencies

    private let api: FrankfurterAPI
    private let userDefaults: UserDefaults
    private let dateProvider: DateProvider

    // MARK: - Initialization

    init(api: FrankfurterAPI, userDefaults: UserDefaults = .standard, dateProvider: DateProvider = SystemDateProvider()) {
        self.api = api
        self.userDefaults = userDefaults
        self.dateProvider = dateProvider
    }

    // MARK: - Rate Fetching Check Methods

    func shouldFetchNewRates() async -> Bool {
        RateRefreshPolicy.shouldRefetch(now: dateProvider.now(), lastFetch: getLastFetchDate())
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

    // MARK: - Date Management Methods

    func updateLastFetchDate(_ date: Date) {
        userDefaults.set(date, forKey: lastFetchDateKey)
    }

    func getLastFetchDate() -> Date? {
        userDefaults.object(forKey: lastFetchDateKey) as? Date
    }
}
