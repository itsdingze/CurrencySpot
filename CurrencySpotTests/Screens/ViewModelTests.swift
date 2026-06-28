//
//  ViewModelTests.swift
//  CurrencySpotTests
//
//  Created by Dingze Yu on 7/17/25.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("ViewModel Tests")
struct ViewModelTests {
    // Builds a HistoryViewModel backed entirely by MockExchangeRateService so trend
    // data is the deterministic MockExchangeRates.trendData fixture and no network runs.
    private static func makeHistoryViewModel(
        ratesStore: ExchangeRatesStore? = nil,
        watchlist: WatchlistStore? = nil
    ) -> HistoryViewModel {
        let ratesStore = ratesStore ?? ExchangeRatesStore()
        let watchlist = watchlist ?? makeWatchlist()
        let service = MockExchangeRateService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncStore: MockHistoricalSyncStore())
        return HistoryViewModel(
            ratesStore: ratesStore,
            watchlist: watchlist,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: DataOrchestrationUseCase(
                repository: service,
                historicalDataAnalysisUseCase: historicalDataAnalysisUseCase
            ),
            chartDataPreparationUseCase: ChartDataPreparationUseCase(cacheService: InMemoryCacheService()),
            trendDataUseCase: TrendDataUseCase(
                trendRepository: service,
                historicalRateRepository: service
            ),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            clock: ImmediateClock()
        )
    }

    /// An isolated, in-memory watchlist (never touches `.standard`), seeded with
    /// an explicit set so list expectations are deterministic.
    private static func makeWatchlist(seed: [String] = CurrencyDefaults.favoriteCurrencies) -> WatchlistStore {
        let suiteName = "ViewModelTests.watchlist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return WatchlistStore(userDefaults: defaults, seed: seed)
    }

    /// Yields the main actor until `condition` holds; tests guard hangs with `.timeLimit`.
    private static func waitUntil(_ condition: () -> Bool) async {
        while condition() == false {
            await Task.yield()
        }
    }

    @Suite("HistoryViewModel Tests")
    struct HistoryViewModelTests {
        let viewModel = ViewModelTests.makeHistoryViewModel()

        @Test("Initializes with default currencies and no chart data")
        func initializesWithDefaults() {
            #expect(viewModel.baseCurrency == "USD")
            #expect(viewModel.targetCurrency == "EUR")
            #expect(viewModel.displayedChartDataPoints.isEmpty)
        }

        @Test("initializeTrendData loads the full fixture trend set")
        func initializeTrendDataLoadsFixture() async {
            await viewModel.initializeTrendData()

            // MockExchangeRateService.loadTrendData() returns the MockExchangeRates.trendData fixture.
            #expect(viewModel.trendData.count == MockExchangeRates.trendData.count)
        }

        @Test("getTrendData returns the raw USD-based trend unchanged when base is USD")
        func getTrendDataUSDBasePassthrough() async {
            await viewModel.initializeTrendData()
            // Default base currency is USD, so trends come straight from the fixture.

            let gbp = viewModel.getTrendData(for: "GBP")
            #expect(gbp?.weeklyChange == -0.5)
            #expect(gbp?.miniChartData == [0.76, 0.755, 0.753, 0.751, 0.749, 0.748, 0.75])

            let eur = viewModel.getTrendData(for: "EUR")
            #expect(eur?.weeklyChange == 0.1)
        }

        @Test("Loading the current configuration populates displayed chart data")
        func loadPopulatesChartData() async {
            #expect(viewModel.chartData == .idle)
            await viewModel.loadCurrentConfigurationAndWait()

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

            await ViewModelTests.waitUntil {
                if case let .loaded(points) = viewModel.chartData { return !points.isEmpty }
                return false
            }
        }

        @Test("selectTimeRange with the current range is a no-op")
        func selectTimeRangeSameValueNoOp() {
            #expect(viewModel.selectedTimeRange == .threeMonths)
            viewModel.selectTimeRange(.threeMonths)
            // No load was triggered: the lifecycle is still untouched.
            #expect(viewModel.chartData == .idle)
        }

        @Test("a failed 5Y load publishes .failed instead of rendering the resident year", .timeLimit(.minutes(1)))
        func archiveLoadFailurePublishesFailed() async throws {
            let repository = MockHistoricalRateRepository()
            repository.shouldThrowErrorOnFetch = true // the archive bridge is unreachable
            // The resident series holds a year of rows — which must NOT be presented
            // as a loaded five-year chart.
            repository.seedCache([
                HistoricalRateSnapshot(date: Date(timeIntervalSince1970: 1_700_000_000), rates: [
                    HistoricalRatePoint(currencyCode: "EUR", rate: 0.9),
                ]),
            ])
            let analysis = HistoricalDataAnalysisUseCase(syncStore: MockHistoricalSyncStore())
            let viewModel = HistoryViewModel(
                ratesStore: ExchangeRatesStore(),
                watchlist: ViewModelTests.makeWatchlist(),
                historicalDataAnalysisUseCase: analysis,
                dataOrchestrationUseCase: DataOrchestrationUseCase(
                    repository: repository,
                    historicalDataAnalysisUseCase: analysis
                ),
                chartDataPreparationUseCase: ChartDataPreparationUseCase(cacheService: InMemoryCacheService()),
                trendDataUseCase: TrendDataUseCase(
                    trendRepository: MockTrendRepository(),
                    historicalRateRepository: repository
                ),
                appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
                clock: ImmediateClock()
            )

            viewModel.selectTimeRange(.fiveYears)

            await ViewModelTests.waitUntil {
                if case .failed = viewModel.chartData { return true }
                return false
            }
        }

        @Test("prefetchHistoricalWindow warms a today-anchored 1-year window without touching chart state")
        func prefetchWarmsSharedSeriesSilently() async throws {
            let repository = MockHistoricalRateRepository()
            repository.earliestStoredDateResult = nil // nothing stored → the prefetch fetches
            repository.fetchedDataToReturn = [
                HistoricalRateSnapshot(date: Date(timeIntervalSince1970: 1_700_000_000), rates: [
                    HistoricalRatePoint(currencyCode: "EUR", rate: 0.9),
                ]),
            ]
            let analysis = HistoricalDataAnalysisUseCase(syncStore: MockHistoricalSyncStore())
            let viewModel = HistoryViewModel(
                ratesStore: ExchangeRatesStore(),
                watchlist: ViewModelTests.makeWatchlist(),
                historicalDataAnalysisUseCase: analysis,
                dataOrchestrationUseCase: DataOrchestrationUseCase(
                    repository: repository,
                    historicalDataAnalysisUseCase: analysis
                ),
                chartDataPreparationUseCase: ChartDataPreparationUseCase(cacheService: InMemoryCacheService()),
                trendDataUseCase: TrendDataUseCase(
                    trendRepository: MockTrendRepository(),
                    historicalRateRepository: repository
                ),
                appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
                clock: ImmediateClock()
            )

            await viewModel.prefetchHistoricalWindow()

            // Published chart state is untouched — the prefetch is invisible to the UI.
            #expect(viewModel.chartData == .idle)

            // One today-anchored, year-long fetch warmed the shared series.
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

            // Re-keying at selection time would let the old points' dates match
            // the incoming dataset and break the chart's crossfade animation.
            viewModel.selectTimeRange(.oneMonth)
            #expect(viewModel.chartSeriesID == initialSeries)

            await ViewModelTests.waitUntil {
                if case .loaded = viewModel.chartData { return viewModel.chartSeriesID != initialSeries }
                return false
            }
            #expect(viewModel.chartSeriesID.range == .oneMonth)

            // A reload of the same configuration keeps the series identity,
            // so refreshed points morph in place instead of crossfading.
            await viewModel.loadCurrentConfigurationAndWait()
            #expect(viewModel.chartSeriesID.range == .oneMonth)
        }

        @Test("openHistory targets the picked currency against the shared base and resets the range", .timeLimit(.minutes(1)))
        func openHistoryConfiguresPair() async {
            viewModel.openHistory(for: "GBP")

            #expect(viewModel.targetCurrency == "GBP")
            #expect(viewModel.baseCurrency == "USD")
            #expect(viewModel.selectedTimeRange == .threeMonths)

            await ViewModelTests.waitUntil {
                if case let .loaded(points) = viewModel.chartData { return !points.isEmpty }
                return false
            }
        }

        @Test("chart onboarding presents after the delayed check on first visit only")
        func chartOnboardingPresentation() async {
            #expect(viewModel.isChartOnboardingPresented == false)

            await viewModel.presentChartOnboardingIfNeeded(hasSeenChartOnboarding: true)
            #expect(viewModel.isChartOnboardingPresented == false)

            await viewModel.presentChartOnboardingIfNeeded(hasSeenChartOnboarding: false)
            #expect(viewModel.isChartOnboardingPresented == true)
        }

        @Test("watchlist view shows only watchlisted currencies, excludes the base, and honors sort", .timeLimit(.minutes(1)))
        func watchlistDisplayAndSort() async {
            let store = ExchangeRatesStore()
            // Manual order GBP, EUR; CHF deliberately left off the watchlist.
            let watchlist = ViewModelTests.makeWatchlist(seed: ["GBP", "EUR"])
            let viewModel = ViewModelTests.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

            store.update(
                rates: [
                    ExchangeRate(currencyCode: "USD", rate: 1.0),
                    ExchangeRate(currencyCode: "EUR", rate: 0.8),
                    ExchangeRate(currencyCode: "GBP", rate: 0.5),
                    ExchangeRate(currencyCode: "CHF", rate: 0.9),
                ],
                lastUpdated: nil,
                isUsingMockData: false
            )
            // Observation delivery hops through the main actor's queue.
            await ViewModelTests.waitUntil { viewModel.displayedCurrencies.count == 2 }

            // Only watchlisted currencies (EUR, GBP); base USD excluded; CHF absent.
            #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"]) // manual order
            #expect(viewModel.displayedCurrencies.first?.rate == 0.5) // GBP: 0.5 / 1.0

            viewModel.selectSortOption(.symbol)
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])

            viewModel.selectSortOption(.name) // "British Pound" < "Euro"
            #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])

            viewModel.selectSortOption(.manual) // back to the stored drag order
            #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])
        }

        @Test("searching exposes the full catalog with watchlist membership", .timeLimit(.minutes(1)))
        func searchShowsFullCatalog() async {
            let store = ExchangeRatesStore()
            let watchlist = ViewModelTests.makeWatchlist(seed: ["EUR"])
            let viewModel = ViewModelTests.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

            store.update(
                rates: [
                    ExchangeRate(currencyCode: "USD", rate: 1.0),
                    ExchangeRate(currencyCode: "EUR", rate: 0.8),
                    ExchangeRate(currencyCode: "CHF", rate: 0.9),
                ],
                lastUpdated: nil,
                isUsingMockData: false
            )
            await ViewModelTests.waitUntil { viewModel.displayedCurrencies.count == 1 }

            // Watchlist view: only EUR.
            #expect(viewModel.isSearching == false)
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR"])

            // Search reaches CHF, which is not on the watchlist.
            viewModel.searchText = "CHF"
            #expect(viewModel.isSearching == true)
            #expect(viewModel.displayedCurrencies.map(\.code) == ["CHF"])
            #expect(viewModel.isInWatchlist("CHF") == false)
            #expect(viewModel.isInWatchlist("EUR") == true)
        }

        @Test("toggling a search result adds then removes it from the watchlist", .timeLimit(.minutes(1)))
        func toggleFromSearch() async {
            let store = ExchangeRatesStore()
            let watchlist = ViewModelTests.makeWatchlist(seed: ["EUR"])
            let viewModel = ViewModelTests.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

            store.update(
                rates: [
                    ExchangeRate(currencyCode: "USD", rate: 1.0),
                    ExchangeRate(currencyCode: "EUR", rate: 0.8),
                    ExchangeRate(currencyCode: "CHF", rate: 0.9),
                ],
                lastUpdated: nil,
                isUsingMockData: false
            )
            await ViewModelTests.waitUntil { viewModel.displayedCurrencies.count == 1 }

            viewModel.toggleWatchlist("CHF")
            #expect(viewModel.isInWatchlist("CHF") == true)
            // Manual order keeps the new addition last.
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "CHF"])

            viewModel.toggleWatchlist("CHF")
            #expect(viewModel.isInWatchlist("CHF") == false)
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR"])
        }

        @Test("removeFromWatchlist(atOffsets:) deletes the row at the displayed offset", .timeLimit(.minutes(1)))
        func removeAtOffsets() async {
            let store = ExchangeRatesStore()
            let watchlist = ViewModelTests.makeWatchlist(seed: ["EUR", "GBP", "JPY"])
            let viewModel = ViewModelTests.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

            store.update(
                rates: [
                    ExchangeRate(currencyCode: "USD", rate: 1.0),
                    ExchangeRate(currencyCode: "EUR", rate: 0.8),
                    ExchangeRate(currencyCode: "GBP", rate: 0.5),
                    ExchangeRate(currencyCode: "JPY", rate: 150),
                ],
                lastUpdated: nil,
                isUsingMockData: false
            )
            await ViewModelTests.waitUntil { viewModel.displayedCurrencies.count == 3 }

            // Displayed manual order [EUR, GBP, JPY]; swipe-delete offset 1 (GBP).
            viewModel.removeFromWatchlist(atOffsets: IndexSet(integer: 1))
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "JPY"])
            #expect(viewModel.isInWatchlist("GBP") == false)
        }

        @Test("moveWatchlist reorders by displayed offset while the hidden base stays put", .timeLimit(.minutes(1)))
        func moveReorders() async {
            let store = ExchangeRatesStore()
            // USD is watchlisted but hidden (it's the base).
            let watchlist = ViewModelTests.makeWatchlist(seed: ["USD", "EUR", "GBP", "JPY"])
            let viewModel = ViewModelTests.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

            store.update(
                rates: [
                    ExchangeRate(currencyCode: "USD", rate: 1.0),
                    ExchangeRate(currencyCode: "EUR", rate: 0.8),
                    ExchangeRate(currencyCode: "GBP", rate: 0.5),
                    ExchangeRate(currencyCode: "JPY", rate: 150),
                ],
                lastUpdated: nil,
                isUsingMockData: false
            )
            await ViewModelTests.waitUntil { viewModel.displayedCurrencies.count == 3 }
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP", "JPY"])

            // Drag JPY (displayed offset 2) to the front.
            viewModel.moveWatchlist(fromOffsets: IndexSet(integer: 2), toOffset: 0)
            #expect(viewModel.displayedCurrencies.map(\.code) == ["JPY", "EUR", "GBP"])
        }

        @Test("Percentage and Price Change sorts surface the biggest weekly gainer first", .timeLimit(.minutes(1)))
        func changeSorts() async {
            let store = ExchangeRatesStore()
            let watchlist = ViewModelTests.makeWatchlist(seed: ["GBP", "EUR"]) // manual: GBP, EUR
            let viewModel = ViewModelTests.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

            store.update(
                rates: [
                    ExchangeRate(currencyCode: "USD", rate: 1.0),
                    ExchangeRate(currencyCode: "EUR", rate: 0.8),
                    ExchangeRate(currencyCode: "GBP", rate: 0.5),
                ],
                lastUpdated: nil,
                isUsingMockData: false
            )
            // Fixture trends: EUR +0.1%, GBP -0.5% (USD base passthrough).
            await viewModel.initializeTrendData()
            await ViewModelTests.waitUntil { viewModel.displayedCurrencies.count == 2 }

            #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"]) // manual

            viewModel.selectSortOption(.percentChange)
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])

            viewModel.selectSortOption(.priceChange)
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])
        }

        @Test("an external watchlist reset refreshes the displayed list without a rates change", .timeLimit(.minutes(1)))
        func externalWatchlistResetRefreshesDisplayedList() async {
            let store = ExchangeRatesStore()
            let watchlist = ViewModelTests.makeWatchlist(seed: ["GBP", "EUR"])
            let viewModel = ViewModelTests.makeHistoryViewModel(ratesStore: store, watchlist: watchlist)

            store.update(
                rates: [
                    ExchangeRate(currencyCode: "USD", rate: 1.0),
                    ExchangeRate(currencyCode: "EUR", rate: 0.8),
                    ExchangeRate(currencyCode: "GBP", rate: 0.5),
                    ExchangeRate(currencyCode: "JPY", rate: 150),
                    ExchangeRate(currencyCode: "CHF", rate: 0.9),
                ],
                lastUpdated: nil,
                isUsingMockData: false
            )
            await ViewModelTests.waitUntil { viewModel.displayedCurrencies.count == 2 }
            #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])

            // Mutating the shared store from outside the ViewModel — exactly what
            // SettingsViewModel.resetSettingsToDefault() does — must refresh the list.
            watchlist.reset(to: ["JPY", "CHF"])

            // Observation delivery hops through the main actor; give it a bounded
            // chance rather than hanging if the list never updates (the bug).
            for _ in 0 ..< 100 { await Task.yield() }
            #expect(viewModel.displayedCurrencies.map(\.code) == ["JPY", "CHF"])

            // A second external change must still propagate — proving the one-shot
            // observation re-armed itself rather than firing only once.
            watchlist.reset(to: ["EUR", "GBP"])
            for _ in 0 ..< 100 { await Task.yield() }
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])
        }

        @Test("Follows the calculator's base currency through the shared rates store")
        func followsSharedBaseCurrency() async {
            let store = ExchangeRatesStore()
            let viewModel = ViewModelTests.makeHistoryViewModel(ratesStore: store)
            #expect(viewModel.baseCurrency == "USD")

            store.updateBaseCurrency("EUR")
            // Observation delivery hops through the main actor's queue.
            while viewModel.baseCurrency != "EUR" {
                await Task.yield()
            }
            #expect(viewModel.baseCurrency == "EUR")
        }
    }
}
