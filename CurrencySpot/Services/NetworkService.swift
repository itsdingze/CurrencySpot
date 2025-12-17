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
    private let updateHourCET = 17
    private let updateMinuteCET = 0

    // MARK: - Initialization

    init() {}

    // MARK: - Rate Fetching Check Methods

    /// Determines whether new exchange rates should be fetched from the API.
    ///
    /// This method implements complex logic to respect the Frankfurter API's update schedule:
    /// - Rates update daily at 17:00 CET
    /// - No updates occur on weekends
    /// - Friday's rates (fetched after 17:00 CET) remain valid throughout the weekend
    ///
    /// - Returns: `true` if new rates should be fetched, `false` otherwise
    func shouldFetchNewRates() async -> Bool {
        guard let lastFetchDate = getLastFetchDate() else {
            return true // If we never fetched, we should fetch
        }

        // Get current date in CET
        let now = Date()
        let calendar = TimeZoneManager.cetCalendar

        // Determine if same day
        let isSameDay = calendar.isDate(lastFetchDate, inSameDayAs: now)

        // Calculate today's update time
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        todayComponents.hour = updateHourCET
        todayComponents.minute = updateMinuteCET
        guard let todayUpdateTime = calendar.date(from: todayComponents) else {
            return true
        }

        // If same day, only fetch if crossing the update time threshold
        if isSameDay {
            return lastFetchDate < todayUpdateTime && now >= todayUpdateTime
        }

        // Different day - check weekend/Friday scenarios
        let lastFetchWeekday = calendar.component(.weekday, from: lastFetchDate)
        let currentWeekday = calendar.component(.weekday, from: now)

        // Create last fetch day's update time
        var lastFetchComponents = calendar.dateComponents([.year, .month, .day], from: lastFetchDate)
        lastFetchComponents.hour = updateHourCET
        lastFetchComponents.minute = updateMinuteCET
        guard let lastFetchDayUpdateTime = calendar.date(from: lastFetchComponents) else {
            return true
        }

        // Check if Friday after update to weekend scenario
        let wasLastFetchFriday = lastFetchWeekday == 6 // Friday
        let wasLastFetchAfterUpdate = lastFetchDate >= lastFetchDayUpdateTime
        let isTodayWeekend = currentWeekday == 1 || currentWeekday == 7 // Sunday or Saturday

        // Check if it's the same week
        let lastFetchWeekOfYear = calendar.component(.weekOfYear, from: lastFetchDate)
        let currentWeekOfYear = calendar.component(.weekOfYear, from: now)
        let isSameWeek = lastFetchWeekOfYear == currentWeekOfYear &&
            calendar.component(.year, from: lastFetchDate) == calendar.component(.year, from: now)

        // Friday after update → weekend in the same week: don't fetch
        if wasLastFetchFriday, wasLastFetchAfterUpdate, isTodayWeekend, isSameWeek {
            return false
        }

        // All other cases: fetch
        return true
    }

    // MARK: - Network Data Fetching Methods

    /// Fetches the latest exchange rates from the Frankfurter API
    ///
    /// - Returns: A FrankfurterResponse containing the latest exchange rates
    /// - Throws: Any error that might occur during the API request
    func fetchExchangeRates() async throws -> ExchangeRatesResponse {
        let response = try await FrankfurterAPI.shared.fetchExchangeRates()

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
        try await FrankfurterAPI.shared.fetchHistoricalRatesForRange(
            startDate: startDate,
            endDate: endDate
        )
    }

    // MARK: - Date Management Methods

    func updateLastFetchDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastFetchDateKey)
    }

    func getLastFetchDate() -> Date? {
        UserDefaults.standard.object(forKey: lastFetchDateKey) as? Date
    }
}
