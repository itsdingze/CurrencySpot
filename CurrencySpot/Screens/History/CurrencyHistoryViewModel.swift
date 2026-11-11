import Foundation
import IdentifiedCollections
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
        case basePicker
    }

    // MARK: - Chart State

    private(set) var chartData: Loadable<[ChartDataPoint]> = .idle

    private(set) var displayedChartDataPoints: [ChartDataPoint] = []

    private(set) var chartStatistics: ChartStatistics?

    private(set) var showLoadingOverlay = false

    private(set) var lastUpdated: Date?

    private var isDownloading = false

    private var lastDownloadFailed = false

    var updateStatus: RateBanner {
        guard chartData.value?.isEmpty == false else { return .hidden }
        if isDownloading { return .updating }
        if !isConnected { return .offlineSaved }
        if lastDownloadFailed { return .updateFailed }
        return .hidden
    }

    var isWaitingForConnection: Bool {
        chartData.error != nil && !isConnected
    }

    var canRetryUpdate: Bool {
        updateStatus == .updateFailed
    }

    private var isConnected: Bool {
        appState.networkMonitor.isConnected
    }

    private(set) var chartSeriesID: ChartSeriesID

    // MARK: - Configuration

    private(set) var baseCurrency: CurrencyCode

    let targetCurrency: CurrencyCode

    var selectedTimeRange: TimeRange {
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

    // MARK: - Base Picker

    var basePickerFavorites: [CurrencyCode] {
        favorites.codes.elements.filter { $0 != targetCurrency }
    }

    var basePickerRates: [ExchangeRate] {
        ratesStore.rates.filter { $0.currencyCode != targetCurrency }
    }

    // MARK: - Dependencies

    private let ratesStore: ExchangeRatesStore
    private let favorites: CurrencyCodeListStore
    private let trendsStore: TrendsStore
    private let loadHistoricalRates: LoadHistoricalRatesUseCase
    private let chartDataPreparation: ChartDataPreparationUseCase
    private let trendDataUseCase: TrendDataUseCase
    private let preferences: PreferencesStore
    private let appState: AppState
    private let clock: ClockService
    private let waitLimitClock: ClockService
    private let logger = Logger(category: .viewModel)

    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var trendRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var loadingOverlayTask: Task<Void, Never>?
    @ObservationIgnored private var waitLimitTask: Task<Void, Never>?
    private static let waitLimit: Duration = .seconds(10)
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var isObservingSharedState = false
    @ObservationIgnored private var isInBackground = false

    // MARK: - Initialization

    init(
        base: CurrencyCode,
        target: CurrencyCode,
        timeRange: TimeRange,
        ratesStore: ExchangeRatesStore,
        favorites: CurrencyCodeListStore,
        trendsStore: TrendsStore,
        loadHistoricalRates: LoadHistoricalRatesUseCase,
        chartDataPreparation: ChartDataPreparationUseCase,
        trendDataUseCase: TrendDataUseCase,
        preferences: PreferencesStore,
        appState: AppState,
        clock: ClockService,
        waitLimitClock: ClockService
    ) {
        baseCurrency = base
        targetCurrency = target
        selectedTimeRange = timeRange
        chartSeriesID = ChartSeriesID(currency: target, range: timeRange)
        self.ratesStore = ratesStore
        self.favorites = favorites
        self.trendsStore = trendsStore
        self.loadHistoricalRates = loadHistoricalRates
        self.chartDataPreparation = chartDataPreparation
        self.trendDataUseCase = trendDataUseCase
        self.preferences = preferences
        self.appState = appState
        self.clock = clock
        self.waitLimitClock = waitLimitClock
    }

    // MARK: - Intents

    func loadChart() async {
        observeSharedStateIfNeeded()
        if case .idle = chartData {
            startLoad()
        }
        await loadTask?.value
        await trendRefreshTask?.value
    }

    func retry() {
        startLoad()
    }

    func appMovedToBackground() {
        isInBackground = true
    }

    func appBecameActive() {
        guard isInBackground else { return }
        isInBackground = false
        refreshChart()
    }

    func baseCurrencyTapped() {
        destination = .basePicker
    }

    func selectBase(_ code: CurrencyCode) {
        guard code != baseCurrency, code != targetCurrency else { return }
        baseCurrency = code
        publishChart(.loading(previous: nil))
        startLoad()
    }

    func volatilityInfoTapped() {
        destination = .volatilityInfo
    }

    func presentChartOnboardingIfNeeded() async {
        guard !preferences.hasSeenChartOnboarding else { return }
        try? await clock.sleep(for: .seconds(0.5))
        guard !Task.isCancelled, destination == nil else { return }
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
        observeDataReset()
        observeConnectivity()
    }

    private func observeConnectivity() {
        withObservationTracking {
            _ = appState.networkMonitor.isConnected
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                reloadIfReconnected()
                observeConnectivity()
            }
        }
    }

    private func reloadIfReconnected() {
        guard isConnected else { return }
        refreshChart()
    }

    private func refreshChart() {
        guard chartData.value != nil || chartData.error != nil else { return }
        startLoad(keepingChart: true)
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
        trendRefreshTask?.cancel()
        publishChart(.idle)
        startLoad()
    }

    // MARK: - Loading

    private func startLoad(keepingChart: Bool = false) {
        loadTask?.cancel()
        waitLimitTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        loadTask = Task { await runLoad(generation: generation, keepingChart: keepingChart) }
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == loadGeneration && !Task.isCancelled
    }

    private func runLoad(generation: Int, keepingChart: Bool) async {
        guard isCurrent(generation) else { return }

        let base = baseCurrency
        let timeRange = selectedTimeRange
        let dateRange = loadHistoricalRates.dateRange(for: timeRange)
        if !keepingChart || chartData.value == nil {
            publishChart(.loading(previous: chartData.value))
        }

        let stored = await loadHistoricalRates.storedHistoricalData(in: dateRange)
        guard isCurrent(generation) else { return }
        let storedPoints = await chartPoints(from: stored, base: base, dateRange: dateRange)
        guard isCurrent(generation) else { return }
        if !storedPoints.isEmpty {
            publishChart(.loaded(storedPoints))
        }
        lastUpdated = await loadHistoricalRates.lastDownloaded()
        guard isCurrent(generation) else { return }
        guard isConnected else {
            isDownloading = false
            if storedPoints.isEmpty {
                publishChart(.failed(.noInternetConnection, previous: nil))
            }
            return
        }
        if storedPoints.isEmpty {
            limitWait(of: generation)
        }
        isDownloading = true

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
            let downloadedAt = await loadHistoricalRates.lastDownloaded()
            guard isCurrent(generation) else { return }
            lastUpdated = downloadedAt
            finishDownload(failed: result.updateFailed)
            if result.newDataFetched {
                refreshTrends(for: result.fetchedRanges)
            }
        } catch is CancellationError {
            guard generation == loadGeneration else { return }
            finishDownload(failed: false)
            publishChart(.loaded(chartData.value ?? []))
        } catch {
            guard generation == loadGeneration else { return }
            finishDownload(failed: true)
            logger.error("Chart load failed: \(error.localizedDescription, privacy: .public)")
            let appError = AppError.from(error) ?? .networkError("Failed to load historical data")
            publishChart(.failed(appError, previous: nil))
        }
    }

    private func finishDownload(failed: Bool) {
        isDownloading = false
        lastDownloadFailed = failed
    }

    private func limitWait(of generation: Int) {
        waitLimitTask?.cancel()
        waitLimitTask = Task {
            try? await waitLimitClock.sleep(for: Self.waitLimit)
            guard !Task.isCancelled, generation == loadGeneration, chartData.isLoading else { return }
            publishChart(.failed(.requestFailed(.timedOut), previous: nil))
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

    private func refreshTrends(for fetchedRanges: [DateRange]) {
        trendRefreshTask?.cancel()
        trendRefreshTask = Task {
            let trends = await trendDataUseCase.checkAndRecalculateTrendsIfNeeded(for: fetchedRanges)
            guard !Task.isCancelled else { return }
            trendsStore.replace(with: trends)
        }
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
        guard let chartStatistics else {
            return String(localized: .historyHeaderCurrentRateUnavailable(
                base: baseCurrency.rawValue,
                target: targetCurrency.rawValue
            ))
        }
        return String(localized: .historyHeaderCurrentRate(
            base: baseCurrency.rawValue,
            rate: chartStatistics.currentRate.rateText,
            target: targetCurrency.rawValue
        ))
    }

    var currentRateAccessibilityLabel: LocalizedStringResource {
        guard chartStatistics != nil else { return .historyHeaderCurrentRateUnavailableAccessibilityLabel }
        return .historyHeaderCurrentRateAccessibilityLabel(rate: formattedCurrentRate)
    }

    var formattedHighestRate: String? {
        chartStatistics?.highestRate.rateText
    }

    var formattedLowestRate: String? {
        chartStatistics?.lowestRate.rateText
    }

    var formattedAverageRate: String? {
        chartStatistics?.averageRate.rateText
    }

    var volatilityLevel: VolatilityLevel? {
        chartStatistics?.volatility.map(VolatilityLevel.init(annualizedPercent:))
    }

    var formattedVolatility: String? {
        guard chartStatistics != nil else { return nil }
        return String(localized: volatilityLevel?.displayName ?? .historyStatisticsVolatilityUnavailable)
    }
}
