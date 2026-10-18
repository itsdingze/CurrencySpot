@testable import CurrencySpot
import Foundation
import Testing

@Suite("CalculatorViewModel Tests")
struct CalculatorViewModelTests {
    private let repository = MockExchangeRateRepository()
    private let ratesStore = ExchangeRatesStore()
    private let connectivity: AsyncStream<Bool>.Continuation
    private let appState: AppState
    private let isolatedDefaults = IsolatedDefaults()
    private let favorites: CurrencyCodeListStore

    init() throws {
        let (connectionUpdates, connectivity) = AsyncStream.makeStream(of: Bool.self)
        self.connectivity = connectivity
        appState = AppState(networkMonitor: NetworkMonitor(connectionUpdates: connectionUpdates))
        favorites = .favorites(in: try isolatedDefaults.make())
    }

    private func setConnected(_ isConnected: Bool) async {
        connectivity.yield(isConnected)
        await waitUntil { appState.networkMonitor.isConnected == isConnected }
    }

    private func makeViewModel(preferences: PreferencesStore = InMemoryPreferencesStore()) -> CalculatorViewModel {
        CalculatorViewModel(
            loadExchangeRatesUseCase: LoadExchangeRatesUseCase(
                repository: repository,
                dateProvider: FixedDateProvider(MockExchangeRateRepository.now)
            ),
            calculateConversionUseCase: CalculateConversionUseCase(),
            ratesStore: ratesStore,
            preferences: preferences,
            favorites: favorites,
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
        let viewModel = makeViewModel(
            preferences: InMemoryPreferencesStore(defaultBaseCurrency: "CHF", defaultTargetCurrency: "CAD")
        )

        #expect(viewModel.baseCurrency == "CHF")
        #expect(viewModel.targetCurrency == "CAD")
        #expect(ratesStore.baseCurrency == "CHF")
    }

    @Test("favoriteCurrencies lists the injected favorites store in its order")
    func favoriteCurrenciesReadTheFavoritesStore() {
        favorites.reset(to: ["JPY", "GBP"])
        let viewModel = makeViewModel()

        #expect(viewModel.favoriteCurrencies == ["JPY", "GBP"])

        favorites.add("CHF")

        #expect(viewModel.favoriteCurrencies == ["JPY", "GBP", "CHF"])
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

    @Test("a huge converted amount also has a short form for when the full digits don't fit")
    func compactConvertedAmount() async throws {
        let viewModel = await makeViewModel(fetching: [
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "IDR", rate: 16000),
        ])
        viewModel.baseCurrency = "USD"
        viewModel.targetCurrency = "IDR"
        viewModel.inputAmountString = "1000000000"

        #expect(viewModel.compactConvertedAmount == "160B")
    }

    @Test("formattedLastUpdated says the rates were not updated yet before any rates arrive")
    func formattedLastUpdatedBeforeAnyRates() {
        let viewModel = makeViewModel()

        #expect(viewModel.formattedLastUpdated == "Not updated yet")
    }

    @Test("formattedLastUpdated names the fetch date after a single Last updated prefix", .timeLimit(.minutes(1)))
    func formattedLastUpdatedNamesTheFetchDateOnce() async throws {
        let viewModel = await makeViewModel(fetching: [ExchangeRate(currencyCode: "EUR", rate: 0.9)])

        let text = viewModel.formattedLastUpdated

        #expect(text.hasPrefix("Last updated: "))
        #expect(text.components(separatedBy: "Last updated").count == 2)
        #expect(text.contains("2025"))
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
        await viewModel.checkIfShouldFetch()

        #expect(repository.fetchExchangeRatesCallCount == 1)
        guard case .loaded = viewModel.loadState else {
            Issue.record("expected .loaded, got \(viewModel.loadState)")
            return
        }
    }

    @Test("checkIfShouldFetch fetches when rates are stale and the device is connected", .timeLimit(.minutes(1)))
    func staleAndConnectedFetches() async throws {
        let viewModel = makeViewModel()
        repository.ratesAreStale = true
        await setConnected(true)
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
        await setConnected(true)
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }
        #expect(viewModel.loadState == .idle)

        let fetchTask = Task { await viewModel.fetchExchangeRates() }
        await waitUntil { repository.fetchExchangeRatesCallCount == 1 }

        #expect(viewModel.loadState == .loading(previous: nil))

        openGate.finish()
        await fetchTask.value
        #expect(viewModel.loadState == .loaded(fetched))
    }

    @Test("a refetch keeps the previous rates in the loading phase", .timeLimit(.minutes(1)))
    func refetchKeepsPreviousRatesWhileLoading() async throws {
        let viewModel = makeViewModel()
        let initial = [ExchangeRate(currencyCode: "EUR", rate: 0.9)]
        await setConnected(true)
        repository.loadExchangeRatesResult = .success(initial)
        await viewModel.checkIfShouldFetch()
        try #require(viewModel.loadState == .loaded(initial))
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }

        let fetchTask = Task { await viewModel.fetchExchangeRates() }
        await waitUntil { repository.fetchExchangeRatesCallCount == 1 }

        #expect(viewModel.loadState == .loading(previous: initial))

        openGate.finish()
        await fetchTask.value
    }

    @Test("checkIfShouldFetch loads from cache when rates are fresh")
    func freshLoadsFromCache() async throws {
        let viewModel = makeViewModel()
        repository.ratesAreStale = false
        await setConnected(true)
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
        repository.ratesAreStale = true
        await setConnected(true)
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
        repository.ratesAreStale = true
        await setConnected(false)
        repository.loadExchangeRatesResult = .failure(.noInternetConnection)

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

    @Test("a failed load offers Try Again while online and sample rates while offline")
    func failureRecoveryFollowsConnectivity() async {
        let viewModel = makeViewModel()

        await setConnected(true)
        #expect(viewModel.failureRecovery == .retry)

        await setConnected(false)
        #expect(viewModel.failureRecovery == .sampleRates)
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
        repository.ratesAreStale = true
        await setConnected(false)
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.91)])

        await viewModel.checkIfShouldFetch()
        await waitUntilSettled(viewModel)

        #expect(repository.fetchExchangeRatesCallCount == 0)
        #expect(viewModel.isShowingSampleRates == false)
        #expect(viewModel.rateBanner == .offlineSaved)
        #expect(viewModel.canRetryRates == false)
    }

    @Test("offline sample rates offer no retry")
    func offlineSampleHasNoRetry() async {
        let viewModel = makeViewModel()
        await setConnected(false)

        viewModel.showSampleRates()

        #expect(viewModel.rateBanner == .sample)
        #expect(viewModel.canRetryRates == false)
    }

    @Test("online sample rates kept after a failed refresh stay sample and offer retry", .timeLimit(.minutes(1)))
    func onlineSampleAfterFailedRefreshStaysSampleWithRetry() async throws {
        let viewModel = makeViewModel()
        viewModel.showSampleRates()
        try #require(viewModel.rateBanner == .sample)

        await setConnected(true)
        repository.fetchExchangeRatesResult = .failure(.networkError("down"))
        repository.loadExchangeRatesResult = .failure(.networkError("down"))
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
        repository.ratesAreStale = true
        await setConnected(true)
        repository.fetchExchangeRatesResult = .failure(.networkError("stubbed fetch failure"))
        repository.loadExchangeRatesResult = .failure(.networkError("stubbed load failure"))

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
        await setConnected(false)
        repository.ratesAreStale = true
        repository.loadExchangeRatesResult = .failure(.noInternetConnection)
        await viewModel.checkIfShouldFetch()
        guard case .failed = viewModel.loadState else {
            Issue.record("precondition: expected .failed, got \(viewModel.loadState)")
            return
        }

        await setConnected(true)
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

    @Test("a saved-rates lookup that resolves after a reconnect fetch never overwrites the fresh rates", .timeLimit(.minutes(1)))
    func lateSavedResultDoesNotOverwriteReconnectFetch() async throws {
        let viewModel = makeViewModel()
        await setConnected(false)
        repository.ratesAreStale = true
        repository.loadExchangeRatesResult = .failure(.noInternetConnection)
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        repository.loadBarrier = { for await _ in gate {} }
        let check = Task { await viewModel.checkIfShouldFetch() }
        await waitUntil { repository.loadExchangeRatesCallCount == 1 }

        let fresh = [ExchangeRate(currencyCode: "EUR", rate: 0.95)]
        repository.fetchExchangeRatesResult = .success(fresh)
        await setConnected(true)
        await viewModel.handleReconnect()
        await waitUntil { viewModel.loadState == .loaded(fresh) }
        openGate.finish()
        await check.value

        #expect(viewModel.loadState == .loaded(fresh))
        #expect(viewModel.rateBanner == .hidden)
    }

    @Test("handleReconnect refreshes stale saved rates", .timeLimit(.minutes(1)))
    func reconnectRefreshesStaleRates() async throws {
        let viewModel = makeViewModel()
        await setConnected(true)
        repository.ratesAreStale = false
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.9)])
        await viewModel.checkIfShouldFetch()
        try #require(viewModel.loadState.value?.isEmpty == false)

        repository.ratesAreStale = true
        repository.fetchExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.95)])
        await viewModel.handleReconnect()
        await waitUntil { repository.fetchExchangeRatesCallCount == 1 }
        await waitUntilSettled(viewModel)

        #expect(repository.fetchExchangeRatesCallCount == 1)
    }

    @Test("handleReconnect does nothing when current rates are already fresh")
    func reconnectSkipsWhenFresh() async throws {
        let viewModel = makeViewModel()
        await setConnected(true)
        repository.ratesAreStale = false
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: "EUR", rate: 0.9)])
        await viewModel.checkIfShouldFetch()

        await viewModel.handleReconnect()
        await viewModel.checkIfShouldFetch()

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

    @Test("a data reset clears the shown rates, then fetches fresh ones", .timeLimit(.minutes(1)))
    func dataResetClearsThenRefetches() async throws {
        let viewModel = makeViewModel()
        await setConnected(true)
        repository.ratesAreStale = true
        repository.fetchExchangeRatesResult = .failure(.networkError("down"))
        let saved = [ExchangeRate(currencyCode: "EUR", rate: 0.9)]
        repository.loadExchangeRatesResult = .success(saved)
        await viewModel.checkIfShouldFetch()
        await waitUntilSettled(viewModel)
        try #require(viewModel.loadState == .loaded(saved))
        try #require(viewModel.lastRefreshFailed)

        let fresh = [ExchangeRate(currencyCode: "GBP", rate: 0.75)]
        repository.fetchExchangeRatesResult = .success(fresh)
        let (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        repository.fetchBarrier = { for await _ in gate {} }

        appState.dataWasReset()
        await waitUntil { repository.fetchExchangeRatesCallCount == 2 }

        #expect(viewModel.availableRates.isEmpty)
        #expect(viewModel.loadState == .loading(previous: []))
        #expect(viewModel.lastRefreshFailed == false)
        #expect(viewModel.isShowingSampleRates == false)
        #expect(viewModel.rateBanner == .hidden)

        openGate.finish()
        await waitUntil { viewModel.loadState == .loaded(fresh) }
        #expect(viewModel.availableRates == fresh)
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
