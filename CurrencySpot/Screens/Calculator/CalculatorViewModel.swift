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

    /// True when the rates on screen are saved rates kept after a live refresh failed
    /// (as opposed to simply being offline, or up to date). Drives the "couldn't update"
    /// banner; reset the moment a fetch succeeds.
    private(set) var lastRefreshFailed = false

    var lastUpdated: Date? { ratesStore.lastUpdated }
    var isUsingMockData: Bool { ratesStore.isUsingMockData }

    /// Single source of truth for the status strip above the calculator, derived so it
    /// can never disagree with the load phase: while a refresh runs over existing rates
    /// it reads `.updating`; with nothing to show it is `.hidden` and the screen itself
    /// (spinner or error view) carries the state.
    var rateBanner: RateBanner {
        if loadState.isLoading, loadState.value?.isEmpty == false { return .updating }
        guard loadState.value?.isEmpty == false else { return .hidden }
        if isUsingMockData { return .sample }
        if !appState.networkMonitor.isConnected { return .offlineSaved }
        if lastRefreshFailed { return .updateFailed }
        return .hidden
    }

    /// Retry is offered only when we're online and the last refresh failed. Offline,
    /// reconnecting refreshes automatically, so there's nothing to retry.
    var canRetryRates: Bool {
        appState.networkMonitor.isConnected && lastRefreshFailed
    }

    // MARK: - Private Properties

    private let repository: ExchangeRateRepository
    private let ratesStore: ExchangeRatesStore
    private let appState: AppState
    private let logger: LoggerService
    private var fetchTask: Task<Void, Never>?
    private var fetchGeneration = 0

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
            // A concurrent caller may have started a fetch while this one was
            // suspended above; joining it instead keeps fetches single-flight.
            guard fetchTask == nil else { return }
            startFetchTask()
        } else {
            await loadExchangeRates()
        }
    }

    /// Retry/refresh intent for the error and offline banners. Synchronous on
    /// the main actor, so a tap during an in-flight fetch is an atomic no-op
    /// instead of a second concurrent fetch.
    func retryFetch() {
        guard fetchTask == nil else { return }
        startFetchTask()
    }

    /// Connectivity was restored. Pulls fresh rates unless we already have current, live
    /// ones — so the offline / sample / "couldn't update" banner clears on its own, and a
    /// no-rates error screen advances to the loading view automatically.
    func handleReconnect() async {
        guard fetchTask == nil else { return }
        // Nothing real on screen, or showing sample / saved-after-failed-refresh rates:
        // pull fresh ones now.
        if loadState.value == nil || isUsingMockData || lastRefreshFailed {
            startFetchTask()
            return
        }
        // Otherwise we already have real saved rates — only refetch if they've gone stale.
        if await repository.shouldRefreshRates() {
            startFetchTask()
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

    /// Clears published state when Settings' "Refresh All Data" wipes the store
    func clearAllData() {
        publish(rates: [], lastUpdated: nil, isUsingMockData: false)
        loadState = .loaded([])
        lastRefreshFailed = false
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
        // Note: don't clear isUsingMockData here. If this refresh fails and we fall back
        // to the rates already on screen, sample rates must stay flagged as sample rather
        // than be mislabeled "saved rates". A successful fetch publishes the real flag.
        loadState = .loading(previous: loadState.value)

        do {
            let rates = try await repository.fetchExchangeRates()
            publish(rates: rates, lastUpdated: repository.lastFetchDate(), isUsingMockData: false)
            lastRefreshFailed = false
            loadState = .loaded(rates)

        } catch {
            // Live fetch failed. Fall back to saved rates; loadExchangeRates decides
            // between showing them under a "couldn't update" banner or, if there are
            // none, surfacing the error screen. A nil AppError means cancellation.
            await loadExchangeRates(surfacing: AppError.from(error))
        }
    }

    /// Loads current rates from local storage (cache, then persistence).
    ///
    /// - Parameter pendingError: the fetch error that drove us here, when this is the
    ///   fallback after a failed live refresh. If saved rates load, its presence marks
    ///   them as "couldn't update"; if they don't, it's what the error screen shows.
    ///   Sample rates are never substituted automatically — that's an explicit choice on
    ///   the error screen (`useMockData`).
    private func loadExchangeRates(surfacing pendingError: AppError? = nil) async {
        do {
            let rates = try await repository.loadExchangeRates()
            publish(rates: rates, lastUpdated: repository.lastFetchDate(), isUsingMockData: false)
            lastRefreshFailed = (pendingError != nil)
            loadState = .loaded(rates)

        } catch {
            // No saved rates to fall back to. Keep whatever is already on screen if we
            // have it; otherwise surface the error screen so the user can retry or
            // switch to sample rates.
            if let shown = loadState.value {
                lastRefreshFailed = true
                loadState = .loaded(shown)
            } else if let surfaced = pendingError ?? AppError.from(error) {
                loadState = .failed(surfaced, previous: nil)
            } else {
                loadState = .loaded([]) // cancellation: nothing to surface
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
}
