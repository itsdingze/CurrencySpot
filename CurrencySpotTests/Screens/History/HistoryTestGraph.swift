@testable import CurrencySpot
import Foundation
import Testing

struct HistoryTestGraph {
    let today: Date
    let ratesStore = ExchangeRatesStore()
    let trendsStore = TrendsStore()
    let syncStore = MockHistoricalSyncStore()
    let appState: AppState
    let connectivity: AsyncStream<NetworkMonitor.Path>.Continuation
    let preferences: InMemoryPreferencesStore
    let watchlist: CurrencyCodeListStore
    let favorites: CurrencyCodeListStore
    let historyBase: HistoryBaseCurrencyStore
    let loadHistoricalRates: LoadHistoricalRatesUseCase
    let trendDataUseCase: TrendDataUseCase

    private let waitLimitClock: ClockService
    private let backfillArchive: BackfillArchiveUseCase
    private let chartDataPreparation: ChartDataPreparationUseCase
    private let isolatedDefaults: IsolatedDefaults

    init(
        historicalRepository: (any HistoricalRateRepository & ArchiveRepository)? = nil,
        trendRepository: (any TrendRepository)? = nil,
        watchlistSeed: [CurrencyCode] = CurrencyDefaults.favoriteCurrencies,
        favoritesSeed: [CurrencyCode] = CurrencyDefaults.favoriteCurrencies,
        preferences: InMemoryPreferencesStore = InMemoryPreferencesStore(),
        waitLimitClock: ClockService = GatedClock()
    ) throws {
        let today = try #require(createCETDate(year: 2025, month: 1, day: 15))
        let fixture = PreviewExchangeRateRepository(today: today)
        let repository: any HistoricalRateRepository & ArchiveRepository = historicalRepository ?? fixture
        let dateProvider = FixedDateProvider(today)
        let analysis = HistoricalDataAnalysisUseCase(syncCoverage: syncStore, dateProvider: dateProvider)
        let (pathUpdates, connectivity) = AsyncStream.makeStream(of: NetworkMonitor.Path.self)
        let networkMonitor = NetworkMonitor(pathUpdates: pathUpdates)
        let backfillArchive = BackfillArchiveUseCase(
            archive: repository,
            analysis: analysis,
            networkMonitor: networkMonitor,
            clock: ImmediateClock()
        )
        let isolatedDefaults = IsolatedDefaults()

        appState = AppState(networkMonitor: networkMonitor)
        self.connectivity = connectivity
        self.waitLimitClock = waitLimitClock
        self.today = today
        self.preferences = preferences
        self.isolatedDefaults = isolatedDefaults
        self.backfillArchive = backfillArchive
        watchlist = CurrencyCodeListStore(
            defaults: try isolatedDefaults.make(),
            key: UserDefaultsKeys.historyWatchlist,
            seed: watchlistSeed
        )
        favorites = CurrencyCodeListStore(
            defaults: try isolatedDefaults.make(),
            key: UserDefaultsKeys.favoriteCurrencies,
            seed: favoritesSeed
        )
        historyBase = HistoryBaseCurrencyStore(defaults: try isolatedDefaults.make())
        loadHistoricalRates = LoadHistoricalRatesUseCase(
            repository: repository,
            archive: repository,
            backfill: backfillArchive,
            analysis: analysis
        )
        trendDataUseCase = TrendDataUseCase(
            trendRepository: trendRepository ?? fixture,
            historicalRateRepository: repository,
            dateProvider: dateProvider
        )
        chartDataPreparation = ChartDataPreparationUseCase()
    }

    func goOffline() async throws {
        try await setConnected(false)
    }

    func goOnline() async throws {
        try await setConnected(true)
    }

    private func setConnected(_ isConnected: Bool) async throws {
        connectivity.yield(NetworkMonitor.Path(isConnected: isConnected, isConstrained: false))
        let monitor = appState.networkMonitor
        await waitUntil { monitor.isConnected == isConnected }
        try #require(monitor.isConnected == isConnected)
    }

    func makeListViewModel() -> CurrencyListViewModel {
        CurrencyListViewModel(
            preferences: preferences,
            historyBase: historyBase,
            ratesStore: ratesStore,
            favorites: favorites,
            watchlist: watchlist,
            trendsStore: trendsStore,
            trendDataUseCase: trendDataUseCase,
            loadHistoricalRates: loadHistoricalRates,
            backfillArchive: backfillArchive,
            buildCurrencyList: BuildCurrencyListUseCase(),
            appState: appState,
            makeHistoryViewModel: makeHistoryViewModel(for:)
        )
    }

    func makeHistoryViewModel(base: CurrencyCode = .usd, target: CurrencyCode = .eur) -> CurrencyHistoryViewModel {
        makeHistoryViewModel(for: HistoryLink(base: base, target: target))
    }

    func makeHistoryViewModel(for link: HistoryLink) -> CurrencyHistoryViewModel {
        CurrencyHistoryViewModel(
            base: link.base,
            target: link.target,
            timeRange: link.period,
            ratesStore: ratesStore,
            favorites: favorites,
            trendsStore: trendsStore,
            loadHistoricalRates: loadHistoricalRates,
            chartDataPreparation: chartDataPreparation,
            trendDataUseCase: trendDataUseCase,
            preferences: preferences,
            appState: appState,
            clock: ImmediateClock(),
            waitLimitClock: waitLimitClock
        )
    }
}
