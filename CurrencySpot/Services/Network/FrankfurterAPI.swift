import Foundation

nonisolated final class FrankfurterAPI: Sendable {
    private let baseURL = "https://api.frankfurter.dev/v2"

    private let urlSession: URLSession
    private let retryManager: RetryManager
    private let dateProvider: DateProvider

    init(session: URLSession = FrankfurterAPI.makeDefaultSession(), retryManager: RetryManager, dateProvider: DateProvider = SystemDateProvider()) {
        urlSession = session
        self.retryManager = retryManager
        self.dateProvider = dateProvider
    }

    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 30.0
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        return URLSession(configuration: configuration)
    }

    @concurrent
    func fetchExchangeRates(baseCurrency: String = "USD") async throws -> ExchangeRatesResponse {
        let urlString = "\(baseURL)/rates?base=\(baseCurrency)"
        let url = try NetworkRequestRunner.createURL(from: urlString)

        let entries = try await NetworkRequestRunner.performRequestWithRetry(
            url: url,
            urlSession: urlSession,
            responseType: [FrankfurterV2Rate].self,
            endpoint: "exchange-rates-latest",
            retryManager: retryManager
        )
        return try FrankfurterV2Mapper.latest(from: entries, base: baseCurrency)
    }

    func fetchHistoricalRates(baseCurrency: String = "USD", days: Int) async throws -> HistoricalRatesResponse {
        let calendar = TimeZoneManager.cetCalendar
        let today = dateProvider.now()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            throw AppError.dateCalculationError("Failed to calculate start date by subtracting \(days) days from \(today)")
        }

        return try await fetchHistoricalRatesForRange(baseCurrency: baseCurrency, startDate: startDate, endDate: today)
    }

    @concurrent
    func fetchHistoricalRatesForRange(baseCurrency: String = "USD", startDate: Date, endDate: Date, quotes: [String] = []) async throws -> HistoricalRatesResponse {
        let startDateString = TimeZoneManager.formatForAPI(startDate)
        let endDateString = TimeZoneManager.formatForAPI(endDate)

        var urlString = "\(baseURL)/rates?base=\(baseCurrency)&from=\(startDateString)&to=\(endDateString)"
        if !quotes.isEmpty {
            urlString += "&quotes=\(quotes.joined(separator: ","))"
        }
        let url = try NetworkRequestRunner.createURL(from: urlString)

        let entries = try await NetworkRequestRunner.performRequestWithRetry(
            url: url,
            urlSession: urlSession,
            responseType: [FrankfurterV2Rate].self,
            endpoint: "historical-rates-range-\(startDateString)-\(endDateString)\(quotes.isEmpty ? "" : "-" + quotes.sorted().joined(separator: "-"))",
            retryManager: retryManager
        )
        return try FrankfurterV2Mapper.historical(from: entries, base: baseCurrency)
    }
}
