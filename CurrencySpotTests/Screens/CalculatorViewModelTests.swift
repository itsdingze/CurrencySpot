//
//  CalculatorViewModelTests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("CalculatorViewModel Tests")
@MainActor
struct CalculatorViewModelTests {
    private let repository = MockExchangeRateRepository()
    private let ratesStore = ExchangeRatesStore()
    private let appState = AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false))

    private func makeViewModel() throws -> CalculatorViewModel {
        let suiteName = "CalculatorViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return CalculatorViewModel(
            repository: repository,
            ratesStore: ratesStore,
            appState: appState,
            userDefaults: defaults
        )
    }

    /// Yields the main actor until `condition` holds, letting the view model's
    /// internal fetch task (also main-actor) run to completion. Callers guard
    /// against hangs with `.timeLimit`.
    private func waitUntil(_ condition: () -> Bool) async {
        while condition() == false {
            await Task.yield()
        }
    }

    /// Yields the main actor until the load lifecycle settles in a terminal case.
    private func waitUntilSettled(_ viewModel: CalculatorViewModel) async {
        await waitUntil {
            switch viewModel.loadState {
            case .loaded, .failed: true
            case .idle, .loading: false
            }
        }
    }

    // MARK: Initialization

    @Test("initializes with currencies from the injected defaults, falling back to USD/EUR")
    func initializesWithDefaults() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.targetCurrency == "EUR")
        #expect(viewModel.loadState == .idle)
        #expect(viewModel.availableRates.isEmpty)
    }

    @Test("initializes with stored currency preferences when present")
    func initializesWithStoredPreferences() throws {
        let suiteName = "CalculatorViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("CHF", forKey: UserDefaultsKeys.defaultBaseCurrency)
        defaults.set("CAD", forKey: UserDefaultsKeys.defaultTargetCurrency)

        let viewModel = CalculatorViewModel(
            repository: repository,
            ratesStore: ratesStore,
            appState: appState,
            userDefaults: defaults
        )

        #expect(viewModel.baseCurrency == "CHF")
        #expect(viewModel.targetCurrency == "CAD")
        #expect(ratesStore.baseCurrency == "CHF")
    }

    // MARK: inputAmount semantics

    @Test("inputAmountString is cents-style: the last two digits are the fraction", arguments: [
        ("0", 0.0),
        ("5", 0.05),
        ("100", 1.0),
        ("1234", 12.34),
        ("999999", 9999.99),
        ("not-a-number", 0.0),
    ])
    func inputAmountParsesCentsStyle(input: String, expected: Double) throws {
        let viewModel = try makeViewModel()
        viewModel.inputAmountString = input
        #expect(abs(viewModel.inputAmount - expected) < 0.0001)
    }

    // MARK: conversionRate math

    @Test("conversionRate is target rate divided by base rate from availableRates")
    func conversionRateUsesAvailableRates() throws {
        let viewModel = try makeViewModel()
        viewModel.availableRates = [
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.8),
            ExchangeRate(currencyCode: "GBP", rate: 0.5),
        ]
        viewModel.baseCurrency = "EUR"
        viewModel.targetCurrency = "GBP"
        #expect(abs(viewModel.conversionRate - 0.625) < 0.0001) // 0.5 / 0.8
    }

    @Test("conversionRate is 1.0 when base and target are the same currency")
    func conversionRateSameCurrencyIsOne() throws {
        let viewModel = try makeViewModel()
        viewModel.availableRates = [ExchangeRate(currencyCode: "EUR", rate: 0.8)]
        viewModel.baseCurrency = "EUR"
        viewModel.targetCurrency = "EUR"
        #expect(viewModel.conversionRate == 1.0)
    }

    @Test("a currency missing from availableRates falls back to a rate of 1.0")
    func conversionRateMissingCurrencyFallsBack() throws {
        let viewModel = try makeViewModel()
        viewModel.availableRates = [ExchangeRate(currencyCode: "USD", rate: 1.0)]
        viewModel.baseCurrency = "USD"
        viewModel.targetCurrency = "ZZZ" // unknown → treated as 1.0
        #expect(viewModel.conversionRate == 1.0)
    }

    // MARK: convertedAmount formatting

    @Test("convertedAmount formats with exactly two fraction digits")
    func convertedAmountFormatting() throws {
        let viewModel = try makeViewModel()
        viewModel.availableRates = [
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.85),
        ]
        viewModel.baseCurrency = "USD"
        viewModel.targetCurrency = "EUR"
        viewModel.inputAmountString = "1000" // 10.00

        #expect(viewModel.convertedAmount == "8.50") // locale pinned to en_US by the test plan
    }

    // MARK: Fetch lifecycle

    @Test("checkIfShouldFetch fetches when rates are stale and the device is connected", .timeLimit(.minutes(1)))
    func staleAndConnectedFetches() async throws {
        let viewModel = try makeViewModel()
        repository.shouldRefreshRatesResult = true
        appState.networkMonitor.isConnected = true
        repository.fetchExchangeRatesResult = .success([
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.9),
        ])

        await viewModel.checkIfShouldFetch()
        await waitUntilSettled(viewModel)

        #expect(repository.fetchExchangeRatesCallCount == 1)
        #expect(viewModel.availableRates.contains { $0.currencyCode == "EUR" && $0.rate == 0.9 })
        #expect(viewModel.availableRates.contains { $0.currencyCode == "USD" && $0.rate == 1.0 })
        #expect(viewModel.lastUpdated != nil)
        guard case let .loaded(rates) = viewModel.loadState else {
            Issue.record("expected .loaded, got \(viewModel.loadState)")
            return
        }
        #expect(rates == viewModel.availableRates)
    }

    @Test("fetchExchangeRates transitions loading(previous:) → loaded", .timeLimit(.minutes(1)))
    func fetchTransitionsThroughLoadingToLoaded() async throws {
        let viewModel = try makeViewModel()
        let fetched = [
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.9),
        ]
        repository.fetchExchangeRatesResult = .success(fetched)
        appState.networkMonitor.isConnected = true
        #expect(viewModel.loadState == .idle)

        let fetchTask = Task { await viewModel.fetchExchangeRates() }
        await waitUntil { viewModel.loadState.isLoading }

        guard case let .loading(previous) = viewModel.loadState else {
            Issue.record("expected .loading, got \(viewModel.loadState)")
            return
        }
        #expect(previous == nil) // first load: nothing to keep on screen

        await fetchTask.value
        #expect(viewModel.loadState == .loaded(fetched))
    }

    @Test("a refetch keeps the previous rates in the loading phase", .timeLimit(.minutes(1)))
    func refetchKeepsPreviousRatesWhileLoading() async throws {
        let viewModel = try makeViewModel()
        let initial = [ExchangeRate(currencyCode: "EUR", rate: 0.9)]
        appState.networkMonitor.isConnected = true
        repository.loadExchangeRatesResult = .success(initial)
        await viewModel.checkIfShouldFetch()
        try #require(viewModel.loadState == .loaded(initial))

        let fetchTask = Task { await viewModel.fetchExchangeRates() }
        await waitUntil { viewModel.loadState.isLoading }

        guard case let .loading(previous) = viewModel.loadState else {
            Issue.record("expected .loading, got \(viewModel.loadState)")
            return
        }
        #expect(previous == initial)
        await fetchTask.value
    }

    @Test("checkIfShouldFetch loads from cache when rates are fresh")
    func freshLoadsFromCache() async throws {
        let viewModel = try makeViewModel()
        repository.shouldRefreshRatesResult = false
        appState.networkMonitor.isConnected = true
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.88)])

        await viewModel.checkIfShouldFetch()

        #expect(repository.fetchExchangeRatesCallCount == 0)
        #expect(viewModel.availableRates.count == 1)
        #expect(viewModel.availableRates.first?.rate == 0.88)
        #expect(viewModel.loadState == .loaded([ExchangeRate(currencyCode: "EUR", rate: 0.88)]))
        #expect(viewModel.isUsingMockData == false)
    }

    @Test("a failing fetch falls back to cached data", .timeLimit(.minutes(1)))
    func failedFetchFallsBackToCache() async throws {
        let viewModel = try makeViewModel()
        repository.shouldRefreshRatesResult = true
        appState.networkMonitor.isConnected = true
        repository.fetchExchangeRatesResult = .failure(.networkError("stubbed failure"))
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "GBP", rate: 0.75)])

        await viewModel.checkIfShouldFetch()
        await waitUntilSettled(viewModel)

        #expect(repository.fetchExchangeRatesCallCount == 1)
        #expect(viewModel.availableRates.count == 1)
        #expect(viewModel.availableRates.first?.currencyCode == "GBP")
        #expect(viewModel.isUsingMockData == false)
        // The cache fallback succeeded, so the lifecycle ends loaded, not failed.
        #expect(viewModel.loadState == .loaded([ExchangeRate(currencyCode: "GBP", rate: 0.75)]))
    }

    @Test("offline with no cached data falls back to mock data")
    func offlineWithoutCacheUsesMockData() async throws {
        let viewModel = try makeViewModel()
        repository.shouldRefreshRatesResult = true
        appState.networkMonitor.isConnected = false
        repository.loadExchangeRatesResult = .failure(.noCachedData)

        await viewModel.checkIfShouldFetch()

        #expect(repository.fetchExchangeRatesCallCount == 0)
        #expect(viewModel.isUsingMockData == true)
        #expect(viewModel.availableRates.count == MockExchangeRates.rates.count)
        guard case let .loaded(rates) = viewModel.loadState else {
            Issue.record("expected .loaded mock data, got \(viewModel.loadState)")
            return
        }
        #expect(rates.count == MockExchangeRates.rates.count)
    }

    @Test(
        "online with a failing fetch AND failing cache ends loading with an error state (no deadlock)",
        .timeLimit(.minutes(1))
    )
    func onlineFetchAndCacheBothFailEndsLoading() async throws {
        // Phase-B regression: this path previously re-entered the fetch pipeline and
        // self-deadlocked awaiting its own fetchTask.
        let viewModel = try makeViewModel()
        repository.shouldRefreshRatesResult = true
        appState.networkMonitor.isConnected = true
        repository.fetchExchangeRatesResult = .failure(.networkError("stubbed fetch failure"))
        repository.loadExchangeRatesResult = .failure(.noCachedData)

        await viewModel.checkIfShouldFetch()
        await waitUntilSettled(viewModel)

        guard case let .failed(error, _) = viewModel.loadState else {
            Issue.record("expected .failed, got \(viewModel.loadState)")
            return
        }
        #expect(error == .networkError("stubbed fetch failure"))
        #expect(viewModel.availableRates.isEmpty)
        #expect(viewModel.isUsingMockData == false)
    }

    // MARK: Pending conversion

    @Test("consumePendingConversion applies and clears the AppState request")
    func consumePendingConversionAppliesRequest() throws {
        let viewModel = try makeViewModel()
        appState.pendingConversion = PendingConversion(
            baseCurrency: "JPY", targetCurrency: "USD", amountInput: "120000"
        )

        viewModel.consumePendingConversion()

        #expect(viewModel.baseCurrency == "JPY")
        #expect(viewModel.targetCurrency == "USD")
        #expect(viewModel.inputAmountString == "120000")
        #expect(appState.pendingConversion == nil)
    }

    @Test("consumePendingConversion is a no-op without a pending request")
    func consumePendingConversionNoRequest() throws {
        let viewModel = try makeViewModel()
        let base = viewModel.baseCurrency
        let input = viewModel.inputAmountString

        viewModel.consumePendingConversion()

        #expect(viewModel.baseCurrency == base)
        #expect(viewModel.inputAmountString == input)
    }

    // MARK: clearAllData

    @Test("clearAllData resets rates, dates, errors, and loading state")
    func clearAllDataResetsState() async throws {
        let viewModel = try makeViewModel()
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.9)])
        await viewModel.checkIfShouldFetch()
        try #require(viewModel.availableRates.isEmpty == false)

        viewModel.clearAllData()

        #expect(viewModel.availableRates.isEmpty)
        #expect(viewModel.lastUpdated == nil)
        #expect(viewModel.loadState == .loaded([]))
        #expect(viewModel.isUsingMockData == false)
        guard case .none = viewModel.retryState else {
            Issue.record("retryState should be .none after clearAllData, got \(viewModel.retryState)")
            return
        }
    }

    // MARK: Input intents

    @Test("appendDigit replaces a leading zero and appends thereafter")
    func appendDigitLeadingZero() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.inputAmountString == "0")

        #expect(viewModel.appendDigit("0") == true)
        #expect(viewModel.inputAmountString == "0") // 0 over 0 stays 0

        #expect(viewModel.appendDigit("7") == true)
        #expect(viewModel.inputAmountString == "7")

        #expect(viewModel.appendDigit("5") == true)
        #expect(viewModel.inputAmountString == "75")
    }

    @Test("appendDigit rejects input beyond the 15-digit maximum")
    func appendDigitMaxLength() throws {
        let viewModel = try makeViewModel()
        viewModel.inputAmountString = String(repeating: "9", count: 15)

        #expect(viewModel.appendDigit("1") == false)
        #expect(viewModel.inputAmountString == String(repeating: "9", count: 15))
    }

    @Test("deleteLastDigit drops the last digit and bottoms out at zero")
    func deleteLastDigitSemantics() throws {
        let viewModel = try makeViewModel()
        viewModel.inputAmountString = "123"

        viewModel.deleteLastDigit()
        #expect(viewModel.inputAmountString == "12")
        viewModel.deleteLastDigit()
        #expect(viewModel.inputAmountString == "1")
        viewModel.deleteLastDigit()
        #expect(viewModel.inputAmountString == "0")
        viewModel.deleteLastDigit()
        #expect(viewModel.inputAmountString == "0")
    }

    @Test("clearInput resets the amount to zero")
    func clearInputResets() throws {
        let viewModel = try makeViewModel()
        viewModel.inputAmountString = "4200"

        viewModel.clearInput()

        #expect(viewModel.inputAmountString == "0")
    }

    // MARK: Currency pair intents

    @Test("swapCurrencies exchanges base and target and publishes the new base")
    func swapCurrenciesExchangesPair() throws {
        let viewModel = try makeViewModel()
        viewModel.baseCurrency = "USD"
        viewModel.targetCurrency = "JPY"

        viewModel.swapCurrencies()

        #expect(viewModel.baseCurrency == "JPY")
        #expect(viewModel.targetCurrency == "USD")
        #expect(ratesStore.baseCurrency == "JPY")
    }

    // MARK: Destination

    @Test("destination drives the currency picker sheet for either side")
    func destinationTransitions() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.destination == nil)

        viewModel.destination = .basePicker
        #expect(viewModel.destination == .basePicker)

        viewModel.destination = .targetPicker
        #expect(viewModel.destination == .targetPicker)

        viewModel.destination = nil
        #expect(viewModel.destination == nil)
    }
}
