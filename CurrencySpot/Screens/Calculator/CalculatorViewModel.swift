import Foundation
import IdentifiedCollections
import Observation

// MARK: - CalculatorViewModel

@Observable
final class CalculatorViewModel {
    nonisolated enum Destination: Identifiable, Hashable {
        case basePicker
        case targetPicker
        case history

        var id: Self { self }
    }

    nonisolated enum FailureRecovery: Equatable {
        case retry
        case sampleRates
    }

    typealias KeypadMode = CalculatorSession.Mode
    typealias KeyPress = CalculatorSession.KeyPress

    // MARK: - Input and Calculation Properties

    var inputAmountString = "0" {
        didSet {
            guard inputAmountString != oldValue else { return }
            conversionShownSince = dateProvider.now()
        }
    }

    private let maxInputLength = 15

    private var calculator = CalculatorSession()

    @ObservationIgnored private var conversionShownSince: Date
    @ObservationIgnored private var lastSaved: ConversionRecord?
    private let conversionSettlesAfter: TimeInterval = 2

    var keypadMode: KeypadMode { calculator.mode }

    var isCalculationUndefined: Bool { calculator.isUndefined }

    var calculationSteps: String? { calculator.steps(locale: .autoupdatingCurrent) }

    var availableRates: [ExchangeRate] { ratesStore.rates }

    var favoriteCurrencies: [CurrencyCode] { favorites.codes.elements }

    // MARK: - Currency Selection Properties

    var baseCurrency: CurrencyCode {
        willSet { pairWillChange(from: baseCurrency, to: newValue) }
        didSet {
            ratesStore.updateBaseCurrency(baseCurrency)
            pairDidChange(from: oldValue, to: baseCurrency)
        }
    }

    var targetCurrency: CurrencyCode {
        willSet { pairWillChange(from: targetCurrency, to: newValue) }
        didSet { pairDidChange(from: oldValue, to: targetCurrency) }
    }

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

    var failureRecovery: FailureRecovery {
        appState.networkMonitor.isConnected ? .retry : .sampleRates
    }

    // MARK: - Private Properties

    private let loadExchangeRatesUseCase: LoadExchangeRatesUseCase
    private let calculateConversionUseCase: CalculateConversionUseCase
    private let ratesStore: ExchangeRatesStore
    private let favorites: CurrencyCodeListStore
    private let history: ConversionHistoryStore
    private let dateProvider: DateProvider
    private let appState: AppState
    private var fetchTask: Task<Void, Never>?
    private var fetchGeneration = 0

    private var rateTable: RateTable = .empty

    // MARK: - Initialization

    init(
        loadExchangeRatesUseCase: LoadExchangeRatesUseCase,
        calculateConversionUseCase: CalculateConversionUseCase,
        ratesStore: ExchangeRatesStore,
        preferences: PreferencesStore,
        favorites: CurrencyCodeListStore,
        history: ConversionHistoryStore,
        dateProvider: DateProvider,
        appState: AppState
    ) {
        self.loadExchangeRatesUseCase = loadExchangeRatesUseCase
        self.calculateConversionUseCase = calculateConversionUseCase
        self.ratesStore = ratesStore
        self.favorites = favorites
        self.history = history
        self.dateProvider = dateProvider
        self.appState = appState
        conversionShownSince = dateProvider.now()

        baseCurrency = preferences.defaultBaseCurrency
        targetCurrency = preferences.defaultTargetCurrency
        ratesStore.updateBaseCurrency(baseCurrency)
        observeDataReset()
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

    var formattedInputAmount: String {
        inputAmount.formatted(.number.precision(.fractionLength(2)))
    }

    var compactInputAmount: String {
        inputAmount.formatted(.compactAmount)
    }

    var convertedAmount: String {
        conversion.converted.formatted(.number.precision(.fractionLength(2)))
    }

    var compactConvertedAmount: String {
        conversion.converted.formatted(.compactAmount)
    }

    // MARK: - Computed Properties (Formatted Display Values)

    var formattedLastUpdated: String {
        guard let lastUpdated else { return String(localized: .calculatorRateInfoNotUpdated) }
        return String(localized: .calculatorRateInfoLastUpdated(date: lastUpdated.lastUpdatedDisplay))
    }

    var savedRatesTime: String? {
        lastUpdated?.savedRatesDisplay(relativeTo: dateProvider.now())
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

    // MARK: - Keypad Intents

    func showKeypad(_ mode: KeypadMode) {
        calculator.show(mode, fromAmount: inputAmount, fromDigits: inputAmountString)
    }

    @discardableResult
    func press(_ key: CalculatorExpression.Input) -> KeyPress {
        switch keypadMode {
        case .amount: pressAmountKey(key)
        case .calculator: pressCalculatorKey(key)
        }
    }

    private func pressAmountKey(_ key: CalculatorExpression.Input) -> KeyPress {
        switch key {
        case let .digit(digit):
            return appendDigit("\(digit)") ? .accepted : .rejected
        case .clear:
            saveSettledConversion()
            clearInput()
            return .accepted
        case .delete:
            deleteLastDigit()
            return .deleted
        case .decimalPoint, .percent, .operation, .equals:
            return .rejected
        }
    }

    private func pressCalculatorKey(_ key: CalculatorExpression.Input) -> KeyPress {
        if key == .clear { saveSettledConversion() }
        let outcome = calculator.press(key, toAmountDigits: amountDigits, maxAmountDigits: maxInputLength)
        if let digits = outcome.amountDigits { inputAmountString = digits }
        if let calculation = outcome.calculation { save(calculation: calculation.expression) }
        return outcome.press
    }

    private func amountDigits(for result: Decimal) -> String {
        calculateConversionUseCase.impliedCentsDigits(for: max(result, 0))
    }

    // MARK: - History Intents

    func saveConversion() {
        save(calculation: calculator.calculation(forAmountDigits: inputAmountString))
    }

    func showHistory() {
        saveConversion()
        destination = .history
    }

    func restore(_ record: ConversionRecord) {
        baseCurrency = record.base
        targetCurrency = record.target
        inputAmountString = amountDigits(for: record.amount)
        calculator.restore(record.calculation, amount: record.amount, amountDigits: inputAmountString)
        lastSaved = record
    }

    private func saveSettledConversion() {
        guard dateProvider.now().timeIntervalSince(conversionShownSince) >= conversionSettlesAfter else { return }
        saveConversion()
    }

    private func save(calculation: CalculatorExpression?) {
        guard inputAmount > 0, baseCurrency != targetCurrency, !isCalculationUndefined, hasLiveRates else { return }
        let record = ConversionRecord(
            id: UUID(),
            calculation: calculation,
            amount: inputAmount,
            base: baseCurrency,
            target: targetCurrency,
            converted: conversion.converted,
            date: dateProvider.now()
        )
        guard lastSaved?.isSameConversion(as: record) != true else { return }
        history.add(record)
        lastSaved = record
    }

    private var hasLiveRates: Bool {
        !isShowingSampleRates
            && rateTable.usdRate(for: baseCurrency) != nil
            && rateTable.usdRate(for: targetCurrency) != nil
    }

    // MARK: - Currency Pair Intents

    func swapCurrencies() {
        (baseCurrency, targetCurrency) = (targetCurrency, baseCurrency)
    }

    private func pairWillChange(from current: CurrencyCode, to next: CurrencyCode) {
        guard next != current else { return }
        saveSettledConversion()
    }

    private func pairDidChange(from previous: CurrencyCode, to current: CurrencyCode) {
        guard current != previous else { return }
        conversionShownSince = dateProvider.now()
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
            let generation = fetchGeneration
            let outcome = await loadExchangeRatesUseCase.saved()
            guard generation == fetchGeneration else { return }
            apply(outcome)
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
        saveConversion()
        appState.pendingConversion = nil
        baseCurrency = pending.baseCurrency
        targetCurrency = pending.targetCurrency
        inputAmountString = pending.amountInput
        calculator.reset()
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

    // MARK: - Data Reset

    private func observeDataReset() {
        withObservationTracking {
            _ = appState.dataResetCount
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                observeDataReset()
                await reloadAfterDataReset()
            }
        }
    }

    private func reloadAfterDataReset() async {
        publish(rates: [], lastUpdated: nil, isShowingSampleRates: false)
        loadState = .loaded([])
        lastRefreshFailed = false
        await checkIfShouldFetch()
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
