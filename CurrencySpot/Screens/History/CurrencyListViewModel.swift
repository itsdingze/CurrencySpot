import Foundation
import IdentifiedCollections
import OSLog
import Observation
import SwiftUI

// MARK: - CurrencyListViewModel

@Observable
final class CurrencyListViewModel {
    nonisolated enum Destination: Equatable {
        case basePicker
    }

    // MARK: - List State

    private(set) var displayedCurrencies: [CurrencyListEntry] = []

    var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            updateDisplayedCurrencies()
        }
    }

    var sortOption: CurrencySortOption = .manual {
        didSet {
            guard sortOption != oldValue else { return }
            updateDisplayedCurrencies()
        }
    }

    var trendDisplayMode: TrendDisplayMode = .percentChange

    var selection: HistoryRoute? {
        didSet {
            if selection != oldValue { currentHistory = nil }
        }
    }

    var selectedCurrency: CurrencyCode? {
        get { selection?.link.target }
        set {
            guard newValue != selectedCurrency else { return }
            if let newValue {
                openHistory(for: newValue)
            } else {
                selection = nil
            }
        }
    }

    var chartLink: HistoryLink? {
        selection?.link ?? defaultChartCurrency.map { HistoryLink(base: baseCurrency, target: $0) }
    }

    private var defaultChartCurrency: CurrencyCode?

    var path: [HistoryRoute] {
        get { selection.map { [$0] } ?? [] }
        set { selection = newValue.last }
    }

    var isSearching: Bool { !searchText.isEmpty }

    var isWatchlistEmpty: Bool { watchlist.codes.allSatisfy { $0 == baseCurrency } }

    var isWaitingForConnection: Bool { isMissingRates && !appState.networkMonitor.isConnected }

    var isLoadingRates: Bool { isMissingRates && appState.networkMonitor.isConnected }

    private var isMissingRates: Bool { !isWatchlistEmpty && ratesStore.rates.isEmpty }

    var baseCurrency: CurrencyCode {
        guard let picked = historyBase.pickedBase, isListedInRates(picked) else {
            return preferences.defaultBaseCurrency
        }
        return picked
    }

    var destination: Destination?

    var basePickerFavorites: [CurrencyCode] { favorites.codes.elements }

    var basePickerRates: [ExchangeRate] { ratesStore.rates }

    // MARK: - Dependencies

    private let preferences: PreferencesStore
    private let historyBase: HistoryBaseCurrencyStore
    private let ratesStore: ExchangeRatesStore
    private let favorites: CurrencyCodeListStore
    private let watchlist: CurrencyCodeListStore
    private let trendsStore: TrendsStore
    private let trendDataUseCase: TrendDataUseCase
    private let loadHistoricalRates: LoadHistoricalRatesUseCase
    private let backfillArchive: BackfillArchiveUseCase
    private let buildCurrencyList: BuildCurrencyListUseCase
    private let appState: AppState
    private let makeHistoryViewModel: @MainActor (HistoryLink) -> CurrencyHistoryViewModel
    private let logger = Logger(category: .viewModel)

    @ObservationIgnored private var warmUpTask: Task<Void, Never>?
    @ObservationIgnored private var currentHistory: (link: HistoryLink, viewModel: CurrencyHistoryViewModel)?

    // MARK: - Initialization

    init(
        preferences: PreferencesStore,
        historyBase: HistoryBaseCurrencyStore,
        ratesStore: ExchangeRatesStore,
        favorites: CurrencyCodeListStore,
        watchlist: CurrencyCodeListStore,
        trendsStore: TrendsStore,
        trendDataUseCase: TrendDataUseCase,
        loadHistoricalRates: LoadHistoricalRatesUseCase,
        backfillArchive: BackfillArchiveUseCase,
        buildCurrencyList: BuildCurrencyListUseCase,
        appState: AppState,
        makeHistoryViewModel: @escaping @MainActor (HistoryLink) -> CurrencyHistoryViewModel
    ) {
        self.preferences = preferences
        self.historyBase = historyBase
        self.ratesStore = ratesStore
        self.favorites = favorites
        self.watchlist = watchlist
        self.trendsStore = trendsStore
        self.trendDataUseCase = trendDataUseCase
        self.loadHistoricalRates = loadHistoricalRates
        self.backfillArchive = backfillArchive
        self.buildCurrencyList = buildCurrencyList
        self.appState = appState
        self.makeHistoryViewModel = makeHistoryViewModel

        updateDisplayedCurrencies()
        observeListInputs()
        observeDataReset()
    }

    // MARK: - Watchlist Intents

    func isInWatchlist(_ code: CurrencyCode) -> Bool {
        watchlist.contains(code)
    }

    func toggleWatchlist(_ code: CurrencyCode) {
        watchlist.toggle(code)
        updateDisplayedCurrencies()
    }

    func removeFromWatchlist(atOffsets offsets: IndexSet) {
        offsets.map { displayedCurrencies[$0].code }.forEach { watchlist.remove($0) }
        updateDisplayedCurrencies()
    }

    func moveWatchlist(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var order = displayedCurrencies.map(\.code)
        order.move(fromOffsets: offsets, toOffset: destination)
        watchlist.reorder(displayedOrder: order)
        updateDisplayedCurrencies()
    }

    // MARK: - Base Currency

    func baseCurrencyTapped() {
        destination = .basePicker
    }

    func selectBase(_ code: CurrencyCode) {
        historyBase.pick(code)
        updateDisplayedCurrencies()
    }

    private func isListedInRates(_ code: CurrencyCode) -> Bool {
        ratesStore.rates.isEmpty || ratesStore.rates.contains { $0.currencyCode == code }
    }

    // MARK: - Navigation

    func openHistory(for code: CurrencyCode) {
        selection = HistoryRoute(HistoryLink(base: baseCurrency, target: code))
    }

    func open(_ link: HistoryLink) {
        appState.selectedTab = .history
        destination = nil
        selection = HistoryRoute(link)
    }

    func historyViewModel(for link: HistoryLink) -> CurrencyHistoryViewModel {
        if let currentHistory, currentHistory.link == link {
            return currentHistory.viewModel
        }
        let viewModel = makeHistoryViewModel(link)
        currentHistory = (link, viewModel)
        return viewModel
    }

    // MARK: - Trends

    func trend(for code: CurrencyCode) -> Trend? {
        trendDataUseCase.adjustedTrend(for: code, baseCurrency: baseCurrency, in: trendsStore.trends)
    }

    func trendDisplayValue(rate: Double, weeklyChange: Double) -> String {
        switch trendDisplayMode {
        case .percentChange:
            (abs(weeklyChange) / 100).formatted(.percent.precision(.fractionLength(2)))
        case .priceChange:
            abs(RateMath.priceChange(rate: rate, percentChange: weeklyChange)).rateText(matching: rate)
        }
    }

    // MARK: - Warm-up

    @discardableResult
    func warmUp() -> Task<Void, Never> {
        warmUpTask?.cancel()
        let task = Task { await runWarmUp() }
        warmUpTask = task
        return task
    }

    private func runWarmUp() async {
        await initializeTrends()
        guard !Task.isCancelled else { return }
        let fetchedRanges = await loadHistoricalRates.prefetchResidentYear()
        guard !Task.isCancelled else { return }
        await refreshTrends(after: fetchedRanges)
        guard !Task.isCancelled else { return }
        await backfillArchive.backfillArchive()
    }

    private func initializeTrends() async {
        do {
            let trends = try await trendDataUseCase.initializeTrendData()
            guard !Task.isCancelled else { return }
            trendsStore.replace(with: trends)
        } catch {
            logger.error("Trend warm-up failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshTrends(after fetchedRanges: [DateRange]) async {
        guard !fetchedRanges.isEmpty else { return }
        let trends = await trendDataUseCase.checkAndRecalculateTrendsIfNeeded(for: fetchedRanges)
        guard !Task.isCancelled, !trends.isEmpty else { return }
        trendsStore.replace(with: trends)
    }

    // MARK: - Shared State

    private func observeListInputs() {
        withObservationTracking {
            _ = ratesStore.rates
            _ = watchlist.codes
            _ = trendsStore.trends
            _ = baseCurrency
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                updateDisplayedCurrencies()
                observeListInputs()
            }
        }
    }

    private func observeDataReset() {
        withObservationTracking {
            _ = appState.dataResetCount
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                trendsStore.replace(with: [])
                warmUp()
                observeDataReset()
            }
        }
    }

    // MARK: - Currency List

    private func updateDisplayedCurrencies() {
        displayedCurrencies = currencyList(searchText: searchText, sortOption: sortOption)
        defaultChartCurrency = currencyList(searchText: "", sortOption: .manual).first?.code
    }

    private func currencyList(searchText: String, sortOption: CurrencySortOption) -> [CurrencyListEntry] {
        buildCurrencyList(
            rates: ratesStore.rates,
            base: baseCurrency,
            isSearching: !searchText.isEmpty,
            searchText: searchText,
            isWatchlisted: { self.watchlist.contains($0) },
            watchlistOrder: watchlist.codes.elements,
            sortOption: sortOption,
            weeklyChange: { self.trend(for: $0)?.weeklyChange ?? 0 }
        )
    }
}
