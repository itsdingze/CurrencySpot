import Foundation

nonisolated final class FrankfurterAPI: Sendable {
    private let ratesEndpoint = "https://api.frankfurter.dev/v2/rates"

    private let urlSession: URLSession
    private let retryPolicy: RetryPolicy
    private let clock: ClockService

    init(session: URLSession, retryPolicy: RetryPolicy, clock: ClockService) {
        urlSession = session
        self.retryPolicy = retryPolicy
        self.clock = clock
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
        let url = try ratesURL([URLQueryItem(name: "base", value: baseCurrency)])

        let entries = try await NetworkRequestRunner.performRequestWithRetry(
            url: url,
            urlSession: urlSession,
            responseType: [FrankfurterV2Rate].self,
            endpoint: "exchange-rates-latest",
            retryPolicy: retryPolicy,
            clock: clock
        )
        return try FrankfurterV2Mapper.latest(from: entries, base: baseCurrency)
    }

    @concurrent
    func fetchHistoricalRatesForRange(baseCurrency: String = "USD", startDate: Date, endDate: Date, quotes: [String] = []) async throws -> HistoricalRatesResponse {
        let startDateString = CETCalendar.dayString(for: startDate)
        let endDateString = CETCalendar.dayString(for: endDate)

        var queryItems = [
            URLQueryItem(name: "base", value: baseCurrency),
            URLQueryItem(name: "from", value: startDateString),
            URLQueryItem(name: "to", value: endDateString),
        ]
        if !quotes.isEmpty {
            queryItems.append(URLQueryItem(name: "quotes", value: quotes.joined(separator: ",")))
        }
        let url = try ratesURL(queryItems)

        let entries = try await NetworkRequestRunner.performRequestWithRetry(
            url: url,
            urlSession: urlSession,
            responseType: [FrankfurterV2Rate].self,
            endpoint: "historical-rates-range-\(startDateString)-\(endDateString)\(quotes.isEmpty ? "" : "-" + quotes.sorted().joined(separator: "-"))",
            retryPolicy: retryPolicy,
            clock: clock
        )
        return try FrankfurterV2Mapper.historical(from: entries, base: baseCurrency)
    }

    private func ratesURL(_ queryItems: [URLQueryItem]) throws -> URL {
        try NetworkRequestRunner.createURL(from: ratesEndpoint).appending(queryItems: queryItems)
    }
}
