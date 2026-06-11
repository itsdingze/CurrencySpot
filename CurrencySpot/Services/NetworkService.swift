//
//  NetworkService.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/31/25.
//

import Foundation

// MARK: - NetworkService Protocol

protocol NetworkService {
    /// Determines whether new exchange rates should be fetched from the API
    func shouldFetchNewRates() async -> Bool

    /// Fetches the latest exchange rates from the API
    func fetchExchangeRates() async throws -> ExchangeRatesResponse

    /// Fetches historical rates for a specific date range
    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse

    /// Updates the last fetch date
    func updateLastFetchDate(_ date: Date)

    /// Gets the last fetch date
    func getLastFetchDate() -> Date?
}

// MARK: - NetworkService Implementation

final class FrankfurterNetworkService: NetworkService {
    // MARK: - Constants

    private let lastFetchDateKey = UserDefaultsKeys.lastFetchDate

    // MARK: - Dependencies

    private let api: FrankfurterAPI
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    /// Defaults preserve production behavior; tests inject a stubbed API client
    /// and an isolated `UserDefaults` so they never touch the live network or `.standard`.
    init(api: FrankfurterAPI = .shared, userDefaults: UserDefaults = .standard) {
        self.api = api
        self.userDefaults = userDefaults
    }

    // MARK: - Rate Fetching Check Methods

    /// Determines whether new exchange rates should be fetched from the API.
    ///
    /// - Returns: `true` if cached rates are older than the freshness window, `false` otherwise.
    func shouldFetchNewRates() async -> Bool {
        RateRefreshPolicy.shouldRefetch(now: Date(), lastFetch: getLastFetchDate())
    }

    // MARK: - Network Data Fetching Methods

    /// Fetches the latest exchange rates from the Frankfurter API
    ///
    /// - Returns: A FrankfurterResponse containing the latest exchange rates
    /// - Throws: Any error that might occur during the API request
    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        let response = try await api.fetchExchangeRates()

        // Update the last fetch date after successful fetch
        updateLastFetchDate(Date())

        return response
    }

    /// Fetches historical rates for a specific date range
    ///
    /// - Parameters:
    ///   - startDate: The start date for historical data
    ///   - endDate: The end date for historical data
    /// - Returns: A HistoricalRatesResponse containing the historical exchange rates
    /// - Throws: Any error that might occur during the API request
    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse {
        try await api.fetchHistoricalRatesForRange(
            startDate: startDate,
            endDate: endDate
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
