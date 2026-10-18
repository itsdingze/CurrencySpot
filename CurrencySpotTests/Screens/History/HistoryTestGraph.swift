@testable import CurrencySpot
import Foundation
import Testing

struct HistoryTestGraph {
    let today: Date
    let ratesStore = ExchangeRatesStore()
    let trendsStore = TrendsStore()
    let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))
    let preferences: InMemoryPreferencesStore
    let watchlist: CurrencyCodeListStore
    let loadHistoricalRates: LoadHistoricalRatesUseCase
    let trendDataUseCase: TrendDataUseCase

    private let backfillArchive: BackfillArchiveUseCase
    private let chartDataPreparation: ChartDataPreparationUseCase
    private let isolatedDefaults: IsolatedDefaults

    init(
        historicalRepository: (any HistoricalRateRepository & ArchiveRepository)? = nil,
        trendRepository: (any TrendRepository)? = nil,
        watchlistSeed: [CurrencyCode] = CurrencyDefaults.favoriteCurrencies,
        preferences: InMemoryPreferencesStore = InMemoryPreferencesStore()
    ) throws {
        let today = try #require(createCETDate(year: 2025, month: 1, day: 15))
        let fixture = PreviewExchangeRateRepository(today: today)
        let repository: any HistoricalRateRepository & ArchiveRepository = historicalRepository ?? fixture
        let dateProvider = FixedDateProvider(today)
        let analysis = HistoricalDataAnalysisUseCase(syncCoverage: MockHistoricalSyncStore(), dateProvider: dateProvider)
        let backfillArchive = BackfillArchiveUseCase(archive: repository, analysis: analysis, clock: ImmediateClock())
        let isolatedDefaults = IsolatedDefaults()

        self.today = today
        self.preferences = preferences
        self.isolatedDefaults = isolatedDefaults
        self.backfillArchive = backfillArchive
        watchlist = CurrencyCodeListStore(
            defaults: try isolatedDefaults.make(),
            key: UserDefaultsKeys.historyWatchlist,
            seed: watchlistSeed
        )
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
        chartDataPreparation = ChartDataPreparationUseCase(chartCache: InMemoryChartDataCache())
    }

    func makeListViewModel() -> CurrencyListViewModel {
        CurrencyListViewModel(
            ratesStore: ratesStore,
            watchlist: watchlist,
            trendsStore: trendsStore,
            trendDataUseCase: trendDataUseCase,
            loadHistoricalRates: loadHistoricalRates,
            backfillArchive: backfillArchive,
            buildCurrencyList: BuildCurrencyListUseCase(),
            appState: appState,
            makeHistoryViewModel: makeHistoryViewModel(base:target:)
        )
    }

    func makeHistoryViewModel(base: CurrencyCode = .usd, target: CurrencyCode = .eur) -> CurrencyHistoryViewModel {
        CurrencyHistoryViewModel(
            base: base,
            target: target,
            ratesStore: ratesStore,
            trendsStore: trendsStore,
            loadHistoricalRates: loadHistoricalRates,
            chartDataPreparation: chartDataPreparation,
            trendDataUseCase: trendDataUseCase,
            preferences: preferences,
            appState: appState,
            clock: ImmediateClock()
        )
    }
}
