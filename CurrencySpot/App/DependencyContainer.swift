import AppIntents
import Foundation
import SwiftData
import WidgetKit

// MARK: - DependencyContainer

final class DependencyContainer {
    // MARK: - Shared State and ViewModels

    let appState: AppState
    let ratesStore: ExchangeRatesStore
    let calculatorViewModel: CalculatorViewModel
    let conversionHistoryViewModel: ConversionHistoryViewModel
    let currencyListViewModel: CurrencyListViewModel
    let settingsViewModel: SettingsViewModel
    let cameraViewModel: CameraViewModel
    let convertCurrencyUseCase: ConvertCurrencyUseCase
    private let sharedSettingsMirror: SharedSettingsMirror

    private let makeHistoryViewModel: @MainActor (HistoryLink) -> CurrencyHistoryViewModel

    // MARK: - Initialization

    init(
        modelContainer: ModelContainer? = nil,
        appState: AppState = .shared,
        userDefaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults = .appGroup,
        preferences: PreferencesStore? = nil,
        languageStore: AppLanguageStore? = nil,
        retryPolicy: RetryPolicy = RetryPolicy(),
        networkService: NetworkService? = nil,
        persistenceService: PersistenceService? = nil,
        cacheService: CacheService = InMemoryCacheService(),
        syncStore: HistoricalSyncStore? = nil,
        fetchDateStore: RatesFetchDateStore? = nil,
        exchangeRateRepository: ExchangeRateRepository? = nil,
        historicalRepository: (any HistoricalRateRepository & ArchiveRepository)? = nil,
        dateProvider: DateProvider = SystemDateProvider(),
        clockService: ClockService = ContinuousClockService(),
        cameraPermissionService: CameraPermissionService = AVCameraPermissionService(),
        stillTextRecognizer: StillTextRecognitionService = StillImageTextRecognizer(),
        torchService: TorchService = AVTorchService()
    ) {
        let preferences = preferences ?? UserDefaultsPreferencesStore(userDefaults: userDefaults)
        let languageStore = languageStore ?? UserDefaultsAppLanguageStore(
            userDefaults: userDefaults,
            domainName: Bundle.main.bundleIdentifier ?? "",
            availableIdentifiers: Bundle.main.localizations.filter { $0 != "Base" }.sorted()
        )
        let dataCoordinator = DataCoordinator(
            networkService: networkService ?? FrankfurterNetworkService(
                api: FrankfurterAPI(
                    session: FrankfurterAPI.makeDefaultSession(),
                    retryPolicy: retryPolicy,
                    clock: clockService
                )
            ),
            persistenceService: persistenceService ?? SwiftDataPersistenceService(
                modelContainer: modelContainer ?? ModelContainerFactory.inMemoryContainer()
            ),
            cacheService: cacheService,
            syncStore: syncStore ?? UserDefaultsHistoricalSyncStore(defaults: userDefaults),
            fetchDateStore: fetchDateStore ?? UserDefaultsRatesFetchDateStore(defaults: userDefaults),
            dateProvider: dateProvider
        )
        let historicalRepository = historicalRepository ?? dataCoordinator

        let historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(
            syncCoverage: dataCoordinator,
            dateProvider: dateProvider
        )
        let backfillArchiveUseCase = BackfillArchiveUseCase(
            archive: historicalRepository,
            analysis: historicalDataAnalysisUseCase,
            clock: clockService
        )
        let loadHistoricalRatesUseCase = LoadHistoricalRatesUseCase(
            repository: historicalRepository,
            archive: historicalRepository,
            backfill: backfillArchiveUseCase,
            analysis: historicalDataAnalysisUseCase
        )
        let chartDataPreparationUseCase = ChartDataPreparationUseCase()
        let trendDataUseCase = TrendDataUseCase(
            trendRepository: dataCoordinator,
            historicalRateRepository: historicalRepository,
            dateProvider: dateProvider
        )
        let refreshAllDataUseCase = RefreshAllDataUseCase(
            repository: dataCoordinator,
            backfill: backfillArchiveUseCase
        )
        let loadExchangeRatesUseCase = LoadExchangeRatesUseCase(
            repository: exchangeRateRepository ?? dataCoordinator,
            dateProvider: dateProvider
        )
        let calculateConversionUseCase = CalculateConversionUseCase()

        let ratesStore = ExchangeRatesStore()
        let trendsStore = TrendsStore()
        let favoritesStore = CurrencyCodeListStore.favorites(in: userDefaults)
        let watchlistStore = CurrencyCodeListStore.watchlist(in: userDefaults, seededFrom: favoritesStore)
        let conversionHistoryStore = ConversionHistoryStore(defaults: userDefaults)

        let makeHistoryViewModel: @MainActor (HistoryLink) -> CurrencyHistoryViewModel = {
            [ratesStore, favoritesStore, trendsStore, loadHistoricalRatesUseCase, chartDataPreparationUseCase, trendDataUseCase, preferences, appState, clockService] link in
            CurrencyHistoryViewModel(
                base: link.base,
                target: link.target,
                timeRange: link.period,
                ratesStore: ratesStore,
                favorites: favoritesStore,
                trendsStore: trendsStore,
                loadHistoricalRates: loadHistoricalRatesUseCase,
                chartDataPreparation: chartDataPreparationUseCase,
                trendDataUseCase: trendDataUseCase,
                preferences: preferences,
                appState: appState,
                clock: clockService,
                waitLimitClock: clockService
            )
        }

        self.appState = appState
        self.ratesStore = ratesStore
        self.makeHistoryViewModel = makeHistoryViewModel
        convertCurrencyUseCase = ConvertCurrencyUseCase(loadExchangeRates: loadExchangeRatesUseCase, clock: clockService)

        calculatorViewModel = CalculatorViewModel(
            loadExchangeRatesUseCase: loadExchangeRatesUseCase,
            calculateConversionUseCase: calculateConversionUseCase,
            ratesStore: ratesStore,
            preferences: preferences,
            favorites: favoritesStore,
            history: conversionHistoryStore,
            dateProvider: dateProvider,
            appState: appState
        )

        conversionHistoryViewModel = ConversionHistoryViewModel(store: conversionHistoryStore) {
            [calculatorViewModel] record in calculatorViewModel.restore(record)
        }

        currencyListViewModel = CurrencyListViewModel(
            baseCurrency: preferences.defaultBaseCurrency,
            ratesStore: ratesStore,
            favorites: favoritesStore,
            watchlist: watchlistStore,
            trendsStore: trendsStore,
            trendDataUseCase: trendDataUseCase,
            loadHistoricalRates: loadHistoricalRatesUseCase,
            backfillArchive: backfillArchiveUseCase,
            buildCurrencyList: BuildCurrencyListUseCase(),
            appState: appState,
            makeHistoryViewModel: makeHistoryViewModel
        )

        settingsViewModel = SettingsViewModel(
            refreshAllDataUseCase: refreshAllDataUseCase,
            resetPreferencesUseCase: ResetPreferencesUseCase(
                preferences: preferences,
                favorites: favoritesStore,
                watchlist: watchlistStore,
                language: languageStore
            ),
            manageFavoritesUseCase: ManageFavoritesUseCase(favorites: favoritesStore),
            preferences: preferences,
            languageStore: languageStore,
            appState: appState,
            clock: clockService
        )

        cameraViewModel = CameraViewModel(
            ratesStore: ratesStore,
            appState: appState,
            permissionService: cameraPermissionService,
            torchService: torchService,
            scanConversionUseCase: ScanConversionUseCase(),
            recognizeStillImageTextUseCase: RecognizeStillImageTextUseCase(recognizer: stillTextRecognizer),
            calculateConversionUseCase: calculateConversionUseCase,
            localeCurrencyCode: Locale.current.currency.flatMap { CurrencyCode($0.identifier) },
            fallbackBaseCurrency: preferences.defaultBaseCurrency,
            defaultTargetCurrency: preferences.defaultTargetCurrency
        )

        sharedSettingsMirror = SharedSettingsMirror(
            favorites: favoritesStore,
            preferences: preferences,
            ratesStore: ratesStore,
            shared: sharedDefaults,
            favoritesChanged: { CurrencySpotShortcuts.updateAppShortcutParameters() },
            ratesRefreshed: { WidgetCenter.shared.reloadAllTimelines() }
        )
    }

    // MARK: - Factories

    func makeCurrencyHistoryViewModel(base: CurrencyCode, target: CurrencyCode) -> CurrencyHistoryViewModel {
        makeHistoryViewModel(HistoryLink(base: base, target: target))
    }

    // MARK: - Bootstrap

    static func bootstrap(appState: AppState) -> DependencyContainer {
        let container = ModelContainerFactory.persistentContainer(
            storeURL: ModelConfiguration().url,
            defaults: .standard,
            errorHandler: appState.errorHandler
        )
        let dependencies = DependencyContainer(modelContainer: container, appState: appState)
        dependencies.sharedSettingsMirror.start()
        return dependencies
    }
}
