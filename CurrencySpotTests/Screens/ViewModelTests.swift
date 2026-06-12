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
    private static func makeHistoryViewModel(ratesStore: ExchangeRatesStore? = nil) -> HistoryViewModel {
        let ratesStore = ratesStore ?? ExchangeRatesStore()
        let service = MockExchangeRateService()
        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(syncStore: MockHistoricalSyncStore())
        return HistoryViewModel(
            ratesStore: ratesStore,
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

        @Test("displayedCurrencies excludes the base, adjusts rates, and reacts to search and sort", .timeLimit(.minutes(1)))
        func displayedCurrenciesFilterAndSort() async {
            let store = ExchangeRatesStore()
            let viewModel = ViewModelTests.makeHistoryViewModel(ratesStore: store)

            store.update(
                rates: [
                    ExchangeRate(currencyCode: "USD", rate: 1.0),
                    ExchangeRate(currencyCode: "EUR", rate: 0.8),
                    ExchangeRate(currencyCode: "GBP", rate: 0.5),
                ],
                lastUpdated: nil,
                isUsingMockData: false
            )
            // Observation delivery hops through the main actor's queue.
            await ViewModelTests.waitUntil { viewModel.displayedCurrencies.count == 2 }

            // Base (USD) excluded; default sort is name A-Z ("British Pound" < "Euro").
            #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])
            #expect(viewModel.displayedCurrencies.first?.rate == 0.5) // 0.5 / 1.0

            viewModel.selectSortOption(.rateHighToLow)
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])

            viewModel.selectSortOption(.rateLowToHigh)
            #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])

            viewModel.searchText = "euro"
            #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR"])

            viewModel.searchText = ""
            #expect(viewModel.displayedCurrencies.count == 2)
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
