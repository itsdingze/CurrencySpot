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

    /// Currently displayed rates. Published through the shared store (single writer);
    /// the setter exists for state resets and tests.
    var availableRates: [ExchangeRateDataValue] {
        get { ratesStore.rates }
        set { publishRates(newValue) }
    }

    // MARK: - Currency Selection Properties

    /// User-facing selections stay String at the UI edge (documented boundary);
    /// they cross into domain math via CurrencyCode where needed.
    var baseCurrency: String {
        didSet { ratesStore.updateBaseCurrency(baseCurrency) }
    }

    var targetCurrency: String

    // MARK: - UI State Properties

    var showCurrencyPicker = false
    var isSelectingFromCurrency = true

    // MARK: - Loading and Error State Properties

    var isLoading = true
    var errorMessage: String?
    var retryState: RetryState = .none

    var lastUpdated: Date? { ratesStore.lastUpdated }
    var isUsingMockData: Bool { ratesStore.isUsingMockData }

    // MARK: - Private Properties

    private let repository: ExchangeRateRepository
    private let ratesStore: ExchangeRatesStore
    private let appState: AppState
    private let logger: LoggerService
    private var fetchTask: Task<Void, Never>?
    private var fetchGeneration = 0
    private let retryManager = RetryManager.shared
    private let exchangeRatesEndpoint = "exchange-rates-latest"

    // Cross-rate table for O(1) currency lookups
    private var rateTable: RateTable = .empty

    // MARK: - Initialization

    /// Initializes the CalculatorViewModel with injected dependencies.
    /// Defaults preserve production behavior; tests inject an isolated `AppState`
    /// (for connectivity control) and `UserDefaults` (for preference isolation).
    init(
        repository: ExchangeRateRepository,
        ratesStore: ExchangeRatesStore,
        appState: AppState = .shared,
        userDefaults: UserDefaults = .standard,
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.repository = repository
        self.ratesStore = ratesStore
        self.appState = appState
        self.logger = logger

        // Load user preferences for default currencies
        baseCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultBaseCurrency) ?? "USD"
        targetCurrency = userDefaults.string(forKey: UserDefaultsKeys.defaultTargetCurrency) ?? "EUR"
        ratesStore.updateBaseCurrency(baseCurrency)
        // CalculatorView's `.task` calls checkIfShouldFetch() on appear; that is the single kickoff.
    }

    // MARK: - Computed Properties (Calculation Results)

    var inputAmount: Double {
        (Double(inputAmountString) ?? 0) / 100.0
    }

    var conversionRate: Double {
        guard let base = CurrencyCode(baseCurrency), let target = CurrencyCode(targetCurrency) else {
            return 1.0
        }
        return rateTable.crossRate(from: base, to: target)
    }

    var convertedAmount: String {
        let result = inputAmount * conversionRate
        return result.formatted(.number.precision(.fractionLength(2)))
    }

    // MARK: - Computed Properties (Formatted Display Values)

    var formattedLastUpdated: String {
        ratesStore.formattedLastUpdated
    }

    // MARK: - Public Interface Methods

    /// Checks if new data should be fetched and initiates fetch or loads cached data
    func checkIfShouldFetch() async {
        // Wait for any in-flight fetch first, then re-evaluate freshness: the
        // completed fetch may have made a second fetch unnecessary.
        if let existingTask = fetchTask {
            _ = await existingTask.result
        }

        let shouldFetch = await repository.shouldRefreshRates()

        if shouldFetch, appState.networkMonitor.isConnected {
            startFetchTask()
        } else {
            await loadExchangeRates()
        }
    }

    /// Applies a pending conversion request (e.g. from the camera's "open in
    /// converter") and consumes it so it cannot re-apply.
    func consumePendingConversion() {
        guard let pending = appState.pendingConversion else { return }
        appState.pendingConversion = nil
        baseCurrency = pending.baseCurrency
        targetCurrency = pending.targetCurrency
        inputAmountString = pending.amountInput
    }

    /// Clears all data when cache is cleared from settings
    func clearAllData() {
        publish(rates: [], lastUpdated: nil, isUsingMockData: false)
        errorMessage = nil
        isLoading = false
        retryState = .none
    }

    /// Clears cached data and initiates fresh fetch
    func resetStoredData() async {
        clearAllData()

        // Wait for existing task to complete instead of cancelling
        if let existingTask = fetchTask {
            _ = await existingTask.result
        }
        startFetchTask()
    }

    /// Single place that assigns `fetchTask`, so a finishing task can only clear
    /// the handle if it is still the current one (generation check).
    private func startFetchTask() {
        fetchGeneration += 1
        let generation = fetchGeneration
        fetchTask = Task {
            await fetchExchangeRates()
            if generation == fetchGeneration {
                fetchTask = nil
            }
        }
    }

    // MARK: - Data Fetching Methods

    /// Fetches fresh exchange rate data through the repository, which owns all
    /// post-fetch bookkeeping (persist, cache, last-fetch stamp).
    func fetchExchangeRates() async {
        isLoading = true
        errorMessage = nil
        publish(rates: availableRates, lastUpdated: lastUpdated, isUsingMockData: false)
        await updateRetryState()

        do {
            let rates = try await repository.fetchExchangeRates()
            publish(rates: rates, lastUpdated: repository.lastFetchDate(), isUsingMockData: false)

            // Reset retry state on success
            retryState = .none

        } catch {
            // Update retry state based on current attempt
            await updateRetryState()

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
            let rates = try await repository.loadExchangeRates()
            publish(rates: rates, lastUpdated: repository.lastFetchDate(), isUsingMockData: false)
            isLoading = false
            errorMessage = nil

        } catch {
            if showErrorOnFailure, let appError = AppError.from(error) {
                errorMessage = appError.message
                appState.errorHandler.handle(appError)
            }

            if appState.networkMonitor.isConnected {
                // Online but no usable data: keep the error state. Calling back into
                // a fetch here would re-enter the pipeline that just failed (and
                // previously self-deadlocked awaiting its own fetchTask).
                isLoading = false
            } else {
                // Offline with no SwiftData - use mock data as fallback
                useMockData()
            }
        }
    }

    // MARK: - Mock Data Methods

    /// Loads mock data for testing or offline use
    func useMockData() {
        publish(rates: MockExchangeRates.getCurrencyRates(), lastUpdated: nil, isUsingMockData: true)
        isLoading = false
        errorMessage = nil
    }

    // MARK: - Rates Publishing

    /// Single funnel for rate state changes: updates the shared store and the cross-rate table.
    private func publish(rates: [ExchangeRateDataValue], lastUpdated: Date?, isUsingMockData: Bool) {
        ratesStore.update(rates: rates, lastUpdated: lastUpdated, isUsingMockData: isUsingMockData)
        rateTable = RateTable(rates)
    }

    /// Rates-only update preserving the store's other fields (setter/tests path).
    private func publishRates(_ rates: [ExchangeRateDataValue]) {
        publish(rates: rates, lastUpdated: ratesStore.lastUpdated, isUsingMockData: ratesStore.isUsingMockData)
    }

    // MARK: - Retry State Management

    /// Updates the retry state based on the current retry manager state
    private func updateRetryState() async {
        let currentAttempt = await retryManager.getCurrentAttempt(for: exchangeRatesEndpoint)
        let canRetry = await retryManager.canRetry(for: exchangeRatesEndpoint)

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
