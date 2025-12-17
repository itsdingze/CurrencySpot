//
//  CalculatorViewModel.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/28/25.
//

import SwiftUI

// MARK: - CalculatorViewModel

@Observable
@MainActor
final class CalculatorViewModel {
    // MARK: - Input and Calculation Properties

    var inputAmountString = "0"

    var availableRates: [ExchangeRateDataValue] = [] {
        didSet {
            updateRatesCache()
        }
    }

    // MARK: - Currency Selection Properties

    var baseCurrency: String
    var targetCurrency: String

    // MARK: - UI State Properties

    var showCurrencyPicker = false
    var isSelectingFromCurrency = true

    // MARK: - Loading and Error State Properties

    var isLoading = true
    var errorMessage: String?
    var lastUpdated: Date?
    var isUsingMockData: Bool = false
    var retryState: RetryState = .none

    // MARK: - Private Properties

    private let service: ExchangeRateService
    private let appState = AppState.shared
    private var fetchTask: Task<Void, Never>?
    private let retryManager = RetryManager.shared
    private let exchangeRatesEndpoint = "exchange-rates-latest"

    // Performance cache for O(1) currency lookups
    private var ratesCache: [String: Double] = [:]

    // MARK: - Initialization

    /// Initializes the CalculatorViewModel with optional service injection
    /// - Parameter service: Optional exchange rate service for dependency injection
    init(service: ExchangeRateService) {
        self.service = service

        // Load user preferences for default currencies
        baseCurrency = UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultBaseCurrency) ?? "USD"
        targetCurrency = UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultTargetCurrency) ?? "EUR"

        Task {
            await checkIfShouldFetch()
        }
    }

    // MARK: - Computed Properties (Calculation Results)

    var inputAmount: Double {
        (Double(inputAmountString) ?? 0) / 100.0
    }

    var conversionRate: Double {
        guard baseCurrency != targetCurrency else { return 1.0 }

        // O(1) lookups instead of array searches
        let baseRate = ratesCache[baseCurrency] ?? 1.0
        let targetRate = ratesCache[targetCurrency] ?? 1.0

        return targetRate / baseRate
    }

    var convertedAmount: String {
        let result = inputAmount * conversionRate
        return result.formatted(.number.precision(.fractionLength(2)))
    }

    // MARK: - Computed Properties (Formatted Display Values)

    var formattedLastUpdated: String {
        guard let date = lastUpdated else { return "Not updated yet" }
        return "Last updated: \(TimeZoneManager.formatLastUpdated(date))"
    }

    // MARK: - Public Interface Methods

    /// Checks if new data should be fetched and initiates fetch or loads cached data
    func checkIfShouldFetch() async {
        let shouldFetch = await service.shouldFetchNewRates()

        if shouldFetch, appState.networkMonitor.isConnected {
            // Wait for existing task to complete instead of cancelling
            if let existingTask = fetchTask {
                _ = await existingTask.result
            }
            fetchTask = Task {
                defer { fetchTask = nil }
                await fetchExchangeRates()
            }
        } else {
            await loadExchangeRates()
        }
    }

    /// Clears all data when cache is cleared from settings
    func clearAllData() {
        availableRates = []
        lastUpdated = nil
        errorMessage = nil
        isLoading = false
        isUsingMockData = false
        retryState = .none
    }

    /// Clears cached data and initiates fresh fetch
    func resetStoredData() async {
        clearAllData()

        // Wait for existing task to complete instead of cancelling
        if let existingTask = fetchTask {
            _ = await existingTask.result
        }
        fetchTask = Task {
            defer { fetchTask = nil }
            await fetchExchangeRates()
        }
    }

    // MARK: - Data Fetching Methods

    /// Fetches fresh exchange rate data from the remote service
    func fetchExchangeRates() async {
        isLoading = true
        errorMessage = nil
        isUsingMockData = false
        updateRetryState()

        do {
            let response = try await service.fetchExchangeRates()

            // Success handling - process and update rates
            var updatedRates = response.rates
            updatedRates[response.base] = 1.0

            // Convert to value types immediately
            availableRates = updatedRates.map {
                ExchangeRateDataValue(currencyCode: $0.key, rate: $0.value)
            }
            let updateDate = Date()
            lastUpdated = updateDate
            service.updateLastFetchDate(updateDate)
            try await service.saveExchangeRates(updatedRates)

            // Reset retry state on success
            retryState = .none

        } catch {
            // Update retry state based on current attempt
            updateRetryState()

            // Error handling with fallback to cache
            if let appError = AppError.from(error) {
                errorMessage = appError.message
                appState.errorHandler.handle(appError)
            }
            // If error is nil (cancellation), don't show error message

            // Try to load from cache as fallback
            await loadExchangeRates(showErrorOnFailure: false)
        }

        isLoading = false
    }

    /// Loads exchange rate data from local cache
    /// - Parameter showErrorOnFailure: Whether to display error messages if loading fails
    private func loadExchangeRates(showErrorOnFailure: Bool = true) async {
        do {
            let valueTypeData = try await service.loadExchangeRates()

            availableRates = valueTypeData
            lastUpdated = service.getLastFetchDate()
            isLoading = false
            errorMessage = nil
            isUsingMockData = false

        } catch {
            if showErrorOnFailure, let appError = AppError.from(error) {
                errorMessage = appError.message
                appState.errorHandler.handle(appError)
            }

            if appState.networkMonitor.isConnected {
                await resetStoredData()
            } else {
                // Offline with no SwiftData - use mock data as fallback
                useMockData()
            }
        }
    }

    // MARK: - Mock Data Methods

    /// Loads mock data for testing or offline use
    func useMockData() {
        // Convert mock data to value types
        availableRates = MockExchangeRates.rates.map {
            ExchangeRateDataValue(currencyCode: $0.key, rate: $0.value)
        }
        lastUpdated = nil
        isLoading = false
        errorMessage = nil
        isUsingMockData = true
    }

    // MARK: - Cache Management Methods

    /// Updates the rates cache for O(1) currency lookups
    private func updateRatesCache() {
        // Build dictionary for O(1) lookups using value types
        ratesCache = availableRates.reduce(into: [:]) { dict, rate in
            dict[rate.currencyCode] = rate.rate
        }
    }

    // MARK: - Retry State Management

    /// Updates the retry state based on the current retry manager state
    private func updateRetryState() {
        let currentAttempt = retryManager.getCurrentAttempt(for: exchangeRatesEndpoint)
        let canRetry = retryManager.canRetry(for: exchangeRatesEndpoint)

        if currentAttempt > 0, canRetry {
            // Currently retrying
            retryState = .retrying(attempt: currentAttempt, maxAttempts: 3)
        } else if currentAttempt > 0, !canRetry {
            // Exhausted retries
            retryState = .exhausted
        } else {
            // No retries or reset state
            retryState = .none
        }
    }
}
