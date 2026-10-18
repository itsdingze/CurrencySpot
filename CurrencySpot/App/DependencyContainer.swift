import Foundation
import OSLog
import SwiftData

// MARK: - DependencyContainer

final class DependencyContainer {
    // MARK: - Shared State and ViewModels

    let appState: AppState
    let ratesStore: ExchangeRatesStore
    let calculatorViewModel: CalculatorViewModel
    let currencyListViewModel: CurrencyListViewModel
    let settingsViewModel: SettingsViewModel
    let cameraViewModel: CameraViewModel

    private let makeHistoryViewModel: @MainActor (CurrencyCode, CurrencyCode) -> CurrencyHistoryViewModel

    private static let logger = Logger(category: .app)

    // MARK: - Initialization

    init(
        modelContainer: ModelContainer? = nil,
        appState: AppState = .shared,
        userDefaults: UserDefaults = .standard,
        preferences: PreferencesStore? = nil,
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
        let chartDataPreparationUseCase = ChartDataPreparationUseCase(chartCache: dataCoordinator)
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

        let makeHistoryViewModel: @MainActor (CurrencyCode, CurrencyCode) -> CurrencyHistoryViewModel = {
            [ratesStore, trendsStore, loadHistoricalRatesUseCase, chartDataPreparationUseCase, trendDataUseCase, preferences, appState, clockService] base, target in
            CurrencyHistoryViewModel(
                base: base,
                target: target,
                ratesStore: ratesStore,
                trendsStore: trendsStore,
                loadHistoricalRates: loadHistoricalRatesUseCase,
                chartDataPreparation: chartDataPreparationUseCase,
                trendDataUseCase: trendDataUseCase,
                preferences: preferences,
                appState: appState,
                clock: clockService
            )
        }

        self.appState = appState
        self.ratesStore = ratesStore
        self.makeHistoryViewModel = makeHistoryViewModel

        calculatorViewModel = CalculatorViewModel(
            loadExchangeRatesUseCase: loadExchangeRatesUseCase,
            calculateConversionUseCase: calculateConversionUseCase,
            ratesStore: ratesStore,
            preferences: preferences,
            favorites: favoritesStore,
            appState: appState
        )

        currencyListViewModel = CurrencyListViewModel(
            ratesStore: ratesStore,
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
                watchlist: watchlistStore
            ),
            manageFavoritesUseCase: ManageFavoritesUseCase(favorites: favoritesStore),
            preferences: preferences,
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
    }

    // MARK: - Factories

    func makeCurrencyHistoryViewModel(base: CurrencyCode, target: CurrencyCode) -> CurrencyHistoryViewModel {
        makeHistoryViewModel(base, target)
    }

    // MARK: - Bootstrap

    static func bootstrap(appState: AppState) -> DependencyContainer {
        #if DEBUG
            if CommandLine.arguments.contains("enable-testing") {
                if let testContainer = try? ModelContainer.inMemoryCurrencySpot() {
                    DataMigration.runIfNeeded(modelContainer: testContainer, defaults: .standard)
                    return DependencyContainer(modelContainer: testContainer, appState: appState)
                }
                logger.fault("Failed to create test container; continuing with production ladder")
            }
        #endif

        let container = ModelContainerFactory.persistentContainer(
            storeURL: ModelConfiguration().url,
            defaults: .standard,
            errorHandler: appState.errorHandler
        )
        return DependencyContainer(modelContainer: container, appState: appState)
    }
}
