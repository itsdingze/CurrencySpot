@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("HistoryViewModel Tests")
struct HistoryViewModelTests {
    private static func makeHistoryViewModel(
        ratesStore: ExchangeRatesStore? = nil,
        watchlist: WatchlistStore? = nil,
        preferences: PreferencesStore = InMemoryPreferencesStore()
    ) -> HistoryViewModel {
        let ratesStore = ratesStore ?? ExchangeRatesStore()
        let watchlist = watchlist ?? makeWatchlist()
        let service = PreviewExchangeRateRepository()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncCoverage: MockHistoricalSyncStore())
        return HistoryViewModel(
            ratesStore: ratesStore,
            watchlist: watchlist,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: DataOrchestrationUseCase(
                repository: service,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase
            ),
            chartDataPreparationUseCase: ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache()),
            trendDataUseCase: TrendDataUseCase(
                trendRepository: service,
                historicalRateRepository: service
            ),
            preferences: preferences,
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            clock: ImmediateClock()
        )
    }

    private static func makeWatchlist(seed: [CurrencyCode] = CurrencyDefaults.favoriteCurrencies) -> WatchlistStore {
        let suiteName = "HistoryViewModelTests.watchlist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return WatchlistStore(userDefaults: defaults, seed: seed)
    }

    let viewModel = Self.makeHistoryViewModel()

    @Test("Initializes with default currencies and no chart data")
    func initializesWithDefaults() {
        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.targetCurrency == "EUR")
        #expect(viewModel.displayedChartDataPoints.isEmpty)
    }

    @Test("initializeTrendData loads the full fixture trend set")
    func initializeTrendDataLoadsFixture() async {
        await viewModel.initializeTrendData()

        #expect(viewModel.trendData.count == SampleExchangeRates.trendData.count)
    }

    @Test("getTrendData returns the raw USD-based trend unchanged when base is USD")
    func getTrendDataUSDBasePassthrough() async {
        await viewModel.initializeTrendData()

        let gbp = viewModel.getTrendData(for: "GBP")
        #expect(gbp?.weeklyChange == -0.5)
        #expect(gbp?.miniChartData == [0.76, 0.755, 0.753, 0.751, 0.749, 0.748, 0.75])

        let eur = viewModel.getTrendData(for: "EUR")
        #expect(eur?.weeklyChange == 0.1)
    }

    @Test("Loading the current configuration transitions .idle -> .loading -> .loaded", .timeLimit(.minutes(1)))
    func loadPopulatesChartData() async {
        #expect(viewModel.chartData == .idle)

        viewModel.loadDataForCurrentConfiguration()

        await waitUntil { viewModel.chartData.isLoading }
        guard case let .loading(previous) = viewModel.chartData else {
            Issue.record("expected .loading, got \(viewModel.chartData)")
            return
        }
        #expect(previous == nil)

        await waitUntil {
            if case .loaded = viewModel.chartData { return true }
            return false
        }

        guard case let .loaded(points) = viewModel.chartData else {
            Issue.record("expected .loaded, got \(viewModel.chartData)")
            return
        }
        #expect(points.isEmpty == false)
        #expect(viewModel.displayedChartDataPoints == points)
    }

    @Test("selectTimeRange switches the range and triggers a load", .timeLimit(.minutes(1)))
    func selectTimeRangeReloads() async {
        #expect(viewModel.chartData == .idle)

        viewModel.selectTimeRange(.oneMonth)
        #expect(viewModel.selectedTimeRange == .oneMonth)

        await waitUntil {
            if case let .loaded(points) = viewModel.chartData { return !points.isEmpty }
            return false
        }
    }

    @Test("selectTimeRange with the current range is a no-op")
    func selectTimeRangeSameValueNoOp() {
        #expect(viewModel.selectedTimeRange == .threeMonths)
        viewModel.selectTimeRange(.threeMonths)
        #expect(viewModel.chartData == .idle)
    }

    @Test("a failed 5Y load publishes .failed instead of rendering the resident year", .timeLimit(.minutes(1)))
    func archiveLoadFailurePublishesFailed() async throws {
        let repository = MockHistoricalRateRepository()
        repository.shouldThrowErrorOnFetch = true
        repository.seedCache([
            HistoricalRateSnapshot(date: Date(timeIntervalSince1970: 1_700_000_000), rates: [
                HistoricalRatePoint(currencyCode: "EUR", rate: 0.9),
            ]),
        ])
        let analysis = HistoricalDataAnalysisUseCase(syncCoverage: MockHistoricalSyncStore())
        let viewModel = HistoryViewModel(
            ratesStore: ExchangeRatesStore(),
            watchlist: Self.makeWatchlist(),
            historicalDataAnalysisUseCase: analysis,
            dataOrchestrationUseCase: DataOrchestrationUseCase(
                repository: repository,
                historicalDataAnalysisUseCase: analysis
            ),
            chartDataPreparationUseCase: ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache()),
            trendDataUseCase: TrendDataUseCase(
                trendRepository: MockTrendRepository(),
                historicalRateRepository: repository
            ),
            preferences: InMemoryPreferencesStore(),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            clock: ImmediateClock()
        )

        viewModel.selectTimeRange(.fiveYears)

        await waitUntil {
            if case .failed = viewModel.chartData { return true }
            return false
        }
    }

    @Test("volatility describes the full daily series, not the downsampled chart line", .timeLimit(.minutes(1)))
    func volatilityUsesFullSeries() async {
        let repository = MockHistoricalRateRepository()
        repository.fetchedDataProvider = { from, to in
            Self.randomWalk(from: from, to: to, dailyMove: 0.0025)
        }
        let analysis = HistoricalDataAnalysisUseCase(syncCoverage: MockHistoricalSyncStore())
        let viewModel = HistoryViewModel(
            ratesStore: ExchangeRatesStore(),
            watchlist: Self.makeWatchlist(),
            historicalDataAnalysisUseCase: analysis,
            dataOrchestrationUseCase: DataOrchestrationUseCase(
                repository: repository,
                historicalDataAnalysisUseCase: analysis
            ),
            chartDataPreparationUseCase: ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache()),
            trendDataUseCase: TrendDataUseCase(
                trendRepository: MockTrendRepository(),
                historicalRateRepository: repository
            ),
            preferences: InMemoryPreferencesStore(),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            clock: ImmediateClock()
        )

        viewModel.selectTimeRange(.oneYear)
        await waitUntil {
            if case let .loaded(points) = viewModel.chartData { return !points.isEmpty }
            return false
        }

        #expect(viewModel.volatilityLevel == .veryLow)
    }

    private static func randomWalk(from: Date, to: Date, dailyMove: Double) -> [HistoricalRateSnapshot] {
        let calendar = TimeZoneManager.cetCalendar
        var state: UInt64 = 42
        var rate = 1.0
        var day = calendar.startOfDay(for: from)
        var snapshots: [HistoricalRateSnapshot] = []
        while day <= to {
            snapshots.append(HistoricalRateSnapshot(date: day, rates: [HistoricalRatePoint(currencyCode: "EUR", rate: rate)]))
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            rate *= (state >> 33) & 1 == 0 ? 1 + dailyMove : 1 - dailyMove
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return snapshots
    }

    @Test("prefetchHistoricalWindow warms a today-anchored 1-year window without touching chart state")
    func prefetchWarmsSharedSeriesSilently() async throws {
        let repository = MockHistoricalRateRepository()
        repository.earliestStoredDateResult = nil
        repository.fetchedDataToReturn = [
            HistoricalRateSnapshot(date: Date(timeIntervalSince1970: 1_700_000_000), rates: [
                HistoricalRatePoint(currencyCode: "EUR", rate: 0.9),
            ]),
        ]
        let analysis = HistoricalDataAnalysisUseCase(syncCoverage: MockHistoricalSyncStore())
        let viewModel = HistoryViewModel(
            ratesStore: ExchangeRatesStore(),
            watchlist: Self.makeWatchlist(),
            historicalDataAnalysisUseCase: analysis,
            dataOrchestrationUseCase: DataOrchestrationUseCase(
                repository: repository,
                historicalDataAnalysisUseCase: analysis
            ),
            chartDataPreparationUseCase: ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache()),
            trendDataUseCase: TrendDataUseCase(
                trendRepository: MockTrendRepository(),
                historicalRateRepository: repository
            ),
            preferences: InMemoryPreferencesStore(),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            clock: ImmediateClock()
        )

        await viewModel.prefetchHistoricalWindow()

        #expect(viewModel.chartData == .idle)

        let call = try #require(repository.fetchHistoricalRatesCalls.first)
        let days = TimeZoneManager.cetCalendar.dateComponents([.day], from: call.from, to: call.to).day ?? 0
        #expect(days >= 364 && days <= 366)
        #expect(repository.cachedData.isEmpty == false)
    }

    @Test("chartSeriesID changes only when a new series' points land, not at selection time", .timeLimit(.minutes(1)))
    func chartSeriesIDFollowsThePoints() async {
        await viewModel.loadCurrentConfigurationAndWait()
        let initialSeries = viewModel.chartSeriesID
        #expect(initialSeries.range == .threeMonths)

        viewModel.selectTimeRange(.oneMonth)
        #expect(viewModel.chartSeriesID == initialSeries)

        await waitUntil {
            if case .loaded = viewModel.chartData { return viewModel.chartSeriesID != initialSeries }
            return false
        }
        #expect(viewModel.chartSeriesID.range == .oneMonth)

        await viewModel.loadCurrentConfigurationAndWait()
        #expect(viewModel.chartSeriesID.range == .oneMonth)
    }

    @Test("openHistory targets the picked currency against the shared base and resets the range", .timeLimit(.minutes(1)))
    func openHistoryConfiguresPair() async {
        viewModel.openHistory(for: "GBP")

        #expect(viewModel.targetCurrency == "GBP")
        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.selectedTimeRange == .threeMonths)

        await waitUntil {
            if case let .loaded(points) = viewModel.chartData { return !points.isEmpty }
            return false
        }
    }

    @Test("chart onboarding stays dismissed once the stored flag says it has been seen")
    func chartOnboardingSkippedWhenSeen() async {
        let seen = Self.makeHistoryViewModel(preferences: InMemoryPreferencesStore(hasSeenChartOnboarding: true))

        await seen.presentChartOnboardingIfNeeded()

        #expect(seen.destination == nil)
    }

    @Test("chart onboarding presents on first visit and completing it records the flag")
    func chartOnboardingPresentsThenCompletes() async {
        let preferences = InMemoryPreferencesStore()
        let firstVisit = Self.makeHistoryViewModel(preferences: preferences)

        await firstVisit.presentChartOnboardingIfNeeded()
        #expect(firstVisit.destination == .chartOnboarding)

        firstVisit.completeChartOnboarding()
        #expect(firstVisit.destination == nil)
        #expect(preferences.hasSeenChartOnboarding == true)
    }

    @Test("watchlist view shows only watchlisted currencies, excludes the base, and honors sort", .timeLimit(.minutes(1)))
    func watchlistDisplayAndSort() async {
        let store = ExchangeRatesStore()
        let watchlist = Self.makeWatchlist(seed: ["GBP", "EUR"])
        let viewModel = Self.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

        store.update(
            rates: [
                ExchangeRate(currencyCode: "USD", rate: 1.0),
                ExchangeRate(currencyCode: "EUR", rate: 0.8),
                ExchangeRate(currencyCode: "GBP", rate: 0.5),
                ExchangeRate(currencyCode: "CHF", rate: 0.9),
            ],
            lastUpdated: nil,
            isShowingSampleRates: false
        )
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])
        #expect(viewModel.displayedCurrencies.first?.rate == 0.5)

        viewModel.selectSortOption(.symbol)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])

        viewModel.selectSortOption(.name)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])

        viewModel.selectSortOption(.manual)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])
    }

    @Test("searching exposes the full catalog with watchlist membership", .timeLimit(.minutes(1)))
    func searchShowsFullCatalog() async {
        let store = ExchangeRatesStore()
        let watchlist = Self.makeWatchlist(seed: ["EUR"])
        let viewModel = Self.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

        store.update(
            rates: [
                ExchangeRate(currencyCode: "USD", rate: 1.0),
                ExchangeRate(currencyCode: "EUR", rate: 0.8),
                ExchangeRate(currencyCode: "CHF", rate: 0.9),
            ],
            lastUpdated: nil,
            isShowingSampleRates: false
        )
        await waitUntil { viewModel.displayedCurrencies.count == 1 }

        #expect(viewModel.isSearching == false)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR"])

        viewModel.searchText = "CHF"
        #expect(viewModel.isSearching == true)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["CHF"])
        #expect(viewModel.isInWatchlist("CHF") == false)
        #expect(viewModel.isInWatchlist("EUR") == true)
    }

    @Test("toggling a search result adds then removes it from the watchlist", .timeLimit(.minutes(1)))
    func toggleFromSearch() async {
        let store = ExchangeRatesStore()
        let watchlist = Self.makeWatchlist(seed: ["EUR"])
        let viewModel = Self.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

        store.update(
            rates: [
                ExchangeRate(currencyCode: "USD", rate: 1.0),
                ExchangeRate(currencyCode: "EUR", rate: 0.8),
                ExchangeRate(currencyCode: "CHF", rate: 0.9),
            ],
            lastUpdated: nil,
            isShowingSampleRates: false
        )
        await waitUntil { viewModel.displayedCurrencies.count == 1 }

        viewModel.toggleWatchlist("CHF")
        #expect(viewModel.isInWatchlist("CHF") == true)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "CHF"])

        viewModel.toggleWatchlist("CHF")
        #expect(viewModel.isInWatchlist("CHF") == false)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR"])
    }

    @Test("removeFromWatchlist(atOffsets:) deletes the row at the displayed offset", .timeLimit(.minutes(1)))
    func removeAtOffsets() async {
        let store = ExchangeRatesStore()
        let watchlist = Self.makeWatchlist(seed: ["EUR", "GBP", "JPY"])
        let viewModel = Self.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

        store.update(
            rates: [
                ExchangeRate(currencyCode: "USD", rate: 1.0),
                ExchangeRate(currencyCode: "EUR", rate: 0.8),
                ExchangeRate(currencyCode: "GBP", rate: 0.5),
                ExchangeRate(currencyCode: "JPY", rate: 150),
            ],
            lastUpdated: nil,
            isShowingSampleRates: false
        )
        await waitUntil { viewModel.displayedCurrencies.count == 3 }

        viewModel.removeFromWatchlist(atOffsets: IndexSet(integer: 1))
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "JPY"])
        #expect(viewModel.isInWatchlist("GBP") == false)
    }

    @Test("moveWatchlist reorders by displayed offset while the hidden base stays put", .timeLimit(.minutes(1)))
    func moveReorders() async {
        let store = ExchangeRatesStore()
        let watchlist = Self.makeWatchlist(seed: ["USD", "EUR", "GBP", "JPY"])
        let viewModel = Self.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

        store.update(
            rates: [
                ExchangeRate(currencyCode: "USD", rate: 1.0),
                ExchangeRate(currencyCode: "EUR", rate: 0.8),
                ExchangeRate(currencyCode: "GBP", rate: 0.5),
                ExchangeRate(currencyCode: "JPY", rate: 150),
            ],
            lastUpdated: nil,
            isShowingSampleRates: false
        )
        await waitUntil { viewModel.displayedCurrencies.count == 3 }
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP", "JPY"])

        viewModel.moveWatchlist(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["JPY", "EUR", "GBP"])
    }

    @Test("Percentage and Price Change sorts surface the biggest weekly gainer first", .timeLimit(.minutes(1)))
    func changeSorts() async {
        let store = ExchangeRatesStore()
        let watchlist = Self.makeWatchlist(seed: ["GBP", "EUR"])
        let viewModel = Self.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

        store.update(
            rates: [
                ExchangeRate(currencyCode: "USD", rate: 1.0),
                ExchangeRate(currencyCode: "EUR", rate: 0.8),
                ExchangeRate(currencyCode: "GBP", rate: 0.5),
            ],
            lastUpdated: nil,
            isShowingSampleRates: false
        )
        await viewModel.initializeTrendData()
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])

        viewModel.selectSortOption(.percentChange)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])

        viewModel.selectSortOption(.priceChange)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])
    }

    @Test("an external watchlist reset refreshes the displayed list without a rates change", .timeLimit(.minutes(1)))
    func externalWatchlistResetRefreshesDisplayedList() async {
        let store = ExchangeRatesStore()
        let watchlist = Self.makeWatchlist(seed: ["GBP", "EUR"])
        let viewModel = Self.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

        store.update(
            rates: [
                ExchangeRate(currencyCode: "USD", rate: 1.0),
                ExchangeRate(currencyCode: "EUR", rate: 0.8),
                ExchangeRate(currencyCode: "GBP", rate: 0.5),
                ExchangeRate(currencyCode: "JPY", rate: 150),
                ExchangeRate(currencyCode: "CHF", rate: 0.9),
            ],
            lastUpdated: nil,
            isShowingSampleRates: false
        )
        await waitUntil { viewModel.displayedCurrencies.count == 2 }
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])

        watchlist.reset(to: ["JPY", "CHF"])

        await waitUntil { viewModel.displayedCurrencies.map(\.code) == ["JPY", "CHF"] }
        #expect(viewModel.displayedCurrencies.map(\.code) == ["JPY", "CHF"])

        watchlist.reset(to: ["EUR", "GBP"])
        await waitUntil { viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"] }
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])
    }

    @Test("Follows the calculator's base currency through the shared rates store", .timeLimit(.minutes(1)))
    func followsSharedBaseCurrency() async {
        let store = ExchangeRatesStore()
        let viewModel = Self.makeHistoryViewModel(ratesStore: store)
        #expect(viewModel.baseCurrency == "USD")

        store.updateBaseCurrency("EUR")
        await waitUntil { viewModel.baseCurrency == "EUR" }
        #expect(viewModel.baseCurrency == "EUR")
    }
}
