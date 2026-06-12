//
//  CalculatorViewModel.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 2/28/25.
//

import SwiftUI

// MARK: - CalculatorViewModel

@Observable
final class CalculatorViewModel {
    /// Mutually exclusive presentations over the calculator.
    nonisolated enum Destination: Identifiable, Hashable {
        case basePicker
        case targetPicker

        var id: Self { self }
    }

    // MARK: - Input and Calculation Properties

    var inputAmountString = "0"

    private let maxInputLength = 15

    /// Currently displayed rates. Published through the shared store (single writer);
    /// the setter exists for state resets and tests.
    var availableRates: [ExchangeRate] {
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

    var destination: Destination?

    // MARK: - Loading and Error State Properties

    /// Lifecycle of the rate load. The rates themselves live in the shared
    /// `ExchangeRatesStore`; this tracks the async phase the UI renders.
    private(set) var loadState: Loadable<[ExchangeRate]> = .idle

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
    private let retryManager: RetryManager
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
        retryManager: RetryManager = .shared,
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.repository = repository
        self.ratesStore = ratesStore
        self.appState = appState
        self.retryManager = retryManager
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

    // MARK: - Input Intents

    /// Appends a digit to the implied-cents input string.
    /// - Returns: `false` when the input is already at its maximum length.
    @discardableResult
    func appendDigit(_ digit: String) -> Bool {
        guard inputAmountString.count < maxInputLength || inputAmountString == "0" else {
            return false
        }
        inputAmountString = inputAmountString == "0" ? digit : inputAmountString + digit
        return true
    }

    func clearInput() {
        inputAmountString = "0"
    }

    func deleteLastDigit() {
        inputAmountString = inputAmountString.count > 1 ? String(inputAmountString.dropLast()) : "0"
    }

    // MARK: - Currency Pair Intents

    func swapCurrencies() {
        (baseCurrency, targetCurrency) = (targetCurrency, baseCurrency)
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
        loadState = .loaded([])
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
        loadState = .loading(previous: loadState.value)
        publish(rates: availableRates, lastUpdated: lastUpdated, isUsingMockData: false)
        await updateRetryState()

        do {
            let rates = try await repository.fetchExchangeRates()
            publish(rates: rates, lastUpdated: repository.lastFetchDate(), isUsingMockData: false)

            // Reset retry state on success
            retryState = .none
            loadState = .loaded(rates)

        } catch {
            // Update retry state based on current attempt
            await updateRetryState()

            // A nil AppError means cancellation — nothing to surface.
            let fetchError = AppError.from(error)
            if let fetchError {
                appState.errorHandler.handle(fetchError)
            }

            // Try to load from cache as fallback; if that also fails (online),
            // the fetch error is what surfaces.
            await loadExchangeRates(surfacing: fetchError, reportCacheError: false)
        }
    }

    /// Loads exchange rate data from local cache.
    /// - Parameters:
    ///   - pendingError: A prior fetch error that should surface if the cache
    ///     cannot provide a fallback (the fetch-failure path).
    ///   - reportCacheError: Whether a cache failure itself is surfaced
    ///     (the cache-first path).
    private func loadExchangeRates(surfacing pendingError: AppError? = nil, reportCacheError: Bool = true) async {
        do {
            let rates = try await repository.loadExchangeRates()
            publish(rates: rates, lastUpdated: repository.lastFetchDate(), isUsingMockData: false)
            loadState = .loaded(rates)

        } catch {
            let cacheError = AppError.from(error)
            if reportCacheError, let cacheError {
                appState.errorHandler.handle(cacheError)
            }

            if appState.networkMonitor.isConnected {
                // Online but no usable data: keep the error state. Calling back into
                // a fetch here would re-enter the pipeline that just failed (and
                // previously self-deadlocked awaiting its own fetchTask).
                if let surfacedError = pendingError ?? (reportCacheError ? cacheError : nil) {
                    loadState = .failed(surfacedError, previous: loadState.value)
                } else {
                    // Cancellation: end the loading phase without an error.
                    loadState = .loaded(availableRates)
                }
            } else {
                // Offline with no SwiftData - use mock data as fallback
                useMockData()
            }
        }
    }

    // MARK: - Mock Data Methods

    /// Loads mock data for testing or offline use
    func useMockData() {
        let rates = MockExchangeRates.getCurrencyRates()
        publish(rates: rates, lastUpdated: nil, isUsingMockData: true)
        loadState = .loaded(rates)
    }

    // MARK: - Rates Publishing

    /// Single funnel for rate state changes: updates the shared store and the cross-rate table.
    private func publish(rates: [ExchangeRate], lastUpdated: Date?, isUsingMockData: Bool) {
        ratesStore.update(rates: rates, lastUpdated: lastUpdated, isUsingMockData: isUsingMockData)
        rateTable = RateTable(rates)
    }

    /// Rates-only update preserving the store's other fields (setter/tests path).
    private func publishRates(_ rates: [ExchangeRate]) {
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
