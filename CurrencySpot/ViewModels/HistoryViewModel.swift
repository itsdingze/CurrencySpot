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

    /// Base currency (left side of conversion)
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

    /// Calculator ViewModel for accessing exchange rates
    private let calculatorVM: CalculatorViewModel

    /// Use cases for business logic
    private let dataOrchestrationUseCase: DataOrchestrationUseCase
    private let historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase
    private let chartDataPreparationUseCase: ChartDataPreparationUseCase
    private let trendDataUseCase: TrendDataUseCase

    /// App-wide state (network reachability, error handling)
    private let appState = AppState.shared

    /// Current async task for data fetching (for cancellation)
    private var fetchTask: Task<Void, Never>?

    /// Suppresses the per-property didSet reloads while a navigation reconfiguration sets several
    /// properties at once, so one configuration triggers a single load instead of one per property.
    private var isApplyingConfiguration = false

    // MARK: - Initialization

    /// Initializes the HistoryViewModel with dependency injection
    init(
        calculatorVM: CalculatorViewModel,
        historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase,
        dataOrchestrationUseCase: DataOrchestrationUseCase,
        chartDataPreparationUseCase: ChartDataPreparationUseCase,
        trendDataUseCase: TrendDataUseCase
    ) {
        self.calculatorVM = calculatorVM
        self.historicalDataAnalysisUseCase = historicalDataAnalysisUseCase
        self.dataOrchestrationUseCase = dataOrchestrationUseCase
        self.chartDataPreparationUseCase = chartDataPreparationUseCase
        self.trendDataUseCase = trendDataUseCase
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

    /// Clears all data when cache is cleared from settings.
    /// Awaits the cache clear so callers know it has completed before any reload.
    func clearAllData() async {
        displayedChartDataPoints = []
        trendData = []
        errorMessage = nil
        await dataOrchestrationUseCase.clearAllCache()
    }

    /// Clears cached data, then initiates a fresh load once the cache is actually cleared.
    func resetStoredData() async {
        await clearAllData()
        loadDataForCurrentConfiguration()
    }

    // MARK: - Data Loading

    /// Main data loading method - simplified to use DataOrchestrationUseCase
    func loadDataForCurrentConfiguration() {
        // Prevent multiple simultaneous loads
        guard !isLoading else {
            AppLogger.warning("Load already in progress, skipping duplicate request", category: .viewModel)
            return
        }

        // Wait for existing task to complete instead of cancelling
        if let existingTask = fetchTask {
            Task {
                _ = await existingTask.result
                startNewLoadTask()
            }
            return
        }

        startNewLoadTask()
    }

    /// Triggers a load for the current configuration and awaits its completion.
    /// Awaitable counterpart to `loadDataForCurrentConfiguration()` for callers that must
    /// sequence work after a load finishes (and for deterministic tests).
    func loadCurrentConfigurationAndWait() async {
        loadDataForCurrentConfiguration()
        await fetchTask?.value
    }

    private func startNewLoadTask() {
        fetchTask = Task {
            self.isLoading = true
            self.errorMessage = nil

            let dateRange = calculateDateRange()
            let currency = self.targetCurrency

            do {
                // Use DataOrchestrationUseCase to handle all the complex logic
                let result = try await dataOrchestrationUseCase.loadHistoricalData(
                    for: currency,
                    dateRange: dateRange
                )

                // Always try to update chart even with partial data
                if !result.dataPoints.isEmpty {
                    // Update UI with new data (pass the same dateRange used for fetching)
                    await self.updateChartDataPoints(dateRange: dateRange)

                    // Clear error if we successfully got data
                    self.errorMessage = nil
                } else {
                    // No data available, but don't treat as error
                    AppLogger.infoPrivate("No historical data available for \(currency)", category: .viewModel)
                    self.displayedChartDataPoints = []

                    // Set a user-friendly message
                    if !appState.networkMonitor.isConnected {
                        self.errorMessage = "Offline - Historical data unavailable"
                    } else {
                        self.errorMessage = "No historical data available for this currency"
                    }
                }

                // Update trends if new data was fetched
                if result.newDataFetched {
                    AppLogger.info("New data fetched, updating trends...", category: .viewModel)
                    // Use the actually fetched ranges, not the requested range
                    self.trendData = await trendDataUseCase.checkAndRecalculateTrendsIfNeeded(
                        for: result.fetchedRanges
                    )
                }

                // Clear task reference before setting loading to false to prevent race conditions
                self.fetchTask = nil
                self.isLoading = false

            } catch is CancellationError {
                AppLogger.debug("Fetch cancelled", category: .viewModel)
                self.fetchTask = nil
                self.isLoading = false
            } catch {
                AppLogger.error("Load failed: \(error.localizedDescription)", category: .viewModel)

                // Try to use cached data even if the load failed
                let cachedData = await dataOrchestrationUseCase.getCachedData(
                    for: currency,
                    dateRange: dateRange
                )

                if !cachedData.isEmpty {
                    // We have some cached data, use it
                    AppLogger.info("Using cached data as fallback", category: .viewModel)
                    await self.updateChartDataPoints(dateRange: dateRange)
                    self.errorMessage = "Using cached data (offline)"
                } else {
                    // No cached data available
                    self.displayedChartDataPoints = []

                    // Use centralized error handling for consistency
                    if let appError = AppError.from(error) {
                        self.errorMessage = appError.message
                        appState.errorHandler.handle(appError)
                    } else {
                        // Handle unexpected errors
                        let genericError = AppError.networkError("Failed to load historical data")
                        self.errorMessage = genericError.message
                        appState.errorHandler.handle(genericError)
                    }
                }

                self.fetchTask = nil
                self.isLoading = false
            }
        }
    }

    // MARK: - Trend Data Methods

    /// Initializes trend data using TrendDataUseCase
    func initializeTrendData() async {
        trendData = await trendDataUseCase.initializeTrendData()
    }

    /// Gets trend data for a specific currency, adjusted for the current base currency
    func getTrendData(for currencyCode: String) -> TrendDataValue? {
        // Special handling when target currency is USD
        if currencyCode == "USD", baseCurrency != "USD" {
            // Need to get the inverse of the base currency trend
            guard let baseTrend = trendDataUseCase.getTrendData(for: baseCurrency, from: trendData),
                  !baseTrend.miniChartData.isEmpty
            else {
                return nil
            }

            // Invert the base currency rates to get USD rates
            // If EUR/USD = 1.1, then USD/EUR = 1/1.1
            let invertedMiniChartData = baseTrend.miniChartData.map { rate in
                rate != 0 ? 1.0 / rate : 1.0
            }

            // Calculate the percentage change from the inverted data
            guard let firstRate = invertedMiniChartData.first,
                  let lastRate = invertedMiniChartData.last,
                  firstRate != 0
            else {
                return nil
            }

            let adjustedChange = ((lastRate - firstRate) / firstRate) * 100

            return TrendDataValue(
                currencyCode: "USD",
                weeklyChange: adjustedChange,
                miniChartData: invertedMiniChartData
            )
        }

        guard let targetTrend = trendDataUseCase.getTrendData(for: currencyCode, from: trendData) else {
            return nil
        }

        // If base currency is USD, return the trend as-is (already USD-based)
        if baseCurrency == "USD" {
            return targetTrend
        }

        // Get the base currency's trend data (USD → Base)
        guard let baseTrend = trendDataUseCase.getTrendData(for: baseCurrency, from: trendData),
              baseTrend.miniChartData.count == targetTrend.miniChartData.count,
              baseTrend.miniChartData.count >= 2
        else {
            // If we can't find base currency trend or data is invalid, return original
            return targetTrend
        }

        // Convert each data point from USD-based to base-currency-based
        // For each point: Base → Target rate = (USD → Target) / (USD → Base)
        let adjustedMiniChartData = zip(targetTrend.miniChartData, baseTrend.miniChartData).map { targetRate, baseRate in
            baseRate != 0 ? targetRate / baseRate : targetRate
        }

        // Calculate the percentage change from the converted first and last points
        guard let firstRate = adjustedMiniChartData.first,
              let lastRate = adjustedMiniChartData.last,
              firstRate != 0
        else {
            return targetTrend
        }

        let adjustedChange = ((lastRate - firstRate) / firstRate) * 100

        // Return a new TrendDataValue with properly adjusted data
        return TrendDataValue(
            currencyCode: currencyCode,
            weeklyChange: adjustedChange,
            miniChartData: adjustedMiniChartData
        )
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

    /// Updates chart data points based on current currency pair and time range
    /// - Parameter dateRange: The date range to use for filtering data (must match the range used for fetching)
    private func updateChartDataPoints(dateRange: DateRange) async {
        let historicalData = await dataOrchestrationUseCase.getCachedData(for: targetCurrency, dateRange: dateRange)

        // Guard against empty data
        guard !historicalData.isEmpty else {
            AppLogger.info("No historical data to display", category: .viewModel)
            displayedChartDataPoints = []
            return
        }

        let fullDataPoints = await chartDataPreparationUseCase.processHistoricalRateData(
            historicalData: historicalData,
            baseCurrency: baseCurrency,
            targetCurrency: targetCurrency,
            dateRange: dateRange,
            exchangeRates: calculatorVM.availableRates
        )

        // Only update if we have valid data points
        if !fullDataPoints.isEmpty {
            displayedChartDataPoints = chartDataPreparationUseCase.sampleDataPoints(from: fullDataPoints)
        } else {
            AppLogger.warning("No valid chart data points after processing", category: .viewModel)
            displayedChartDataPoints = []
        }
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
