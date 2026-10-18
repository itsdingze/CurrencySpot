import Foundation
import IdentifiedCollections
import OSLog
import Observation
import SwiftUI

// MARK: - CurrencyListViewModel

@Observable
final class CurrencyListViewModel {
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

    var path: [CurrencyCode] = []

    var isSearching: Bool { !searchText.isEmpty }

    var isWatchlistEmpty: Bool { watchlist.codes.isEmpty }

    var baseCurrency: CurrencyCode { ratesStore.baseCurrency }

    // MARK: - Dependencies

    private let ratesStore: ExchangeRatesStore
    private let watchlist: CurrencyCodeListStore
    private let trendsStore: TrendsStore
    private let trendDataUseCase: TrendDataUseCase
    private let loadHistoricalRates: LoadHistoricalRatesUseCase
    private let backfillArchive: BackfillArchiveUseCase
    private let buildCurrencyList: BuildCurrencyListUseCase
    private let appState: AppState
    private let makeHistoryViewModel: @MainActor (CurrencyCode, CurrencyCode) -> CurrencyHistoryViewModel
    private let logger = Logger(category: .viewModel)

    @ObservationIgnored private var warmUpTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        ratesStore: ExchangeRatesStore,
        watchlist: CurrencyCodeListStore,
        trendsStore: TrendsStore,
        trendDataUseCase: TrendDataUseCase,
        loadHistoricalRates: LoadHistoricalRatesUseCase,
        backfillArchive: BackfillArchiveUseCase,
        buildCurrencyList: BuildCurrencyListUseCase,
        appState: AppState,
        makeHistoryViewModel: @escaping @MainActor (_ base: CurrencyCode, _ target: CurrencyCode) -> CurrencyHistoryViewModel
    ) {
        self.ratesStore = ratesStore
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

    // MARK: - Navigation

    func openHistory(for code: CurrencyCode) {
        path.append(code)
    }

    func historyViewModel(for target: CurrencyCode) -> CurrencyHistoryViewModel {
        makeHistoryViewModel(ratesStore.baseCurrency, target)
    }

    // MARK: - Trends

    func trend(for code: CurrencyCode) -> Trend? {
        trendDataUseCase.adjustedTrend(for: code, baseCurrency: ratesStore.baseCurrency, in: trendsStore.trends)
    }

    func trendDisplayValue(rate: Double, weeklyChange: Double) -> String {
        switch trendDisplayMode {
        case .percentChange:
            (abs(weeklyChange) / 100).formatted(.percent.precision(.fractionLength(2)))
        case .priceChange:
            abs(RateMath.priceChange(rate: rate, percentChange: weeklyChange)).toStringMax4Decimals
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
        await loadHistoricalRates.prefetchResidentYear()
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

    // MARK: - Shared State

    private func observeListInputs() {
        withObservationTracking {
            _ = ratesStore.rates
            _ = ratesStore.baseCurrency
            _ = watchlist.codes
            _ = trendsStore.trends
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
        displayedCurrencies = buildCurrencyList(
            rates: ratesStore.rates,
            base: ratesStore.baseCurrency,
            isSearching: isSearching,
            searchText: searchText,
            isWatchlisted: { self.watchlist.contains($0) },
            watchlistOrder: watchlist.codes.elements,
            sortOption: sortOption,
            weeklyChange: { self.trend(for: $0)?.weeklyChange ?? 0 }
        )
    }
}
