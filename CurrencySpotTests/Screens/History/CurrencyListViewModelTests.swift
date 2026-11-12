@testable import CurrencySpot
import Foundation
import IdentifiedCollections
import Testing

@Suite("CurrencyListViewModel Tests")
struct CurrencyListViewModelTests {
    private static let rates = [
        ExchangeRate(currencyCode: "USD", rate: 1.0),
        ExchangeRate(currencyCode: "EUR", rate: 0.8),
        ExchangeRate(currencyCode: "GBP", rate: 0.5),
        ExchangeRate(currencyCode: "JPY", rate: 150),
        ExchangeRate(currencyCode: "CHF", rate: 0.9),
    ]

    private static func publishRates(to graph: HistoryTestGraph) {
        graph.ratesStore.update(rates: rates, lastUpdated: nil, isShowingSampleRates: false)
    }

    // MARK: - Watchlist

    @Test("the watchlist shows only watchlisted currencies, excludes the base, and honors the sort", .timeLimit(.minutes(1)))
    func watchlistDisplayAndSort() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["GBP", "USD", "EUR"])
        let viewModel = graph.makeListViewModel()

        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])
        #expect(viewModel.displayedCurrencies.first?.rate == 0.5)

        viewModel.sortOption = .symbol
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])

        viewModel.sortOption = .name
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])

        viewModel.sortOption = .manual
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])
    }

    @Test("searching exposes the full catalog with watchlist membership", .timeLimit(.minutes(1)))
    func searchShowsFullCatalog() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
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
    func toggleFromSearch() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 1 }

        viewModel.toggleWatchlist("CHF")
        #expect(viewModel.isInWatchlist("CHF") == true)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "CHF"])

        viewModel.toggleWatchlist("CHF")
        #expect(viewModel.isInWatchlist("CHF") == false)
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR"])
    }

    @Test("removeFromWatchlist(atOffsets:) deletes the row at the displayed offset", .timeLimit(.minutes(1)))
    func removeAtOffsets() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR", "GBP", "JPY"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 3 }

        viewModel.removeFromWatchlist(atOffsets: IndexSet(integer: 1))

        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "JPY"])
        #expect(viewModel.isInWatchlist("GBP") == false)
    }

    @Test("a watchlist holding only the hidden base currency counts as empty", .timeLimit(.minutes(1)))
    func watchlistWithOnlyBaseIsEmpty() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["USD", "EUR"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 1 }
        #expect(viewModel.isWatchlistEmpty == false)

        viewModel.removeFromWatchlist(atOffsets: IndexSet(integer: 0))

        #expect(viewModel.isWatchlistEmpty == true)
    }

    @Test("offline with no rates, a saved watchlist waits for a connection, then shows once rates arrive", .timeLimit(.minutes(1)))
    func offlineWithoutRatesWaitsForConnection() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR", "GBP"])
        try await graph.goOffline()
        let viewModel = graph.makeListViewModel()

        #expect(viewModel.isWatchlistEmpty == false)
        #expect(viewModel.isWaitingForConnection)

        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        #expect(viewModel.isWaitingForConnection == false)
    }

    @Test("online with no rates yet, a saved watchlist shows rates loading until they arrive", .timeLimit(.minutes(1)))
    func onlineWithoutRatesShowsLoading() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR", "GBP"])
        try await graph.goOnline()
        let viewModel = graph.makeListViewModel()

        #expect(viewModel.isLoadingRates)
        #expect(viewModel.isWaitingForConnection == false)

        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        #expect(viewModel.isLoadingRates == false)
    }

    @Test("an empty watchlist shows its own empty state even without rates", .timeLimit(.minutes(1)))
    func emptyWatchlistWithoutRatesStaysEmptyWatchlist() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: [])
        try await graph.goOffline()
        let viewModel = graph.makeListViewModel()

        #expect(viewModel.isWatchlistEmpty)
        #expect(viewModel.isWaitingForConnection == false)
        #expect(viewModel.isLoadingRates == false)
    }

    @Test("moveWatchlist reorders by displayed offset while the hidden base stays put", .timeLimit(.minutes(1)))
    func moveReorders() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["USD", "EUR", "GBP", "JPY"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 3 }
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP", "JPY"])

        viewModel.moveWatchlist(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(viewModel.displayedCurrencies.map(\.code) == ["JPY", "EUR", "GBP"])
        #expect(graph.watchlist.codes.elements == ["USD", "JPY", "EUR", "GBP"])
    }

    @Test("an external watchlist reset refreshes the displayed list without a rates change", .timeLimit(.minutes(1)))
    func externalWatchlistResetRefreshesDisplayedList() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["GBP", "EUR"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        graph.watchlist.reset(to: ["JPY", "CHF"])
        await waitUntil { viewModel.displayedCurrencies.map(\.code) == ["JPY", "CHF"] }

        graph.watchlist.reset(to: ["EUR", "GBP"])
        await waitUntil { viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"] }
    }

    @Test("the list starts on the default base currency from Settings, not the converter's", .timeLimit(.minutes(1)))
    func startsOnDefaultBaseCurrency() async throws {
        let graph = try HistoryTestGraph(
            watchlistSeed: ["EUR", "GBP"],
            preferences: InMemoryPreferencesStore(defaultBaseCurrency: "EUR")
        )
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)

        await waitUntil { !viewModel.displayedCurrencies.isEmpty }

        #expect(viewModel.baseCurrency == "EUR")
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP"])
        let gbp = try #require(viewModel.displayedCurrencies.first)
        #expect(abs(gbp.rate - 0.625) < 0.0001)
    }

    @Test("the list follows a new default base currency from Settings", .timeLimit(.minutes(1)))
    func followsSettingsDefaultBase() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR", "GBP"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        graph.preferences.defaultBaseCurrency = "EUR"
        await waitUntil(timeout: .seconds(2)) { viewModel.displayedCurrencies.count == 1 }

        #expect(viewModel.baseCurrency == "EUR")
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP"])
    }

    @Test("a base picked in History is kept after relaunch and no longer follows Settings", .timeLimit(.minutes(1)))
    func pickedBaseOutlastsRelaunchAndSettings() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR", "GBP"])
        graph.makeListViewModel().selectBase("GBP")

        let relaunched = graph.makeListViewModel()
        Self.publishRates(to: graph)
        graph.preferences.defaultBaseCurrency = "EUR"
        await waitUntil { relaunched.displayedCurrencies.count == 1 }

        #expect(relaunched.baseCurrency == "GBP")
        #expect(relaunched.displayedCurrencies.map(\.code) == ["EUR"])
    }

    @Test("once History's base pick is cleared, the list follows the Settings default again", .timeLimit(.minutes(1)))
    func clearedPickFollowsDefaultAgain() async throws {
        let graph = try HistoryTestGraph(
            watchlistSeed: ["EUR", "GBP"],
            preferences: InMemoryPreferencesStore(defaultBaseCurrency: "EUR")
        )
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        viewModel.selectBase("USD")
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        graph.historyBase.clear()
        await waitUntil { viewModel.displayedCurrencies.count == 1 }

        #expect(viewModel.baseCurrency == "EUR")
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP"])
    }

    @Test("a saved base the rates no longer list falls back to the Settings default", .timeLimit(.minutes(1)))
    func pickMissingFromRatesFallsBackToDefault() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR", "GBP"])
        graph.historyBase.pick("NZD")
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)

        await waitUntil(timeout: .seconds(2)) { viewModel.displayedCurrencies.count == 2 }

        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])
    }

    @Test("picking a base currency re-expresses the list against it", .timeLimit(.minutes(1)))
    func selectingBaseReexpressesList() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR", "GBP"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        viewModel.selectBase("EUR")

        #expect(viewModel.baseCurrency == "EUR")
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP"])
        let gbp = try #require(viewModel.displayedCurrencies.first)
        #expect(abs(gbp.rate - 0.625) < 0.0001)
    }

    // MARK: - Trends

    @Test("Percentage and Price Change sorts surface the biggest weekly gainer first", .timeLimit(.minutes(1)))
    func changeSorts() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["GBP", "EUR"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await viewModel.warmUp().value
        await waitUntil { viewModel.displayedCurrencies.count == 2 }
        #expect(viewModel.displayedCurrencies.map(\.code) == ["GBP", "EUR"])

        viewModel.sortOption = .percentChange
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])

        viewModel.sortOption = .priceChange
        #expect(viewModel.displayedCurrencies.map(\.code) == ["EUR", "GBP"])
    }

    @Test("with a USD base, a row's trend is the stored USD-based trend unchanged", .timeLimit(.minutes(1)))
    func usdBaseTrendPassthrough() async throws {
        let graph = try HistoryTestGraph()
        let viewModel = graph.makeListViewModel()

        await viewModel.warmUp().value

        let gbp = viewModel.trend(for: "GBP")
        #expect(gbp?.weeklyChange == -0.5)
        #expect(gbp?.miniChartData == [0.76, 0.755, 0.753, 0.751, 0.749, 0.748, 0.75])
        #expect(viewModel.trend(for: "EUR")?.weeklyChange == 0.1)
    }

    @Test("the percent indicator shows the absolute weekly change with two decimals")
    func percentChangeDisplayValue() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()

        #expect(viewModel.trendDisplayMode == .percentChange)
        #expect(viewModel.trendDisplayValue(rate: 150, weeklyChange: -2) == "2.00%")
    }

    @Test("the price indicator shows the absolute rate move implied by the weekly change, with as many decimals as the rate")
    func priceChangeDisplayValue() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()

        viewModel.trendDisplayMode = .priceChange

        #expect(viewModel.trendDisplayValue(rate: 150, weeklyChange: -2) == "3.06")
        #expect(viewModel.trendDisplayValue(rate: 0.006351, weeklyChange: -2) == "0.000130")
    }

    // MARK: - Warm-up

    @Test("warm-up shows the stored trends and prefetches the resident year once", .timeLimit(.minutes(1)))
    func warmUpRunsEachStepOnce() async throws {
        let repository = MockHistoricalRateRepository()
        let trendRepository = MockTrendRepository(trends: SampleExchangeRates.trendData)
        let graph = try HistoryTestGraph(historicalRepository: repository, trendRepository: trendRepository)
        let viewModel = graph.makeListViewModel()

        await viewModel.warmUp().value

        #expect(graph.trendsStore.trends == SampleExchangeRates.trendData)
        #expect(Self.residentYearFetches(in: repository) == 1)
    }

    @Test("warm-up replaces last session's trends once the resident-year download brings this week's rates", .timeLimit(.minutes(1)))
    func warmUpRecalculatesTrendsAfterDownload() async throws {
        let weekStart = try #require(createCETDate(year: 2025, month: 1, day: 8))
        let today = try #require(createCETDate(year: 2025, month: 1, day: 15))
        let thisWeek = [
            HistoricalRateSnapshot(date: weekStart, rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.0)]),
            HistoricalRateSnapshot(date: today, rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.5)]),
        ]
        let repository = MockHistoricalRateRepository()
        repository.fetchedDataToReturn = thisWeek
        repository.storedRows = thisWeek
        let lastSession = [Trend(currencyCode: "EUR", weeklyChange: 9, miniChartData: [1, 1.09])]
        let graph = try HistoryTestGraph(
            historicalRepository: repository,
            trendRepository: MockTrendRepository(trends: lastSession)
        )
        let viewModel = graph.makeListViewModel()

        await viewModel.warmUp().value

        #expect(graph.trendsStore.trends == [Trend(currencyCode: "EUR", weeklyChange: 50, miniChartData: [1.0, 1.5])])
    }

    @Test("warm-up keeps last session's trends when recalculating them after the download fails", .timeLimit(.minutes(1)))
    func warmUpKeepsTrendsWhenRecalculationFails() async throws {
        let repository = MockHistoricalRateRepository()
        repository.fetchedDataToReturn = [
            HistoricalRateSnapshot(
                date: try #require(createCETDate(year: 2025, month: 1, day: 15)),
                rates: [HistoricalRatePoint(currencyCode: "EUR", rate: 1.5)]
            ),
        ]
        let lastSession = [Trend(currencyCode: "EUR", weeklyChange: 9, miniChartData: [1, 1.09])]
        let trendRepository = MockTrendRepository(trends: lastSession)
        trendRepository.shouldThrowOnSave = true
        let graph = try HistoryTestGraph(historicalRepository: repository, trendRepository: trendRepository)
        let viewModel = graph.makeListViewModel()

        await viewModel.warmUp().value

        #expect(graph.trendsStore.trends == lastSession)
    }

    @Test("a failing warm-up is logged, never shown as an alert", .timeLimit(.minutes(1)))
    func warmUpFailureRaisesNoAlert() async throws {
        let repository = MockHistoricalRateRepository()
        repository.shouldThrowErrorOnFetch = true
        let trendRepository = MockTrendRepository()
        trendRepository.shouldThrowOnLoadTrends = true
        let graph = try HistoryTestGraph(historicalRepository: repository, trendRepository: trendRepository)
        let viewModel = graph.makeListViewModel()

        await viewModel.warmUp().value

        #expect(graph.appState.errorHandler.currentError == nil)
        #expect(graph.trendsStore.trends.isEmpty)
    }

    @Test("a second warm-up cancels the first, which then writes nothing and prefetches nothing", .timeLimit(.minutes(1)))
    func secondWarmUpCancelsFirst() async throws {
        let repository = MockHistoricalRateRepository()
        let stale = [Trend(currencyCode: "EUR", weeklyChange: 9, miniChartData: [1, 1.09])]
        let fresh = [Trend(currencyCode: "EUR", weeklyChange: 1, miniChartData: [1, 1.01])]
        let trendRepository = FirstLoadGatedTrendRepository(firstLoad: stale, laterLoads: fresh)
        let graph = try HistoryTestGraph(historicalRepository: repository, trendRepository: trendRepository)
        let viewModel = graph.makeListViewModel()

        let first = viewModel.warmUp()
        await waitUntil { trendRepository.loadCount == 1 }
        let second = viewModel.warmUp()
        await second.value
        trendRepository.releaseFirstLoad()
        await first.value

        #expect(graph.trendsStore.trends == fresh)
        #expect(Self.residentYearFetches(in: repository) == 1)
    }

    @Test("a data reset clears the shown trends and warms up again", .timeLimit(.minutes(1)))
    func dataResetRewarms() async throws {
        let fresh = [Trend(currencyCode: "EUR", weeklyChange: 1, miniChartData: [1, 1.01])]
        let trendRepository = MockTrendRepository(trends: fresh)
        let graph = try HistoryTestGraph(historicalRepository: MockHistoricalRateRepository(), trendRepository: trendRepository)
        let viewModel = graph.makeListViewModel()
        graph.trendsStore.replace(with: [Trend(currencyCode: "GBP", weeklyChange: 3, miniChartData: [1, 1.03])])

        graph.appState.dataWasReset()

        await waitUntil { graph.trendsStore.trends == fresh }
        #expect(viewModel.trend(for: "GBP") == nil)
    }

    @Test("a data reset clears the shown trends even when the warm-up after it fails", .timeLimit(.minutes(1)))
    func dataResetClearsTrends() async throws {
        let repository = MockHistoricalRateRepository()
        repository.shouldThrowErrorOnFetch = true
        let trendRepository = MockTrendRepository()
        trendRepository.shouldThrowOnLoadTrends = true
        let graph = try HistoryTestGraph(historicalRepository: repository, trendRepository: trendRepository)
        let viewModel = graph.makeListViewModel()
        graph.trendsStore.replace(with: [Trend(currencyCode: "GBP", weeklyChange: 3, miniChartData: [1, 1.03])])

        graph.appState.dataWasReset()

        await waitUntil { trendRepository.loadTrendDataCallCount == 1 }
        #expect(graph.trendsStore.trends.isEmpty)
        #expect(viewModel.trend(for: "GBP") == nil)
    }

    // MARK: - Navigation

    @Test("opening a currency shows its chart, paired with the list's base")
    func openHistoryShowsChart() throws {
        let graph = try HistoryTestGraph()
        let viewModel = graph.makeListViewModel()
        viewModel.selectBase("EUR")

        viewModel.openHistory(for: "GBP")

        #expect(viewModel.selection?.link == HistoryLink(base: "EUR", target: "GBP"))
    }

    @Test("picking a currency in the list shows its chart, paired with the list's base")
    func pickingCurrencyShowsChart() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()
        viewModel.selectBase("EUR")

        viewModel.selectedCurrency = "GBP"

        #expect(viewModel.selection?.link == HistoryLink(base: "EUR", target: "GBP"))
    }

    @Test("picking the currency already showing keeps its chart instead of reloading it")
    func pickingShownCurrencyKeepsChart() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()
        viewModel.openHistory(for: "GBP")
        let shown = viewModel.selection

        viewModel.selectedCurrency = "GBP"

        #expect(viewModel.selection == shown)
    }

    @Test("clearing the list's pick closes the chart")
    func clearingPickClosesChart() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()
        viewModel.openHistory(for: "GBP")

        viewModel.selectedCurrency = nil

        #expect(viewModel.selection == nil)
    }

    @Test("on a tall screen the open chart is the one screen pushed over the list")
    func pathHoldsOpenChart() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()

        viewModel.openHistory(for: "GBP")

        #expect(viewModel.path.map(\.link) == [HistoryLink(base: "USD", target: "GBP")])
    }

    @Test("going back to the list on a tall screen closes the chart")
    func poppingPathClosesChart() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()
        viewModel.openHistory(for: "GBP")

        viewModel.path = []

        #expect(viewModel.selection == nil)
    }

    @Test("with nothing picked, the always-visible chart shows the first listed currency on the list's base", .timeLimit(.minutes(1)))
    func chartDefaultsToFirstListedCurrency() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["GBP", "EUR"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 2 }
        viewModel.selectBase("CHF")

        #expect(viewModel.chartLink == HistoryLink(base: "CHF", target: "GBP"))
    }

    @Test("the always-visible chart shows the picked currency")
    func chartShowsPickedCurrency() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()

        viewModel.open(HistoryLink(base: "JPY", target: "EUR"))

        #expect(viewModel.chartLink == HistoryLink(base: "JPY", target: "EUR"))
    }

    @Test("with nothing picked and an empty list, there is no chart to show")
    func noChartForEmptyList() throws {
        let viewModel = try HistoryTestGraph(watchlistSeed: []).makeListViewModel()

        #expect(viewModel.chartLink == nil)
    }

    @Test("the chart screen's model shows the pair it was opened for")
    func historyViewModelUsesThePair() throws {
        let graph = try HistoryTestGraph()
        let viewModel = graph.makeListViewModel()

        let history = viewModel.historyViewModel(for: HistoryLink(base: "CHF", target: "GBP"))

        #expect(history.baseCurrency == "CHF")
        #expect(history.targetCurrency == "GBP")
    }

    @Test("the chart screen opens on the time range its link names")
    func historyViewModelUsesTheLinkRange() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()

        let history = viewModel.historyViewModel(for: HistoryLink(base: "USD", target: "IDR", period: .oneWeek))

        #expect(history.selectedTimeRange == .oneWeek)
        #expect(history.chartSeriesID == CurrencyHistoryViewModel.ChartSeriesID(currency: "IDR", range: .oneWeek))
    }

    @Test("recreating the selected chart's view keeps its range, base, and chart options")
    func recreatingChartViewKeepsItsState() async throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()
        let link = HistoryLink(base: "USD", target: "GBP")
        viewModel.open(link)
        let chart = viewModel.historyViewModel(for: link)
        chart.selectedTimeRange = .oneYear
        chart.selectBase("JPY")
        chart.showAverageLine = true
        await chart.loadChart()

        let recreated = viewModel.historyViewModel(for: link)

        #expect(recreated.selectedTimeRange == .oneYear)
        #expect(recreated.baseCurrency == "JPY")
        #expect(recreated.showAverageLine)
    }

    @Test("an explicit new visit to the same chart starts on the link's base, range, and default options")
    func reopeningChartStartsFresh() async throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()
        let link = HistoryLink(base: "USD", target: "GBP")
        viewModel.open(link)
        let chart = viewModel.historyViewModel(for: link)
        chart.selectedTimeRange = .oneYear
        chart.selectBase("JPY")
        chart.showAverageLine = true
        await chart.loadChart()

        viewModel.open(link)
        let reopened = viewModel.historyViewModel(for: link)

        #expect(reopened.selectedTimeRange == .threeMonths)
        #expect(reopened.baseCurrency == "USD")
        #expect(reopened.showAverageLine == false)
    }

    @Test("a base picked on the chart screen stays there, and the next chart opens on the list's base")
    func chartBaseStaysOnChartScreen() async throws {
        let graph = try HistoryTestGraph()
        let viewModel = graph.makeListViewModel()
        viewModel.selectBase("EUR")
        viewModel.openHistory(for: "GBP")
        let link = try #require(viewModel.selection?.link)
        let chart = viewModel.historyViewModel(for: link)

        chart.selectBase("JPY")
        await chart.loadChart()
        viewModel.openHistory(for: "CHF")

        #expect(chart.baseCurrency == "JPY")
        #expect(viewModel.baseCurrency == "EUR")
        #expect(viewModel.selection?.link == HistoryLink(base: "EUR", target: "CHF"))
    }

    // MARK: - Base Picker

    @Test("tapping the base currency opens the base picker")
    func baseCurrencyTapOpensPicker() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()

        viewModel.baseCurrencyTapped()

        #expect(viewModel.destination == .basePicker)
    }

    @Test("the base picker offers the saved favorites and every rate")
    func basePickerOptions() throws {
        let graph = try HistoryTestGraph(favoritesSeed: ["GBP", "USD"])
        Self.publishRates(to: graph)
        let viewModel = graph.makeListViewModel()

        #expect(viewModel.basePickerFavorites == ["GBP", "USD"])
        #expect(viewModel.basePickerRates == Self.rates)
    }

    // MARK: - Links

    @Test("a widget link switches to History and shows only that pair's chart")
    func widgetLinkOpensThePair() throws {
        let graph = try HistoryTestGraph()
        let viewModel = graph.makeListViewModel()
        viewModel.openHistory(for: "GBP")
        let link = HistoryLink(base: "JPY", target: "EUR")

        viewModel.open(link)

        #expect(graph.appState.selectedTab == .history)
        #expect(viewModel.selection?.link == link)
    }

    @Test("a link for the chart already showing opens it again fresh, on the link's base")
    func linkReopensShownChart() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()
        let link = HistoryLink(base: "EUR", target: "GBP")
        viewModel.open(link)
        let shown = viewModel.selection

        viewModel.open(link)

        #expect(viewModel.selection != shown)
        #expect(viewModel.selection?.link == link)
    }

    @Test("a link closes the base picker so the chart it opens is visible")
    func linkClosesBasePicker() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()
        viewModel.baseCurrencyTapped()

        viewModel.open(HistoryLink(base: "EUR", target: "GBP"))

        #expect(viewModel.destination == nil)
    }

    // MARK: - Helpers

    private static func residentYearFetches(in repository: MockHistoricalRateRepository) -> Int {
        repository.fetchHistoricalRatesCalls.filter { call in
            let days = CETCalendar.calendar.dateComponents([.day], from: call.from, to: call.to).day ?? 0
            return (364 ... 366).contains(days)
        }.count
    }
}

private final class FirstLoadGatedTrendRepository: TrendRepository {
    private let firstLoad: [Trend]
    private let laterLoads: [Trend]
    private let continuation: AsyncStream<Void>.Continuation
    private let gate: Task<Void, Never>

    private(set) var loadCount = 0

    init(firstLoad: [Trend], laterLoads: [Trend]) {
        self.firstLoad = firstLoad
        self.laterLoads = laterLoads
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        self.continuation = continuation
        gate = Task { for await _ in stream {} }
    }

    func releaseFirstLoad() {
        continuation.finish()
    }

    func loadTrendData() async throws -> [Trend] {
        loadCount += 1
        guard loadCount == 1 else { return laterLoads }
        await gate.value
        return firstLoad
    }

    func saveTrendData(_: [Trend]) async throws {}

    func loadHistoricalRates(from _: Date, to _: Date) async throws -> [HistoricalRateSnapshot] {
        []
    }
}
