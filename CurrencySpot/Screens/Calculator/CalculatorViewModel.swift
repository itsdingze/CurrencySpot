import SwiftUI

// MARK: - CalculatorViewModel

@Observable
final class CalculatorViewModel {
    nonisolated enum Destination: Identifiable, Hashable {
        case basePicker
        case targetPicker

        var id: Self { self }
    }

    // MARK: - Input and Calculation Properties

    var inputAmountString = "0"

    private let maxInputLength = 15

    var availableRates: [ExchangeRate] { ratesStore.rates }

    var favoriteCurrencies: [CurrencyCode] { preferences.favoriteCurrencies.elements }

    // MARK: - Currency Selection Properties

    var baseCurrency: CurrencyCode {
        didSet { ratesStore.updateBaseCurrency(baseCurrency) }
    }

    var targetCurrency: CurrencyCode

    // MARK: - UI State Properties

    var destination: Destination?

    // MARK: - Loading and Error State Properties

    private(set) var loadState: Loadable<[ExchangeRate]> = .idle

    private(set) var lastRefreshFailed = false

    var lastUpdated: Date? { ratesStore.lastUpdated }
    var isShowingSampleRates: Bool { ratesStore.isShowingSampleRates }

    var rateBanner: RateBanner {
        if loadState.isLoading, loadState.value?.isEmpty == false { return .updating }
        guard loadState.value?.isEmpty == false else { return .hidden }
        if isShowingSampleRates { return .sample }
        if !appState.networkMonitor.isConnected { return .offlineSaved }
        if lastRefreshFailed { return .updateFailed }
        return .hidden
    }

    var canRetryRates: Bool {
        appState.networkMonitor.isConnected && lastRefreshFailed
    }

    // MARK: - Private Properties

    private let loadExchangeRatesUseCase: LoadExchangeRatesUseCase
    private let calculateConversionUseCase: CalculateConversionUseCase
    private let ratesStore: ExchangeRatesStore
    private let preferences: PreferencesStore
    private let appState: AppState
    private var fetchTask: Task<Void, Never>?
    private var fetchGeneration = 0

    private var rateTable: RateTable = .empty

    // MARK: - Initialization

    init(
        loadExchangeRatesUseCase: LoadExchangeRatesUseCase,
        calculateConversionUseCase: CalculateConversionUseCase = CalculateConversionUseCase(),
        ratesStore: ExchangeRatesStore,
        preferences: PreferencesStore,
        appState: AppState = .shared
    ) {
        self.loadExchangeRatesUseCase = loadExchangeRatesUseCase
        self.calculateConversionUseCase = calculateConversionUseCase
        self.ratesStore = ratesStore
        self.preferences = preferences
        self.appState = appState

        baseCurrency = preferences.defaultBaseCurrency
        targetCurrency = preferences.defaultTargetCurrency
        ratesStore.updateBaseCurrency(baseCurrency)
    }

    // MARK: - Computed Properties (Calculation Results)

    private var conversion: CalculateConversionUseCase.Conversion {
        calculateConversionUseCase(
            impliedCentsDigits: inputAmountString,
            from: baseCurrency,
            to: targetCurrency,
            in: rateTable
        )
    }

    var inputAmount: Decimal {
        conversion.amount
    }

    var conversionRate: Double {
        conversion.rate
    }

    var convertedAmount: String {
        conversion.converted.formatted(.number.precision(.fractionLength(2)))
    }

    // MARK: - Computed Properties (Formatted Display Values)

    var formattedLastUpdated: String {
        ratesStore.formattedLastUpdated
    }

    // MARK: - Input Intents

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

    func checkIfShouldFetch() async {
        if let existingTask = fetchTask {
            _ = await existingTask.result
        }

        let shouldFetch = await loadExchangeRatesUseCase.shouldRefresh()

        if shouldFetch, appState.networkMonitor.isConnected {
            guard fetchTask == nil else { return }
            startFetchTask()
        } else {
            apply(await loadExchangeRatesUseCase.saved())
        }
    }

    func retryFetch() {
        guard fetchTask == nil else { return }
        startFetchTask()
    }

    func handleReconnect() async {
        guard fetchTask == nil else { return }

        let shouldRefresh = await loadExchangeRatesUseCase.shouldRefreshOnReconnect(
            hasRates: loadState.value != nil,
            isShowingSample: isShowingSampleRates,
            lastRefreshFailed: lastRefreshFailed
        )

        if shouldRefresh {
            startFetchTask()
        }
    }

    func consumePendingConversion() {
        guard let pending = appState.pendingConversion else { return }
        appState.pendingConversion = nil
        baseCurrency = pending.baseCurrency
        targetCurrency = pending.targetCurrency
        inputAmountString = pending.amountInput
    }

    func clearAllData() {
        publish(rates: [], lastUpdated: nil, isShowingSampleRates: false)
        loadState = .loaded([])
        lastRefreshFailed = false
    }

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

    func fetchExchangeRates() async {
        loadState = .loading(previous: loadState.value)

        apply(await loadExchangeRatesUseCase.refresh())
    }

    private func apply(_ outcome: LoadExchangeRatesUseCase.Outcome) {
        switch outcome {
        case let .rates(rates, lastUpdated, refreshFailed):
            publish(rates: rates, lastUpdated: lastUpdated, isShowingSampleRates: false)
            lastRefreshFailed = refreshFailed
            loadState = .loaded(rates)

        case let .unavailable(error):
            if let shown = loadState.value {
                lastRefreshFailed = true
                loadState = .loaded(shown)
            } else if let error {
                loadState = .failed(error, previous: nil)
            } else {
                loadState = .loaded([])
            }
        }
    }

    // MARK: - Sample Rates

    func showSampleRates() {
        let rates = loadExchangeRatesUseCase.sampleRates()
        publish(rates: rates, lastUpdated: nil, isShowingSampleRates: true)
        loadState = .loaded(rates)
    }

    // MARK: - Rates Publishing

    private func publish(rates: [ExchangeRate], lastUpdated: Date?, isShowingSampleRates: Bool) {
        ratesStore.update(rates: rates, lastUpdated: lastUpdated, isShowingSampleRates: isShowingSampleRates)
        rateTable = RateTable(rates)
    }
}
