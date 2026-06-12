//
//  HistoryViewModel.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/25/25.
//

import Foundation
import SwiftUI

// MARK: - HistoryViewModel

@Observable
final class HistoryViewModel {
    // MARK: - Chart State

    /// Lifecycle of the displayed chart series. `.loading` keeps the previous
    /// points so the chart never blanks during a range or currency change.
    private(set) var chartData: Loadable<[ChartDataPoint]> = .idle

    /// Currently displayed chart data points (filtered and sampled).
    var displayedChartDataPoints: [ChartDataPoint] {
        chartData.value ?? []
    }

    /// Statistics for the displayed points, recomputed only when they change
    /// (previously recomputed per access, up to 9x per render).
    private(set) var chartStatistics: ChartStatistics

    /// Debounced loading indicator over the chart: appears only when a load
    /// outlasts the debounce, and stays for a minimum duration so it never flickers.
    private(set) var showLoadingOverlay = false

    /// Cache for date range calculation to avoid redundant operations
    private var _cachedDateRange: DateRange?
    private var _cachedTimeRange: TimeRange?

    // MARK: Configuration Properties

    /// Base currency (left side of conversion). Stays String at the UI edge;
    /// follows the calculator's selection via the shared rates store.
    private(set) var baseCurrency = "USD"

    /// Target currency (right side of conversion)
    private(set) var targetCurrency = "EUR"

    /// Selected time range for historical data display
    private(set) var selectedTimeRange: TimeRange = .threeMonths

    /// The series the published chart points answer for. Part of each mark's
    /// identity, so a currency or range switch never matches marks across
    /// datasets — the chart crossfades whole series through the animating
    /// scales — while a same-series refresh keeps date identity and morphs
    /// in place. Updated atomically with the points in `publishChart`:
    /// deriving it from `selectedTimeRange` directly would re-key the OLD
    /// points the moment the user taps a range, and overlapping dates would
    /// match again when the new data lands.
    private(set) var chartSeriesID = ChartSeriesID(currency: "", range: .threeMonths)

    nonisolated struct ChartSeriesID: Hashable, Sendable {
        let currency: String
        let range: TimeRange
    }

    // MARK: UI State Properties

    /// Toggle states for chart elements
    var showAverageLine = false
    var showHighestPoint = false
    var showLowestPoint = false

    /// First-visit chart onboarding sheet (set after a short delay on entry).
    var isChartOnboardingPresented = false

    // MARK: Currency List State

    /// Cached filter/sort result for the currency list, recomputed when the
    /// search text, sort option, or shared rates change — not per body pass.
    private(set) var displayedCurrencies: [CurrencyListEntry] = []

    var searchText = "" {
        didSet {
            if oldValue != searchText {
                updateDisplayedCurrencies()
            }
        }
    }

    private(set) var sortOption: CurrencySortOption = .nameAZ

    // MARK: - Trend Data Storage

    /// In-memory storage for trend data (converted to value types)
    private(set) var trendData: [Trend] = []

    // MARK: Dependencies

    /// Shared read-only snapshot of the calculator's current rates and base selection.
    private let ratesStore: ExchangeRatesStore

    /// Use cases for business logic
    private let dataOrchestrationUseCase: DataOrchestrationUseCase
    private let historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase
    private let chartDataPreparationUseCase: ChartDataPreparationUseCase
    private let trendDataUseCase: TrendDataUseCase

    /// App-wide state (network reachability, error handling)
    private let appState: AppState

    private let clock: ClockService
    private let logger: LoggerService

    /// Current async task for data fetching (for cancellation)
    private var fetchTask: Task<Void, Never>?

    /// Drives the debounced show/hide of the loading overlay.
    private var loadingOverlayTask: Task<Void, Never>?

    /// Monotonically increasing load generation. Only the task carrying the latest
    /// generation may publish state, clear `fetchTask`, or end the loading indicator.
    private var loadGeneration = 0

    // MARK: - Initialization

    /// Initializes the HistoryViewModel with dependency injection
    init(
        ratesStore: ExchangeRatesStore,
        historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase,
        dataOrchestrationUseCase: DataOrchestrationUseCase,
        chartDataPreparationUseCase: ChartDataPreparationUseCase,
        trendDataUseCase: TrendDataUseCase,
        appState: AppState = .shared,
        clock: ClockService = ContinuousClockService(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.ratesStore = ratesStore
        self.historicalDataAnalysisUseCase = historicalDataAnalysisUseCase
        self.dataOrchestrationUseCase = dataOrchestrationUseCase
        self.chartDataPreparationUseCase = chartDataPreparationUseCase
        self.trendDataUseCase = trendDataUseCase
        self.appState = appState
        self.clock = clock
        self.logger = logger

        chartStatistics = chartDataPreparationUseCase.calculateStatistics(from: [])
        baseCurrency = ratesStore.baseCurrency
        updateDisplayedCurrencies()
        observeSharedRates()
    }

    // MARK: - Shared Rates Sync

    /// Follows the calculator's base selection and published rates through the
    /// shared store, replacing the previous view-driven onAppear/onChange syncing.
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

    // MARK: - Intents

    /// Switches the displayed time range and reloads once.
    func selectTimeRange(_ timeRange: TimeRange) {
        guard timeRange != selectedTimeRange else { return }
        selectedTimeRange = timeRange
        invalidateDateRangeCache()
        loadDataForCurrentConfiguration()
    }

    /// Switches the currency-list sort order and recomputes the cached list.
    func selectSortOption(_ option: CurrencySortOption) {
        guard option != sortOption else { return }
        sortOption = option
        updateDisplayedCurrencies()
    }

    /// List-row tap: targets the picked currency against the shared base and
    /// reloads exactly once.
    func openHistory(for currencyCode: String) {
        configure(base: ratesStore.baseCurrency, target: currencyCode)
    }

    /// Presents the chart onboarding sheet after a short delay on first entry.
    /// Cancellation (leaving the screen within the delay) suppresses it.
    func presentChartOnboardingIfNeeded(hasSeenChartOnboarding: Bool) async {
        guard !hasSeenChartOnboarding else { return }
        try? await clock.sleep(for: .seconds(0.5))
        guard !Task.isCancelled else { return }
        isChartOnboardingPresented = true
    }

    // MARK: - Public Interface

    /// Applies a new currency pair and reloads exactly once.
    func configure(base: String, target: String) {
        baseCurrency = base
        targetCurrency = target
        resetDisplayedDataAndTimeRange()
    }

    /// Resets displayed data and time range (called when navigating to new currency)
    func resetDisplayedDataAndTimeRange() {
        // Cancel any existing fetch task to prevent race conditions
        fetchTask?.cancel()
        fetchTask = nil

        // Reset data and UI state
        publishChart(.idle)
        selectedTimeRange = .threeMonths
        invalidateDateRangeCache()
        showAverageLine = false
        showHighestPoint = false
        showLowestPoint = false

        // Start fresh load
        loadDataForCurrentConfiguration()
    }

    /// Resets published state after the cross-cutting clear (RefreshAllDataUseCase
    /// wipes the repository, including caches, before signalling this).
    func clearAllData() {
        publishChart(.idle)
        trendData = []
    }

    // MARK: - Data Loading

    /// Main data loading method - simplified to use DataOrchestrationUseCase.
    /// Cancel-and-replace: a new request supersedes any in-flight load, and only
    /// the latest generation may publish state.
    func loadDataForCurrentConfiguration() {
        fetchTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration

        fetchTask = Task {
            await runLoad(generation: generation)
        }
    }

    /// Triggers a load for the current configuration and awaits its completion.
    /// Awaitable counterpart to `loadDataForCurrentConfiguration()` for callers that must
    /// sequence work after a load finishes (and for deterministic tests).
    func loadCurrentConfigurationAndWait() async {
        loadDataForCurrentConfiguration()
        // `loadDataForCurrentConfiguration()` assigns `fetchTask` synchronously,
        // so this awaits exactly the task created above.
        await fetchTask?.value
    }

    private func runLoad(generation: Int) async {
        guard generation == loadGeneration, !Task.isCancelled else { return }

        guard let currency = CurrencyCode(targetCurrency) else {
            publishChart(.failed(.dataValidationError("No historical data available for this currency"), previous: nil))
            return
        }

        publishChart(.loading(previous: chartData.value))

        let dateRange = calculateDateRange()

        do {
            // Use DataOrchestrationUseCase to handle all the complex logic
            let result = try await dataOrchestrationUseCase.loadHistoricalData(
                for: currency,
                base: CurrencyCode(baseCurrency) ?? .usd,
                dateRange: dateRange
            )
            guard generation == loadGeneration, !Task.isCancelled else { return }

            // Always try to update chart even with partial data
            if !result.dataPoints.isEmpty {
                // Chart from the returned rows: archive ranges never enter the
                // resident series, so re-reading the cache would come up empty.
                let dataPoints = await preparedChartDataPoints(for: currency, from: result.dataPoints, dateRange: dateRange)
                guard generation == loadGeneration, !Task.isCancelled else { return }
                publishChart(.loaded(dataPoints))
            } else {
                // No data available, but don't treat as error
                logger.infoPrivate("No historical data available for \(currency)", category: .viewModel)
                publishChart(.loaded([]))
            }

            // Update trends if new data was fetched
            if result.newDataFetched {
                logger.info("New data fetched, updating trends...", category: .viewModel)
                // Use the actually fetched ranges, not the requested range
                let trends = await trendDataUseCase.checkAndRecalculateTrendsIfNeeded(
                    for: result.fetchedRanges
                )
                guard generation == loadGeneration, !Task.isCancelled else { return }
                trendData = trends
            }

            fetchTask = nil

        } catch is CancellationError {
            logger.debug("Fetch cancelled", category: .viewModel)
            guard generation == loadGeneration else { return }
            fetchTask = nil
            // End the loading phase without discarding what is on screen.
            publishChart(.loaded(chartData.value ?? []))
        } catch {
            logger.error("Load failed: \(error.localizedDescription)", category: .viewModel)

            // Try to use cached data even if the load failed — except for archive
            // ranges: the resident series can never legitimately cover them, and
            // falling back would render ~1Y of points as a loaded 5Y chart.
            let cachedData = DataOrchestrationUseCase.isArchiveRange(dateRange)
                ? []
                : await dataOrchestrationUseCase.getCachedData(dateRange: dateRange)
            guard generation == loadGeneration, !Task.isCancelled else { return }

            if !cachedData.isEmpty {
                // We have some cached data, use it
                logger.info("Using cached data as fallback", category: .viewModel)
                let dataPoints = await preparedChartDataPoints(for: currency, from: cachedData, dateRange: dateRange)
                guard generation == loadGeneration, !Task.isCancelled else { return }
                publishChart(.loaded(dataPoints))
            } else {
                // No cached data available - use centralized error handling
                let appError = AppError.from(error) ?? AppError.networkError("Failed to load historical data")
                appState.errorHandler.handle(appError)
                publishChart(.failed(appError, previous: nil))
            }

            fetchTask = nil
        }
    }

    // MARK: - Chart Publishing

    /// Single funnel for chart-state changes: keeps the cached statistics in
    /// sync and drives the debounced loading overlay on phase transitions.
    private func publishChart(_ newState: Loadable<[ChartDataPoint]>) {
        let wasLoading = chartData.isLoading
        chartData = newState
        if case .loaded = newState {
            chartSeriesID = ChartSeriesID(currency: targetCurrency, range: selectedTimeRange)
        }
        chartStatistics = chartDataPreparationUseCase.calculateStatistics(from: newState.value ?? [])

        if wasLoading != newState.isLoading {
            loadingPhaseChanged(isLoading: newState.isLoading)
        }
    }

    /// Sub-quarter-second loads show no overlay at all (with the warmed shared series
    /// that is nearly every load), and an overlay that did appear lingers just long
    /// enough not to read as a flicker.
    private enum LoadingOverlayTiming {
        static let showDebounce: Duration = .seconds(0.25)
        static let minimumDisplay: Duration = .seconds(0.15)
    }

    /// Debounce/minimum-duration state machine for the chart loading overlay,
    /// previously inlined in ChartSection with raw `Task.sleep`.
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
        let base = ratesStore.baseCurrency
        let rates = ratesStore.rates
        let baseRate = rates.first { $0.currencyCode.rawValue == base }?.rate ?? 1.0

        var entries = rates
            .filter { $0.currencyCode.rawValue != base }
            .map { rate in
                CurrencyListEntry(
                    code: rate.currencyCode.rawValue,
                    name: CurrencyUtilities.name(for: rate.currencyCode.rawValue),
                    rate: rate.rate / baseRate
                )
            }

        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.code.localizedStandardContains(searchText) ||
                    entry.name.localizedStandardContains(searchText)
            }
        }

        displayedCurrencies = switch sortOption {
        case .nameAZ: entries.sorted { $0.name < $1.name }
        case .rateHighToLow: entries.sorted { $0.rate > $1.rate }
        case .rateLowToHigh: entries.sorted { $0.rate < $1.rate }
        }
    }

    // MARK: - Prefetch

    /// Warms the shared historical series with a today-anchored one-year window so
    /// chart opens, range switches within a year, and currency switches all render
    /// from memory — then backfills the five-year archive into the blob store
    /// (persistence only; the resident series and published chart state stay
    /// untouched). Runs from the app root task after the trend seed; on first launch
    /// the archive tier is a multi-year download, so nothing latency-sensitive may
    /// sequence behind this call. Offline it still warms the series from persistence.
    func prefetchHistoricalWindow() async {
        let range = historicalDataAnalysisUseCase.calculateDateRange(for: .oneYear)
        do {
            // USD rows carry every currency's rate, so one warm pass covers all charts.
            _ = try await dataOrchestrationUseCase.loadHistoricalData(for: .usd, dateRange: range)
        } catch {
            // Purely opportunistic: the next chart open loads on demand as before.
            logger.debug("Historical prefetch did not complete: \(error.localizedDescription)", category: .viewModel)
        }

        // Final warm-up tier: the five-year archive lands in persistence only, after
        // which 5Y charts read from the blob store instead of bridging via the network.
        await dataOrchestrationUseCase.backfillArchive()
    }

    // MARK: - Trend Data Methods

    /// Initializes trend data using TrendDataUseCase; failures surface through the
    /// injected error handler (the use case no longer reaches into AppState).
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

    /// Gets trend data for a specific currency, adjusted for the current base currency
    func getTrendData(for currencyCode: String) -> Trend? {
        guard let code = CurrencyCode(currencyCode), let base = CurrencyCode(baseCurrency) else {
            return nil
        }
        return trendDataUseCase.adjustedTrend(for: code, baseCurrency: base, in: trendData)
    }

    // MARK: - Date Range Calculations

    private func invalidateDateRangeCache() {
        _cachedDateRange = nil
        _cachedTimeRange = nil
    }

    /// Calculates the date range based on selected time range with caching
    private func calculateDateRange() -> DateRange {
        // Return cached result if time range hasn't changed
        if let cached = _cachedDateRange,
           let cachedTimeRange = _cachedTimeRange,
           cachedTimeRange == selectedTimeRange
        {
            return cached
        }

        let range = historicalDataAnalysisUseCase.calculateDateRange(for: selectedTimeRange)

        // Cache the result
        _cachedDateRange = range
        _cachedTimeRange = selectedTimeRange

        return range
    }

    // MARK: - Chart Data Processing

    /// Prepares chart data points based on current currency pair and time range.
    /// Returns the points instead of publishing them so the caller can apply its
    /// generation/cancellation guard before any state write.
    /// - Parameter dateRange: The date range to use for filtering data (must match the range used for fetching)
    private func preparedChartDataPoints(for currency: CurrencyCode, from historicalData: [HistoricalRateSnapshot], dateRange: DateRange) async -> [ChartDataPoint] {
        // Guard against empty data
        guard !historicalData.isEmpty else {
            logger.info("No historical data to display", category: .viewModel)
            return []
        }

        guard let base = CurrencyCode(baseCurrency) else { return [] }

        let fullDataPoints = await chartDataPreparationUseCase.processHistoricalRateData(
            historicalData: historicalData,
            baseCurrency: base,
            targetCurrency: currency,
            dateRange: dateRange,
            exchangeRates: ratesStore.rates
        )

        // Only return if we have valid data points
        guard !fullDataPoints.isEmpty else {
            logger.warning("No valid chart data points after processing", category: .viewModel)
            return []
        }

        return chartDataPreparationUseCase.sampleDataPoints(from: fullDataPoints)
    }

    // MARK: - Computed Properties (Statistics)

    /// Current exchange rate (most recent data point)
    var currentRate: Double {
        chartStatistics.currentRate
    }

    /// Highest exchange rate in the current time range
    var highestRate: Double {
        chartStatistics.highestRate
    }

    /// Lowest exchange rate in the current time range
    var lowestRate: Double {
        chartStatistics.lowestRate
    }

    /// Average exchange rate in the current time range
    var averageRate: Double {
        chartStatistics.averageRate
    }

    /// Price change from first to last data point
    var priceChange: Double? {
        chartStatistics.priceChange
    }

    /// Percentage change from first to last data point
    var percentChange: Double? {
        chartStatistics.percentChange
    }

    /// Trend direction based on percentage change with stable threshold
    var trendDirection: TrendDirection {
        chartStatistics.trendDirection
    }

    /// Volatility (annualized standard deviation of returns)
    var volatility: Double? {
        chartStatistics.volatility
    }

    // MARK: - Computed Properties (Formatted Display Values)

    /// Formatted string for current exchange rate
    var formattedCurrentRate: String {
        "1 \(baseCurrency) = \(currentRate.toStringMax4Decimals) \(targetCurrency)"
    }

    /// Formatted string for highest exchange rate
    var formattedHighestRate: String {
        highestRate.toStringMax4Decimals
    }

    /// Formatted string for lowest exchange rate
    var formattedLowestRate: String {
        lowestRate.toStringMax4Decimals
    }

    /// Formatted string for average exchange rate
    var formattedAverageRate: String {
        averageRate.toStringMax4Decimals
    }

    /// Volatility classified into a qualitative level (nil when volatility is unavailable).
    var volatilityLevel: VolatilityLevel? {
        volatility.map(VolatilityLevel.init(annualizedPercent:))
    }

    /// Formatted string for volatility with interpretation
    var formattedVolatility: String {
        volatilityLevel?.displayName ?? "N/A"
    }

    // MARK: - Computed Properties (Chart Configuration)

    /// Y-axis domain for chart display with padding
    var chartYDomain: ClosedRange<Double> {
        chartStatistics.chartYDomain
    }
}
