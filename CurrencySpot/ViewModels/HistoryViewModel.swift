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
@MainActor
final class HistoryViewModel {
    // MARK: - Properties

    /// Currently displayed chart data points (filtered and sampled)
    private(set) var displayedChartDataPoints: [ChartDataPoint] = []

    /// Cache for date range calculation to avoid redundant operations
    private var _cachedDateRange: DateRange?
    private var _cachedTimeRange: TimeRange?

    // MARK: Configuration Properties

    /// Base currency (left side of conversion). Stays String at the UI edge;
    /// follows the calculator's selection via the shared rates store.
    var baseCurrency = "USD" {
        didSet {
            if oldValue != baseCurrency, !isApplyingConfiguration {
                loadDataForCurrentConfiguration()
            }
        }
    }

    /// Target currency (right side of conversion)
    var targetCurrency = "EUR" {
        didSet {
            if oldValue != targetCurrency, !isApplyingConfiguration {
                loadDataForCurrentConfiguration()
            }
        }
    }

    /// Selected time range for historical data display
    var selectedTimeRange: TimeRange = .threeMonths {
        didSet {
            if oldValue != selectedTimeRange {
                // Clear date range cache when time range changes
                _cachedDateRange = nil
                _cachedTimeRange = nil
                if !isApplyingConfiguration {
                    loadDataForCurrentConfiguration()
                }
            }
        }
    }

    // MARK: UI State Properties

    /// Loading state for UI feedback
    private(set) var isLoading = false

    /// Error message for display in UI
    private(set) var errorMessage: String?

    /// Toggle states for chart elements
    var showAverageLine = false
    var showHighestPoint = false
    var showLowestPoint = false

    // MARK: - Trend Data Storage

    /// In-memory storage for trend data (converted to value types)
    private(set) var trendData: [TrendDataValue] = []

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

    private let logger: LoggerService

    /// Current async task for data fetching (for cancellation)
    private var fetchTask: Task<Void, Never>?

    /// Monotonically increasing load generation. Only the task carrying the latest
    /// generation may publish state, clear `fetchTask`, or end the loading indicator.
    private var loadGeneration = 0

    /// Suppresses the per-property didSet reloads while a navigation reconfiguration sets several
    /// properties at once, so one configuration triggers a single load instead of one per property.
    private var isApplyingConfiguration = false

    // MARK: - Initialization

    /// Initializes the HistoryViewModel with dependency injection
    init(
        ratesStore: ExchangeRatesStore,
        historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase,
        dataOrchestrationUseCase: DataOrchestrationUseCase,
        chartDataPreparationUseCase: ChartDataPreparationUseCase,
        trendDataUseCase: TrendDataUseCase,
        appState: AppState = .shared,
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.ratesStore = ratesStore
        self.historicalDataAnalysisUseCase = historicalDataAnalysisUseCase
        self.dataOrchestrationUseCase = dataOrchestrationUseCase
        self.chartDataPreparationUseCase = chartDataPreparationUseCase
        self.trendDataUseCase = trendDataUseCase
        self.appState = appState
        self.logger = logger

        baseCurrency = ratesStore.baseCurrency
        observeSharedBaseCurrency()
    }

    // MARK: - Shared Base Currency Sync

    /// Follows the calculator's base selection through the shared store, replacing
    /// the previous view-driven onAppear/onChange syncing.
    private func observeSharedBaseCurrency() {
        withObservationTracking {
            _ = ratesStore.baseCurrency
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newValue = ratesStore.baseCurrency
                if baseCurrency != newValue {
                    baseCurrency = newValue
                }
                observeSharedBaseCurrency()
            }
        }
    }

    // MARK: - Public Interface

    /// Applies a new currency pair and reloads exactly once. Navigation uses this so that setting the
    /// base and target currencies does not trigger a per-property load on top of the reset's load.
    func configure(base: String, target: String) {
        isApplyingConfiguration = true
        baseCurrency = base
        targetCurrency = target
        isApplyingConfiguration = false

        resetDisplayedDataAndTimeRange()
    }

    /// Resets displayed data and time range (called when navigating to new currency)
    func resetDisplayedDataAndTimeRange() {
        // Cancel any existing fetch task to prevent race conditions
        fetchTask?.cancel()
        fetchTask = nil
        isLoading = false

        // Reset data and UI state
        displayedChartDataPoints = []
        // Reset the time range without triggering its didSet load; the single load happens below.
        isApplyingConfiguration = true
        selectedTimeRange = .threeMonths
        isApplyingConfiguration = false
        _cachedDateRange = nil
        _cachedTimeRange = nil
        showAverageLine = false
        showHighestPoint = false
        showLowestPoint = false

        // Start fresh load
        loadDataForCurrentConfiguration()
    }

    /// Resets published state after the cross-cutting clear (ClearAllDataUseCase
    /// wipes the repository, including caches, before signalling this).
    func clearAllData() {
        displayedChartDataPoints = []
        trendData = []
        errorMessage = nil
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
            displayedChartDataPoints = []
            errorMessage = "No historical data available for this currency"
            return
        }

        isLoading = true
        errorMessage = nil

        let dateRange = calculateDateRange()

        do {
            // Use DataOrchestrationUseCase to handle all the complex logic
            let result = try await dataOrchestrationUseCase.loadHistoricalData(
                for: currency,
                dateRange: dateRange
            )
            guard generation == loadGeneration, !Task.isCancelled else { return }

            // Always try to update chart even with partial data
            if !result.dataPoints.isEmpty {
                // Update UI with new data (pass the same dateRange used for fetching)
                let dataPoints = await preparedChartDataPoints(for: currency, dateRange: dateRange)
                guard generation == loadGeneration, !Task.isCancelled else { return }
                displayedChartDataPoints = dataPoints

                // Clear error if we successfully got data
                errorMessage = nil
            } else {
                // No data available, but don't treat as error
                logger.infoPrivate("No historical data available for \(currency)", category: .viewModel)
                displayedChartDataPoints = []

                // Set a user-friendly message
                if !appState.networkMonitor.isConnected {
                    errorMessage = "Offline - Historical data unavailable"
                } else {
                    errorMessage = "No historical data available for this currency"
                }
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

            // Clear task reference before setting loading to false to prevent race conditions
            fetchTask = nil
            isLoading = false

        } catch is CancellationError {
            logger.debug("Fetch cancelled", category: .viewModel)
            guard generation == loadGeneration else { return }
            fetchTask = nil
            isLoading = false
        } catch {
            logger.error("Load failed: \(error.localizedDescription)", category: .viewModel)

            // Try to use cached data even if the load failed
            let cachedData = await dataOrchestrationUseCase.getCachedData(
                for: currency,
                dateRange: dateRange
            )
            guard generation == loadGeneration, !Task.isCancelled else { return }

            if !cachedData.isEmpty {
                // We have some cached data, use it
                logger.info("Using cached data as fallback", category: .viewModel)
                let dataPoints = await preparedChartDataPoints(for: currency, dateRange: dateRange)
                guard generation == loadGeneration, !Task.isCancelled else { return }
                displayedChartDataPoints = dataPoints
                errorMessage = "Using cached data (offline)"
            } else {
                // No cached data available
                displayedChartDataPoints = []

                // Use centralized error handling for consistency
                if let appError = AppError.from(error) {
                    errorMessage = appError.message
                    appState.errorHandler.handle(appError)
                } else {
                    // Handle unexpected errors
                    let genericError = AppError.networkError("Failed to load historical data")
                    errorMessage = genericError.message
                    appState.errorHandler.handle(genericError)
                }
            }

            fetchTask = nil
            isLoading = false
        }
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
    func getTrendData(for currencyCode: String) -> TrendDataValue? {
        guard let code = CurrencyCode(currencyCode), let base = CurrencyCode(baseCurrency) else {
            return nil
        }
        return trendDataUseCase.adjustedTrend(for: code, baseCurrency: base, in: trendData)
    }

    // MARK: - Date Range Calculations

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
    private func preparedChartDataPoints(for currency: CurrencyCode, dateRange: DateRange) async -> [ChartDataPoint] {
        let historicalData = await dataOrchestrationUseCase.getCachedData(for: currency, dateRange: dateRange)

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

    /// Statistics calculated from current chart data
    private var chartStatistics: ChartStatistics {
        chartDataPreparationUseCase.calculateStatistics(from: displayedChartDataPoints)
    }

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
