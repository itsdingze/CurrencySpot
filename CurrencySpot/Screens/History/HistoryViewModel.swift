import Foundation
import SwiftUI

// MARK: - HistoryViewModel

@Observable
final class HistoryViewModel {
    // MARK: - Chart State

    private(set) var chartData: Loadable<[ChartDataPoint]> = .idle

    private(set) var displayedChartDataPoints: [ChartDataPoint] = []

    private(set) var chartStatistics: ChartStatistics

    private(set) var showLoadingOverlay = false

    private var cachedDateRange: DateRange?
    private var cachedTimeRange: TimeRange?

    // MARK: - Configuration Properties

    private(set) var baseCurrency = CurrencyCode.usd

    private(set) var targetCurrency = CurrencyCode.eur

    private(set) var selectedTimeRange: TimeRange = .threeMonths

    private(set) var chartSeriesID = ChartSeriesID(currency: .usd, range: .threeMonths)

    nonisolated struct ChartSeriesID: Hashable, Sendable {
        let currency: CurrencyCode
        let range: TimeRange
    }

    // MARK: - UI State Properties

    nonisolated enum Destination: Equatable {
        case chartOnboarding
        case volatilityInfo
    }

    var path: [CurrencyCode] = []

    var destination: Destination?

    var showAverageLine = false
    var showHighestPoint = false
    var showLowestPoint = false

    // MARK: - Currency List State

    private(set) var displayedCurrencies: [CurrencyListEntry] = []

    var searchText = "" {
        didSet {
            if oldValue != searchText {
                updateDisplayedCurrencies()
            }
        }
    }

    private(set) var sortOption: CurrencySortOption = .manual

    private(set) var trendDisplayMode: TrendDisplayMode = .percentChange

    var isSearching: Bool { !searchText.isEmpty }

    var isWatchlistEmpty: Bool { watchlist.codes.isEmpty }

    // MARK: - Trend Data Storage

    private(set) var trendData: [Trend] = [] {
        didSet { updateDisplayedCurrencies() }
    }

    // MARK: - Dependencies

    private let ratesStore: ExchangeRatesStore

    private let watchlist: WatchlistStore

    private let dataOrchestrationUseCase: DataOrchestrationUseCase
    private let historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase
    private let chartDataPreparationUseCase: ChartDataPreparationUseCase
    private let trendDataUseCase: TrendDataUseCase
    private let buildCurrencyList: BuildCurrencyListUseCase

    private let preferences: PreferencesStore

    private let appState: AppState

    private let clock: ClockService
    private let logger: LoggerService

    private var fetchTask: Task<Void, Never>?

    private var loadingOverlayTask: Task<Void, Never>?

    private var loadGeneration = 0

    // MARK: - Initialization

    init(
        ratesStore: ExchangeRatesStore,
        watchlist: WatchlistStore,
        historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase,
        dataOrchestrationUseCase: DataOrchestrationUseCase,
        chartDataPreparationUseCase: ChartDataPreparationUseCase,
        trendDataUseCase: TrendDataUseCase,
        buildCurrencyList: BuildCurrencyListUseCase = BuildCurrencyListUseCase(),
        preferences: PreferencesStore,
        appState: AppState = .shared,
        clock: ClockService = ContinuousClockService(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.ratesStore = ratesStore
        self.watchlist = watchlist
        self.historicalDataAnalysisUseCase = historicalDataAnalysisUseCase
        self.dataOrchestrationUseCase = dataOrchestrationUseCase
        self.chartDataPreparationUseCase = chartDataPreparationUseCase
        self.trendDataUseCase = trendDataUseCase
        self.buildCurrencyList = buildCurrencyList
        self.preferences = preferences
        self.appState = appState
        self.clock = clock
        self.logger = logger

        chartStatistics = chartDataPreparationUseCase.calculateStatistics(from: [])
        baseCurrency = ratesStore.baseCurrency
        updateDisplayedCurrencies()
        observeSharedRates()
        observeWatchlist()
    }

    // MARK: - Shared Rates Sync

    private func observeSharedRates() {
        withObservationTracking {
            _ = ratesStore.baseCurrency
            _ = ratesStore.rates
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                sharedRatesChanged()
                observeSharedRates()
            }
        }
    }

    private func sharedRatesChanged() {
        updateDisplayedCurrencies()

        let newBase = ratesStore.baseCurrency
        if baseCurrency != newBase {
            baseCurrency = newBase
            loadDataForCurrentConfiguration()
        }
    }

    // MARK: - Watchlist Sync

    private func observeWatchlist() {
        withObservationTracking {
            _ = watchlist.codes
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                updateDisplayedCurrencies()
                observeWatchlist()
            }
        }
    }

    // MARK: - Intents

    func selectTimeRange(_ timeRange: TimeRange) {
        guard timeRange != selectedTimeRange else { return }
        selectedTimeRange = timeRange
        invalidateDateRangeCache()
        loadDataForCurrentConfiguration()
    }

    func selectSortOption(_ option: CurrencySortOption) {
        guard option != sortOption else { return }
        sortOption = option
        updateDisplayedCurrencies()
    }

    func selectTrendDisplayMode(_ mode: TrendDisplayMode) {
        guard mode != trendDisplayMode else { return }
        trendDisplayMode = mode
    }

    func trendDisplayValue(rate: Double, weeklyChange: Double) -> String {
        switch trendDisplayMode {
        case .percentChange:
            abs(weeklyChange).formatted(.number.precision(.fractionLength(2))) + "%"
        case .priceChange:
            abs(RateMath.priceChange(rate: rate, percentChange: weeklyChange)).toStringMax4Decimals
        }
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
        let codes = offsets.map { displayedCurrencies[$0].code }
        codes.forEach { watchlist.remove($0) }
        updateDisplayedCurrencies()
    }

    func moveWatchlist(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var order = displayedCurrencies.map(\.code)
        order.move(fromOffsets: offsets, toOffset: destination)
        watchlist.reorder(displayedOrder: order)
        updateDisplayedCurrencies()
    }

    func openHistory(for currencyCode: CurrencyCode) {
        configure(base: ratesStore.baseCurrency, target: currencyCode)
        path.append(currencyCode)
    }

    func volatilityInfoTapped() {
        destination = .volatilityInfo
    }

    func presentChartOnboardingIfNeeded() async {
        guard !preferences.hasSeenChartOnboarding else { return }
        try? await clock.sleep(for: .seconds(0.5))
        guard !Task.isCancelled else { return }
        destination = .chartOnboarding
    }

    func completeChartOnboarding() {
        preferences.hasSeenChartOnboarding = true
        destination = nil
    }

    // MARK: - Public Interface

    func configure(base: CurrencyCode, target: CurrencyCode) {
        baseCurrency = base
        targetCurrency = target
        resetDisplayedDataAndTimeRange()
    }

    func resetDisplayedDataAndTimeRange() {
        fetchTask?.cancel()
        fetchTask = nil

        publishChart(.idle)
        selectedTimeRange = .threeMonths
        invalidateDateRangeCache()
        showAverageLine = false
        showHighestPoint = false
        showLowestPoint = false

        loadDataForCurrentConfiguration()
    }

    func clearAllData() {
        publishChart(.idle)
        trendData = []
    }

    // MARK: - Data Loading

    func loadDataForCurrentConfiguration() {
        fetchTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration

        fetchTask = Task {
            await runLoad(generation: generation)
        }
    }

    func loadCurrentConfigurationAndWait() async {
        loadDataForCurrentConfiguration()
        await fetchTask?.value
    }

    private func runLoad(generation: Int) async {
        guard generation == loadGeneration, !Task.isCancelled else { return }

        let currency = targetCurrency

        publishChart(.loading(previous: chartData.value))

        let dateRange = calculateDateRange()

        do {
            let result = try await dataOrchestrationUseCase.loadHistoricalData(
                for: currency,
                base: baseCurrency,
                dateRange: dateRange
            )
            guard generation == loadGeneration, !Task.isCancelled else { return }
            await publishLoadedResult(result, generation: generation, currency: currency, dateRange: dateRange)
        } catch is CancellationError {
            logger.debug("Fetch cancelled", category: .viewModel)
            guard generation == loadGeneration else { return }
            fetchTask = nil
            publishChart(.loaded(chartData.value ?? []))
        } catch {
            await recoverFromLoadFailure(error, generation: generation, currency: currency, dateRange: dateRange)
        }
    }

    private func publishLoadedResult(
        _ result: HistoricalLoadResult,
        generation: Int,
        currency: CurrencyCode,
        dateRange: DateRange
    ) async {
        if !result.snapshots.isEmpty {
            let dataPoints = await preparedChartDataPoints(for: currency, from: result.snapshots, dateRange: dateRange)
            guard generation == loadGeneration, !Task.isCancelled else { return }
            publishChart(.loaded(dataPoints))
        } else {
            logger.infoPrivate("No historical data available for \(currency)", category: .viewModel)
            publishChart(.loaded([]))
        }

        if result.newDataFetched {
            logger.info("New data fetched, updating trends...", category: .viewModel)
            let trends = await trendDataUseCase.checkAndRecalculateTrendsIfNeeded(
                for: result.fetchedRanges
            )
            guard generation == loadGeneration, !Task.isCancelled else { return }
            trendData = trends
        }

        fetchTask = nil
    }

    private func recoverFromLoadFailure(
        _ error: Error,
        generation: Int,
        currency: CurrencyCode,
        dateRange: DateRange
    ) async {
        logger.error("Load failed: \(error.localizedDescription)", category: .viewModel)

        let cachedData = DataOrchestrationUseCase.isArchiveRange(dateRange)
            ? []
            : await dataOrchestrationUseCase.getCachedData(dateRange: dateRange)
        guard generation == loadGeneration, !Task.isCancelled else { return }

        if !cachedData.isEmpty {
            logger.info("Using cached data as fallback", category: .viewModel)
            let dataPoints = await preparedChartDataPoints(for: currency, from: cachedData, dateRange: dateRange)
            guard generation == loadGeneration, !Task.isCancelled else { return }
            publishChart(.loaded(dataPoints))
        } else {
            let appError = AppError.from(error) ?? AppError.networkError("Failed to load historical data")
            appState.errorHandler.handle(appError)
            publishChart(.failed(appError, previous: nil))
        }

        fetchTask = nil
    }

    // MARK: - Chart Publishing

    private func publishChart(_ newState: Loadable<[ChartDataPoint]>) {
        let wasLoading = chartData.isLoading
        chartData = newState
        if case .loaded = newState {
            chartSeriesID = ChartSeriesID(currency: targetCurrency, range: selectedTimeRange)
        }
        let series = newState.value ?? []
        displayedChartDataPoints = chartDataPreparationUseCase.sampleDataPoints(from: series)
        chartStatistics = chartDataPreparationUseCase.calculateStatistics(from: series)

        if wasLoading != newState.isLoading {
            loadingPhaseChanged(isLoading: newState.isLoading)
        }
    }

    private enum LoadingOverlayTiming {
        static let showDebounce: Duration = .seconds(0.25)
        static let minimumDisplay: Duration = .seconds(0.15)
    }

    private func loadingPhaseChanged(isLoading: Bool) {
        loadingOverlayTask?.cancel()

        if isLoading {
            loadingOverlayTask = Task {
                try? await clock.sleep(for: LoadingOverlayTiming.showDebounce)
                guard !Task.isCancelled else { return }
                withAnimation(.appQuickFade) {
                    showLoadingOverlay = true
                }
            }
        } else if showLoadingOverlay {
            loadingOverlayTask = Task {
                try? await clock.sleep(for: LoadingOverlayTiming.minimumDisplay)
                guard !Task.isCancelled else { return }
                withAnimation(.appQuickFade) {
                    showLoadingOverlay = false
                }
            }
        } else {
            showLoadingOverlay = false
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
            weeklyChange: { self.weeklyChange(for: $0) }
        )
    }

    private func weeklyChange(for code: CurrencyCode) -> Double {
        getTrendData(for: code)?.weeklyChange ?? 0
    }

    // MARK: - Prefetch

    func prefetchHistoricalWindow() async {
        let range = historicalDataAnalysisUseCase.calculateDateRange(for: .oneYear)
        do {
            _ = try await dataOrchestrationUseCase.loadHistoricalData(for: .usd, dateRange: range)
        } catch {
            logger.debug("Historical prefetch did not complete: \(error.localizedDescription)", category: .viewModel)
        }

        await dataOrchestrationUseCase.backfillArchive()
    }

    // MARK: - Trend Data Methods

    func initializeTrendData() async {
        do {
            trendData = try await trendDataUseCase.initializeTrendData()
        } catch {
            trendData = []
            if let appError = AppError.from(error) {
                appState.errorHandler.handle(appError)
            }
        }
    }

    func getTrendData(for currencyCode: CurrencyCode) -> Trend? {
        trendDataUseCase.adjustedTrend(for: currencyCode, baseCurrency: baseCurrency, in: trendData)
    }

    // MARK: - Date Range Calculations

    private func invalidateDateRangeCache() {
        cachedDateRange = nil
        cachedTimeRange = nil
    }

    private func calculateDateRange() -> DateRange {
        if let cached = cachedDateRange,
           let cachedTimeRange = cachedTimeRange,
           cachedTimeRange == selectedTimeRange
        {
            return cached
        }

        let range = historicalDataAnalysisUseCase.calculateDateRange(for: selectedTimeRange)

        cachedDateRange = range
        cachedTimeRange = selectedTimeRange

        return range
    }

    // MARK: - Chart Data Processing

    private func preparedChartDataPoints(for currency: CurrencyCode, from historicalData: [HistoricalRateSnapshot], dateRange: DateRange) async -> [ChartDataPoint] {
        guard !historicalData.isEmpty else {
            logger.info("No historical data to display", category: .viewModel)
            return []
        }

        let fullDataPoints = await chartDataPreparationUseCase.processHistoricalRateData(
            historicalData: historicalData,
            baseCurrency: baseCurrency,
            targetCurrency: currency,
            dateRange: dateRange,
            exchangeRates: ratesStore.rates
        )

        if fullDataPoints.isEmpty {
            logger.warning("No valid chart data points after processing", category: .viewModel)
        }

        return fullDataPoints
    }

}
