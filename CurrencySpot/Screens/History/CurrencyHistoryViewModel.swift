import Foundation
import OSLog
import SwiftUI

// MARK: - CurrencyHistoryViewModel

@Observable
final class CurrencyHistoryViewModel {
    nonisolated struct ChartSeriesID: Hashable, Sendable {
        let currency: CurrencyCode
        let range: TimeRange
    }

    nonisolated enum Destination: Equatable {
        case chartOnboarding
        case volatilityInfo
    }

    // MARK: - Chart State

    private(set) var chartData: Loadable<[ChartDataPoint]> = .idle

    private(set) var displayedChartDataPoints: [ChartDataPoint] = []

    private(set) var chartStatistics: ChartStatistics

    private(set) var showLoadingOverlay = false

    private(set) var chartSeriesID: ChartSeriesID

    // MARK: - Configuration

    private(set) var baseCurrency: CurrencyCode

    let targetCurrency: CurrencyCode

    var selectedTimeRange: TimeRange = .threeMonths {
        didSet {
            guard selectedTimeRange != oldValue else { return }
            startLoad()
        }
    }

    // MARK: - Presentation State

    var destination: Destination?

    var showAverageLine = false
    var showHighestPoint = false
    var showLowestPoint = false

    // MARK: - Dependencies

    private let ratesStore: ExchangeRatesStore
    private let trendsStore: TrendsStore
    private let loadHistoricalRates: LoadHistoricalRatesUseCase
    private let chartDataPreparation: ChartDataPreparationUseCase
    private let trendDataUseCase: TrendDataUseCase
    private let preferences: PreferencesStore
    private let appState: AppState
    private let clock: ClockService
    private let logger = Logger(category: .viewModel)

    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadingOverlayTask: Task<Void, Never>?
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var isObservingSharedState = false

    // MARK: - Initialization

    init(
        base: CurrencyCode,
        target: CurrencyCode,
        ratesStore: ExchangeRatesStore,
        trendsStore: TrendsStore,
        loadHistoricalRates: LoadHistoricalRatesUseCase,
        chartDataPreparation: ChartDataPreparationUseCase,
        trendDataUseCase: TrendDataUseCase,
        preferences: PreferencesStore,
        appState: AppState,
        clock: ClockService
    ) {
        baseCurrency = base
        targetCurrency = target
        chartSeriesID = ChartSeriesID(currency: target, range: .threeMonths)
        chartStatistics = chartDataPreparation.calculateStatistics(from: [])
        self.ratesStore = ratesStore
        self.trendsStore = trendsStore
        self.loadHistoricalRates = loadHistoricalRates
        self.chartDataPreparation = chartDataPreparation
        self.trendDataUseCase = trendDataUseCase
        self.preferences = preferences
        self.appState = appState
        self.clock = clock
    }

    // MARK: - Intents

    func loadChart() async {
        observeSharedStateIfNeeded()
        if case .idle = chartData {
            startLoad()
        }
        await loadTask?.value
    }

    func retry() {
        startLoad()
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

    // MARK: - Shared State

    private func observeSharedStateIfNeeded() {
        guard !isObservingSharedState else { return }
        isObservingSharedState = true
        observeBaseCurrency()
        observeDataReset()
    }

    private func observeBaseCurrency() {
        withObservationTracking {
            _ = ratesStore.baseCurrency
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                followBaseCurrency()
                observeBaseCurrency()
            }
        }
    }

    private func followBaseCurrency() {
        let newBase = ratesStore.baseCurrency
        guard newBase != baseCurrency else { return }
        baseCurrency = newBase
        startLoad()
    }

    private func observeDataReset() {
        withObservationTracking {
            _ = appState.dataResetCount
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                reloadAfterDataReset()
                observeDataReset()
            }
        }
    }

    private func reloadAfterDataReset() {
        publishChart(.idle)
        startLoad()
    }

    // MARK: - Loading

    private func startLoad() {
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        loadTask = Task { await runLoad(generation: generation) }
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == loadGeneration && !Task.isCancelled
    }

    private func runLoad(generation: Int) async {
        guard isCurrent(generation) else { return }

        let base = baseCurrency
        let timeRange = selectedTimeRange
        let dateRange = loadHistoricalRates.dateRange(for: timeRange)
        publishChart(.loading(previous: chartData.value))

        do {
            let result = try await loadHistoricalRates.loadHistoricalData(
                for: targetCurrency,
                base: base,
                dateRange: dateRange
            )
            guard isCurrent(generation) else { return }
            let points = await chartPoints(from: result.snapshots, base: base, dateRange: dateRange)
            guard isCurrent(generation) else { return }
            publishChart(.loaded(points))
            if result.newDataFetched {
                await refreshTrends(for: result.fetchedRanges, generation: generation)
            }
        } catch is CancellationError {
            guard generation == loadGeneration else { return }
            publishChart(.loaded(chartData.value ?? []))
        } catch {
            guard generation == loadGeneration else { return }
            logger.error("Chart load failed: \(error.localizedDescription, privacy: .public)")
            let appError = AppError.from(error) ?? .networkError("Failed to load historical data")
            publishChart(.failed(appError, previous: nil))
        }
    }

    private func chartPoints(
        from snapshots: [HistoricalRateSnapshot],
        base: CurrencyCode,
        dateRange: DateRange
    ) async -> [ChartDataPoint] {
        guard !snapshots.isEmpty else { return [] }
        return await chartDataPreparation.processHistoricalRateData(
            historicalData: snapshots,
            baseCurrency: base,
            targetCurrency: targetCurrency,
            dateRange: dateRange,
            exchangeRates: ratesStore.rates
        )
    }

    private func refreshTrends(for fetchedRanges: [DateRange], generation: Int) async {
        let trends = await trendDataUseCase.checkAndRecalculateTrendsIfNeeded(for: fetchedRanges)
        guard isCurrent(generation) else { return }
        trendsStore.replace(with: trends)
    }

    // MARK: - Chart Publishing

    private func publishChart(_ newState: Loadable<[ChartDataPoint]>) {
        let wasLoading = chartData.isLoading
        chartData = newState
        if case .loaded = newState {
            chartSeriesID = ChartSeriesID(currency: targetCurrency, range: selectedTimeRange)
        }
        let series = newState.value ?? []
        displayedChartDataPoints = chartDataPreparation.sampleDataPoints(from: series)
        chartStatistics = chartDataPreparation.calculateStatistics(from: series)

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
}

// MARK: - Display Values

extension CurrencyHistoryViewModel {
    var formattedCurrentRate: String {
        String(localized: .historyHeaderCurrentRate(
            base: baseCurrency.rawValue,
            rate: chartStatistics.currentRate.toStringMax4Decimals,
            target: targetCurrency.rawValue
        ))
    }

    var formattedHighestRate: String {
        chartStatistics.highestRate.toStringMax4Decimals
    }

    var formattedLowestRate: String {
        chartStatistics.lowestRate.toStringMax4Decimals
    }

    var formattedAverageRate: String {
        chartStatistics.averageRate.toStringMax4Decimals
    }

    var volatilityLevel: VolatilityLevel? {
        chartStatistics.volatility.map(VolatilityLevel.init(annualizedPercent:))
    }

    var formattedVolatility: String {
        String(localized: volatilityLevel?.displayName ?? .historyStatisticsVolatilityUnavailable)
    }
}
