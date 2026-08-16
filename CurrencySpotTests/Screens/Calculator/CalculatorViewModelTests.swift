@testable import CurrencySpot
import Foundation
import Testing

@Suite("CalculatorViewModel Tests")
struct CalculatorViewModelTests {
    private let repository = MockExchangeRateRepository()
    private let ratesStore = ExchangeRatesStore()
    private let appState = AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false))

    private func makeViewModel() -> CalculatorViewModel {
        CalculatorViewModel(
            loadExchangeRatesUseCase: LoadExchangeRatesUseCase(repository: repository),
            ratesStore: ratesStore,
            preferences: InMemoryPreferencesStore(),
            appState: appState
        )
    }

    private func makeViewModel(fetching rates: [ExchangeRate]) async -> CalculatorViewModel {
        repository.fetchExchangeRatesResult = .success(rates)
        let viewModel = makeViewModel()
        await viewModel.fetchExchangeRates()
        return viewModel
    }

    private func waitUntilSettled(_ viewModel: CalculatorViewModel) async {
        await waitUntil {
            switch viewModel.loadState {
            case .loaded, .failed: true
            case .idle, .loading: false
            }
        }
    }

    @Test("initializes with currencies from the injected defaults, falling back to USD/EUR")
    func initializesWithDefaults() throws {
        let viewModel = makeViewModel()
        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.targetCurrency == "EUR")
        #expect(viewModel.loadState == .idle)
        #expect(viewModel.availableRates.isEmpty)
    }

    @Test("initializes with stored currency preferences when present")
    func initializesWithStoredPreferences() {
        let viewModel = CalculatorViewModel(
            loadExchangeRatesUseCase: LoadExchangeRatesUseCase(repository: repository),
            ratesStore: ratesStore,
            preferences: InMemoryPreferencesStore(defaultBaseCurrency: "CHF", defaultTargetCurrency: "CAD"),
            appState: appState
        )

        #expect(viewModel.baseCurrency == "CHF")
        #expect(viewModel.targetCurrency == "CAD")
        #expect(ratesStore.baseCurrency == "CHF")
    }

    @Test("inputAmountString is cents-style: the last two digits are the fraction", arguments: [
        ("0", Decimal(0)),
        ("5", Decimal(string: "0.05")!),
        ("100", Decimal(1)),
        ("1234", Decimal(string: "12.34")!),
        ("999999", Decimal(string: "9999.99")!),
        ("not-a-number", Decimal(0)),
    ])
    func inputAmountParsesCentsStyle(input: String, expected: Decimal) throws {
        let viewModel = makeViewModel()
        viewModel.inputAmountString = input
        #expect(viewModel.inputAmount == expected)
    }

    @Test("conversionRate is target rate divided by base rate from availableRates")
    func conversionRateUsesAvailableRates() async throws {
        let viewModel = await makeViewModel(fetching: [
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.8),
            ExchangeRate(currencyCode: "GBP", rate: 0.5),
        ])
        viewModel.baseCurrency = "EUR"
        viewModel.targetCurrency = "GBP"
        #expect(abs(viewModel.conversionRate - 0.625) < 0.0001)
    }

    @Test("conversionRate is 1.0 when base and target are the same currency")
    func conversionRateSameCurrencyIsOne() async throws {
        let viewModel = await makeViewModel(fetching: [ExchangeRate(currencyCode: "EUR", rate: 0.8)])
        viewModel.baseCurrency = "EUR"
        viewModel.targetCurrency = "EUR"
        #expect(viewModel.conversionRate == 1.0)
    }

    @Test("a currency missing from availableRates falls back to a rate of 1.0")
    func conversionRateMissingCurrencyFallsBack() async throws {
        let viewModel = await makeViewModel(fetching: [ExchangeRate(currencyCode: "USD", rate: 1.0)])
        viewModel.baseCurrency = "USD"
        viewModel.targetCurrency = "ZZZ"
        #expect(viewModel.conversionRate == 1.0)
    }

    @Test("convertedAmount formats with exactly two fraction digits")
    func convertedAmountFormatting() async throws {
        let viewModel = await makeViewModel(fetching: [
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.85),
        ])
        viewModel.baseCurrency = "USD"
        viewModel.targetCurrency = "EUR"
        viewModel.inputAmountString = "1000"

        #expect(viewModel.convertedAmount == "8.50")
    }

    @Test("retryFetch is single-flight: a second tap during an in-flight fetch starts no second fetch", .timeLimit(.minutes(1)))
    func retryFetchIsSingleFlight() async throws {
        let viewModel = makeViewModel()
        repository.fetchExchangeRatesResult = .success([
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.9),
        ])

        viewModel.retryFetch()
        viewModel.retryFetch()
        await waitUntilSettled(viewModel)

        #expect(repository.fetchExchangeRatesCallCount == 1)
        guard case .loaded = viewModel.loadState else {
            Issue.record("expected .loaded, got \(viewModel.loadState)")
            return
        }
    }

    @Test("checkIfShouldFetch fetches when rates are stale and the device is connected", .timeLimit(.minutes(1)))
    func staleAndConnectedFetches() async throws {
        let viewModel = makeViewModel()
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
        let viewModel = makeViewModel()
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
        #expect(previous == nil)

        await fetchTask.value
        #expect(viewModel.loadState == .loaded(fetched))
    }

    @Test("a refetch keeps the previous rates in the loading phase", .timeLimit(.minutes(1)))
    func refetchKeepsPreviousRatesWhileLoading() async throws {
        let viewModel = makeViewModel()
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
        let viewModel = makeViewModel()
        repository.shouldRefreshRatesResult = false
        appState.networkMonitor.isConnected = true
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.88)])

        await viewModel.checkIfShouldFetch()

        #expect(repository.fetchExchangeRatesCallCount == 0)
        #expect(viewModel.availableRates.count == 1)
        #expect(viewModel.availableRates.first?.rate == 0.88)
        #expect(viewModel.loadState == .loaded([ExchangeRate(currencyCode: "EUR", rate: 0.88)]))
        #expect(viewModel.isShowingSampleRates == false)
        #expect(viewModel.rateBanner == .hidden)
    }

    @Test("a failing fetch falls back to cached data", .timeLimit(.minutes(1)))
    func failedFetchFallsBackToCache() async throws {
        let viewModel = makeViewModel()
        repository.shouldRefreshRatesResult = true
        appState.networkMonitor.isConnected = true
        repository.fetchExchangeRatesResult = .failure(.networkError("stubbed failure"))
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "GBP", rate: 0.75)])

        await viewModel.checkIfShouldFetch()
        await waitUntilSettled(viewModel)

        #expect(repository.fetchExchangeRatesCallCount == 1)
        #expect(viewModel.availableRates.count == 1)
        #expect(viewModel.availableRates.first?.currencyCode == "GBP")
        #expect(viewModel.isShowingSampleRates == false)
        #expect(viewModel.loadState == .loaded([ExchangeRate(currencyCode: "GBP", rate: 0.75)]))
        #expect(viewModel.lastRefreshFailed == true)
        #expect(viewModel.rateBanner == .updateFailed)
        #expect(viewModel.canRetryRates == true)
    }

    @Test("offline with no saved rates shows the error state instead of auto-loading sample rates")
    func offlineWithoutCacheShowsErrorState() async throws {
        let viewModel = makeViewModel()
        repository.shouldRefreshRatesResult = true
        appState.networkMonitor.isConnected = false
        repository.loadExchangeRatesResult = .failure(.noCachedData)

        await viewModel.checkIfShouldFetch()

        #expect(repository.fetchExchangeRatesCallCount == 0)
        #expect(viewModel.isShowingSampleRates == false)
        #expect(viewModel.availableRates.isEmpty)
        guard case .failed = viewModel.loadState else {
            Issue.record("expected .failed, got \(viewModel.loadState)")
            return
        }
        #expect(viewModel.rateBanner == .hidden)
    }

    @Test("showSampleRates publishes the fallback rates and raises the sample banner")
    func showSampleRatesRaisesSampleBanner() throws {
        let viewModel = makeViewModel()

        viewModel.showSampleRates()

        #expect(viewModel.isShowingSampleRates == true)
        #expect(viewModel.availableRates.count == SampleExchangeRates.rates.count)
        #expect(viewModel.rateBanner == .sample)
        guard case .loaded = viewModel.loadState else {
            Issue.record("expected .loaded sample rates, got \(viewModel.loadState)")
            return
        }
    }

    @Test("offline with saved rates shows them under the offline banner", .timeLimit(.minutes(1)))
    func offlineWithCacheShowsOfflineBanner() async throws {
        let viewModel = makeViewModel()
        repository.shouldRefreshRatesResult = true
        appState.networkMonitor.isConnected = false
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.91)])

        await viewModel.checkIfShouldFetch()
        await waitUntilSettled(viewModel)

        #expect(repository.fetchExchangeRatesCallCount == 0)
        #expect(viewModel.isShowingSampleRates == false)
        #expect(viewModel.rateBanner == .offlineSaved)
        #expect(viewModel.canRetryRates == false)
    }

    @Test("offline sample rates offer no retry")
    func offlineSampleHasNoRetry() throws {
        let viewModel = makeViewModel()
        appState.networkMonitor.isConnected = false

        viewModel.showSampleRates()

        #expect(viewModel.rateBanner == .sample)
        #expect(viewModel.canRetryRates == false)
    }

    @Test("online sample rates kept after a failed refresh stay sample and offer retry", .timeLimit(.minutes(1)))
    func onlineSampleAfterFailedRefreshStaysSampleWithRetry() async throws {
        let viewModel = makeViewModel()
        viewModel.showSampleRates()
        try #require(viewModel.rateBanner == .sample)

        appState.networkMonitor.isConnected = true
        repository.fetchExchangeRatesResult = .failure(.networkError("down"))
        repository.loadExchangeRatesResult = .failure(.noCachedData)
        viewModel.retryFetch()
        await waitUntil { repository.fetchExchangeRatesCallCount == 1 }
        await waitUntilSettled(viewModel)

        #expect(viewModel.isShowingSampleRates == true)
        #expect(viewModel.rateBanner == .sample)
        #expect(viewModel.canRetryRates == true)
    }

    @Test(
        "online with a failing fetch AND failing cache ends loading with an error state (no deadlock)",
        .timeLimit(.minutes(1))
    )
    func onlineFetchAndCacheBothFailEndsLoading() async throws {
        let viewModel = makeViewModel()
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
        #expect(viewModel.isShowingSampleRates == false)
    }

    @Test("handleReconnect fetches when there are no rates to show", .timeLimit(.minutes(1)))
    func reconnectFetchesWhenNoRates() async throws {
        let viewModel = makeViewModel()
        appState.networkMonitor.isConnected = false
        repository.shouldRefreshRatesResult = true
        repository.loadExchangeRatesResult = .failure(.noCachedData)
        await viewModel.checkIfShouldFetch()
        guard case .failed = viewModel.loadState else {
            Issue.record("precondition: expected .failed, got \(viewModel.loadState)")
            return
        }

        appState.networkMonitor.isConnected = true
        repository.fetchExchangeRatesResult = .success([ExchangeRate(currencyCode: "USD", rate: 1.0)])
        await viewModel.handleReconnect()
        await waitUntil { repository.fetchExchangeRatesCallCount == 1 }
        await waitUntilSettled(viewModel)

        #expect(repository.fetchExchangeRatesCallCount == 1)
        guard case .loaded = viewModel.loadState else {
            Issue.record("expected .loaded after reconnect, got \(viewModel.loadState)")
            return
        }
    }

    @Test("handleReconnect refreshes stale saved rates", .timeLimit(.minutes(1)))
    func reconnectRefreshesStaleRates() async throws {
        let viewModel = makeViewModel()
        appState.networkMonitor.isConnected = true
        repository.shouldRefreshRatesResult = false
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.9)])
        await viewModel.checkIfShouldFetch()
        try #require(viewModel.loadState.value?.isEmpty == false)

        repository.shouldRefreshRatesResult = true
        repository.fetchExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.95)])
        await viewModel.handleReconnect()
        await waitUntil { repository.fetchExchangeRatesCallCount == 1 }
        await waitUntilSettled(viewModel)

        #expect(repository.fetchExchangeRatesCallCount == 1)
    }

    @Test("handleReconnect does nothing when current rates are already fresh")
    func reconnectSkipsWhenFresh() async throws {
        let viewModel = makeViewModel()
        appState.networkMonitor.isConnected = true
        repository.shouldRefreshRatesResult = false
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.9)])
        await viewModel.checkIfShouldFetch()

        await viewModel.handleReconnect()

        #expect(repository.fetchExchangeRatesCallCount == 0)
    }

    @Test("consumePendingConversion applies and clears the AppState request")
    func consumePendingConversionAppliesRequest() throws {
        let viewModel = makeViewModel()
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
        let viewModel = makeViewModel()
        let base = viewModel.baseCurrency
        let input = viewModel.inputAmountString

        viewModel.consumePendingConversion()

        #expect(viewModel.baseCurrency == base)
        #expect(viewModel.inputAmountString == input)
    }

    @Test("clearAllData resets rates, dates, errors, and loading state")
    func clearAllDataResetsState() async throws {
        let viewModel = makeViewModel()
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.9)])
        await viewModel.checkIfShouldFetch()
        try #require(viewModel.availableRates.isEmpty == false)

        viewModel.clearAllData()

        #expect(viewModel.availableRates.isEmpty)
        #expect(viewModel.lastUpdated == nil)
        #expect(viewModel.loadState == .loaded([]))
        #expect(viewModel.isShowingSampleRates == false)
        #expect(viewModel.lastRefreshFailed == false)
        #expect(viewModel.rateBanner == .hidden)
    }

    @Test("appendDigit replaces a leading zero and appends thereafter")
    func appendDigitLeadingZero() throws {
        let viewModel = makeViewModel()
        #expect(viewModel.inputAmountString == "0")

        #expect(viewModel.appendDigit("0") == true)
        #expect(viewModel.inputAmountString == "0")

        #expect(viewModel.appendDigit("7") == true)
        #expect(viewModel.inputAmountString == "7")

        #expect(viewModel.appendDigit("5") == true)
        #expect(viewModel.inputAmountString == "75")
    }

    @Test("appendDigit rejects input beyond the 15-digit maximum")
    func appendDigitMaxLength() throws {
        let viewModel = makeViewModel()
        viewModel.inputAmountString = String(repeating: "9", count: 15)

        #expect(viewModel.appendDigit("1") == false)
        #expect(viewModel.inputAmountString == String(repeating: "9", count: 15))
    }

    @Test("deleteLastDigit drops the last digit and bottoms out at zero")
    func deleteLastDigitSemantics() throws {
        let viewModel = makeViewModel()
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
        let viewModel = makeViewModel()
        viewModel.inputAmountString = "4200"

        viewModel.clearInput()

        #expect(viewModel.inputAmountString == "0")
    }

    @Test("swapCurrencies exchanges base and target and publishes the new base")
    func swapCurrenciesExchangesPair() throws {
        let viewModel = makeViewModel()
        viewModel.baseCurrency = "USD"
        viewModel.targetCurrency = "JPY"

        viewModel.swapCurrencies()

        #expect(viewModel.baseCurrency == "JPY")
        #expect(viewModel.targetCurrency == "USD")
        #expect(ratesStore.baseCurrency == "JPY")
    }

    @Test("destination drives the currency picker sheet for either side")
    func destinationTransitions() throws {
        let viewModel = makeViewModel()
        #expect(viewModel.destination == nil)

        viewModel.destination = .basePicker
        #expect(viewModel.destination == .basePicker)

        viewModel.destination = .targetPicker
        #expect(viewModel.destination == .targetPicker)

        viewModel.destination = nil
        #expect(viewModel.destination == nil)
    }
}
