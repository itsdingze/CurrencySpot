//
//  FrankFurtherAPI.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/24/25.
//

import Foundation

struct ExchangeRatesResponse: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}

struct HistoricalRatesResponse: Codable {
    let base: String
    let start_date: String
    let end_date: String
    let rates: [String: [String: Double]]
}

/// Client for interacting with the Frankfurter exchange rate API
/// Provides methods to fetch current and historical exchange rates
class FrankfurterAPI {
    /// Singleton instance for app-wide access
    static let shared = FrankfurterAPI()

    private let baseURL = "https://api.frankfurter.dev/v1"

    /// Custom URLSession with appropriate timeout configuration
    private let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0 // 10 seconds
        configuration.timeoutIntervalForResource = 30.0 // 30 seconds
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        return URLSession(configuration: configuration)
    }()

    /// Fetches the latest exchange rates from the Frankfurter API
    ///
    /// - Parameter baseCurrency: The reference currency for exchange rates (default: "USD")
    /// - Returns: A ExchangeRatesResponse object that contains the latest exchange rates
    /// - Throws: AppError if network request fails, API returns an error status, or response cannot be decoded
    func fetchExchangeRates(baseCurrency: String = "USD") async throws -> ExchangeRatesResponse {
        let urlString = "\(baseURL)/latest?base=\(baseCurrency)"
        let url = try NetworkUtility.createURL(from: urlString)

        return try await NetworkUtility.performRequestWithRetry(
            url: url,
            urlSession: urlSession,
            responseType: ExchangeRatesResponse.self,
            endpoint: "exchange-rates-latest"
        )
    }

    /// Fetches historical exchange rates for a specified number of days in the past
    ///
    /// - Parameters:
    ///   - baseCurrency: The reference currency for exchange rates (default: "USD")
    ///   - days: Number of days of historical data to retrieve
    /// - Returns: A HistoricalRatesResponse object that contains the historical exchange rates
    /// - Throws: AppError if date calculation fails, network request fails, or response cannot be decoded
    func fetchHistoricalRates(baseCurrency: String = "USD", days: Int) async throws -> HistoricalRatesResponse {
        // Calculate date 'days' ago
        let calendar = TimeZoneManager.cetCalendar
        let today = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            throw AppError.dateCalculationError("Failed to calculate start date by subtracting \(days) days from \(today)")
        }

        // Format dates and build URL
        let startDateString = TimeZoneManager.formatForAPI(startDate)
        let endDateString = TimeZoneManager.formatForAPI(today)

        let urlString = "\(baseURL)/\(startDateString)..\(endDateString)?base=\(baseCurrency)"
        let url = try NetworkUtility.createURL(from: urlString)

        return try await NetworkUtility.performRequestWithRetry(
            url: url,
            urlSession: urlSession,
            responseType: HistoricalRatesResponse.self,
            endpoint: "historical-rates-days"
        )
    }

    /// Fetches historical exchange rates for a specified date range
    ///
    /// - Parameters:
    ///   - baseCurrency: The reference currency for exchange rates (default: "USD")
    ///   - startDate: The start date for historical data
    ///   - endDate: The end date for historical data
    /// - Returns: A HistoricalRatesResponse object that contains the historical exchange rates
    /// - Throws: AppError if network request fails, or response cannot be decoded
    func fetchHistoricalRatesForRange(baseCurrency: String = "USD", startDate: Date, endDate: Date) async throws -> HistoricalRatesResponse {
        // Format dates and build URL
        let startDateString = TimeZoneManager.formatForAPI(startDate)
        let endDateString = TimeZoneManager.formatForAPI(endDate)

        let urlString = "\(baseURL)/\(startDateString)..\(endDateString)?base=\(baseCurrency)"
        let url = try NetworkUtility.createURL(from: urlString)

        return try await NetworkUtility.performRequestWithRetry(
            url: url,
            urlSession: urlSession,
            responseType: HistoricalRatesResponse.self,
            endpoint: "historical-rates-range"
        )
    }
}
