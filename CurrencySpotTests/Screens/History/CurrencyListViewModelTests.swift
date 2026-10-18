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

    @Test("a base currency change re-expresses the list against the new base", .timeLimit(.minutes(1)))
    func followsSharedBaseCurrency() async throws {
        let graph = try HistoryTestGraph(watchlistSeed: ["EUR", "GBP"])
        let viewModel = graph.makeListViewModel()
        Self.publishRates(to: graph)
        await waitUntil { viewModel.displayedCurrencies.count == 2 }

        graph.ratesStore.updateBaseCurrency("EUR")

        await waitUntil { viewModel.displayedCurrencies.map(\.code) == ["GBP"] }
        #expect(viewModel.baseCurrency == "EUR")
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

    @Test("the price indicator shows the absolute rate move implied by the weekly change")
    func priceChangeDisplayValue() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()

        viewModel.trendDisplayMode = .priceChange

        #expect(viewModel.trendDisplayValue(rate: 150, weeklyChange: -2) == "3")
    }

    // MARK: - Warm-up

    @Test("warm-up loads the stored trends once and prefetches the resident year once", .timeLimit(.minutes(1)))
    func warmUpRunsEachStepOnce() async throws {
        let repository = MockHistoricalRateRepository()
        let trendRepository = MockTrendRepository(trends: SampleExchangeRates.trendData)
        let graph = try HistoryTestGraph(historicalRepository: repository, trendRepository: trendRepository)
        let viewModel = graph.makeListViewModel()

        await viewModel.warmUp().value

        #expect(trendRepository.loadTrendDataCallCount == 1)
        #expect(graph.trendsStore.trends == SampleExchangeRates.trendData)
        #expect(Self.residentYearFetches(in: repository) == 1)
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

    @Test("opening a currency pushes it onto the navigation path")
    func openHistoryPushes() throws {
        let viewModel = try HistoryTestGraph().makeListViewModel()

        viewModel.openHistory(for: "GBP")

        #expect(viewModel.path == ["GBP"])
    }

    @Test("the chart screen's model pairs the picked currency with the current base")
    func historyViewModelUsesCurrentBase() throws {
        let graph = try HistoryTestGraph()
        let viewModel = graph.makeListViewModel()
        graph.ratesStore.updateBaseCurrency("EUR")

        let history = viewModel.historyViewModel(for: "GBP")

        #expect(history.baseCurrency == "EUR")
        #expect(history.targetCurrency == "GBP")
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
