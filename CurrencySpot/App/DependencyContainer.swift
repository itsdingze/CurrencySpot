import Foundation
import SwiftData

// MARK: - ModelContainer Factory

extension ModelContainer {
    static let currencySpotSchema = Schema([
        ExchangeRateData.self,
        HistoricalRateData.self,
        TrendData.self,
    ])

    static func inMemoryCurrencySpot() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: currencySpotSchema, configurations: configuration)
    }
}

// MARK: - DependencyContainer

@Observable
final class DependencyContainer {
    // MARK: - Core Services

    let modelContainer: ModelContainer
    let appState: AppState
    let networkService: NetworkService
    let persistenceService: PersistenceService
    let cacheService: CacheService
    let syncStore: HistoricalSyncStore
    let dateProvider: DateProvider
    let clockService: ClockService
    let logger: LoggerService
    let cameraPermissionService: CameraPermissionService
    let stillTextRecognizer: StillTextRecognitionService
    let torchService: TorchService

    let dataCoordinator: DataCoordinator

    // MARK: - Use Cases

    let historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase
    let dataOrchestrationUseCase: DataOrchestrationUseCase
    let chartDataPreparationUseCase: ChartDataPreparationUseCase
    let trendDataUseCase: TrendDataUseCase
    let refreshAllDataUseCase: RefreshAllDataUseCase
    let loadExchangeRatesUseCase: LoadExchangeRatesUseCase
    let calculateConversionUseCase: CalculateConversionUseCase
    let scanConversionUseCase: ScanConversionUseCase

    // MARK: - Shared State and ViewModels

    let ratesStore: ExchangeRatesStore
    let watchlistStore: WatchlistStore
    let calculatorViewModel: CalculatorViewModel
    let historyViewModel: HistoryViewModel
    let settingsViewModel: SettingsViewModel
    let cameraViewModel: CameraViewModel

    // MARK: - Initialization

    init(
        modelContainer: ModelContainer? = nil,
        appState: AppState = .shared,
        userDefaults: UserDefaults = .standard,
        preferences: PreferencesStore = UserDefaultsPreferencesStore(),
        retryManager: RetryManager = RetryManager(),
        networkService: NetworkService? = nil,
        persistenceService: PersistenceService? = nil,
        cacheService: CacheService = InMemoryCacheService(),
        syncStore: HistoricalSyncStore = UserDefaultsHistoricalSyncStore(),
        dateProvider: DateProvider = SystemDateProvider(),
        clockService: ClockService = ContinuousClockService(),
        logger: LoggerService = OSLogLoggerService(),
        cameraPermissionService: CameraPermissionService = AVCameraPermissionService(),
        stillTextRecognizer: StillTextRecognitionService = StillImageTextRecognizer(),
        torchService: TorchService = AVTorchService()
    ) {
        let resolvedModelContainer = modelContainer ?? Self.inMemoryFallbackContainer()
        self.modelContainer = resolvedModelContainer
        self.appState = appState
        self.networkService = networkService ?? FrankfurterNetworkService(
            api: FrankfurterAPI(retryManager: retryManager),
            userDefaults: userDefaults,
            dateProvider: dateProvider
        )
        self.persistenceService = persistenceService ?? SwiftDataPersistenceService(
            modelContainer: resolvedModelContainer,
            logger: logger
        )
        self.cacheService = cacheService
        self.syncStore = syncStore
        self.dateProvider = dateProvider
        self.clockService = clockService
        self.logger = logger
        self.cameraPermissionService = cameraPermissionService
        self.stillTextRecognizer = stillTextRecognizer
        self.torchService = torchService

        dataCoordinator = DataCoordinator(
            networkService: self.networkService,
            persistenceService: self.persistenceService,
            cacheService: cacheService,
            syncStore: syncStore,
            dateProvider: dateProvider,
            logger: logger
        )

        historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(
            syncCoverage: dataCoordinator,
            dateProvider: dateProvider,
            logger: logger
        )

        dataOrchestrationUseCase = DataOrchestrationUseCase(
            repository: dataCoordinator,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dateProvider: dateProvider,
            logger: logger,
            clock: clockService
        )

        chartDataPreparationUseCase = ChartDataPreparationUseCase(
            chartCache: dataCoordinator,
            logger: logger
        )

        trendDataUseCase = TrendDataUseCase(
            trendRepository: dataCoordinator,
            historicalRateRepository: dataCoordinator,
            dateProvider: dateProvider,
            logger: logger
        )

        refreshAllDataUseCase = RefreshAllDataUseCase(repository: dataCoordinator)
        loadExchangeRatesUseCase = LoadExchangeRatesUseCase(repository: dataCoordinator)
        calculateConversionUseCase = CalculateConversionUseCase()
        scanConversionUseCase = ScanConversionUseCase()

        ratesStore = ExchangeRatesStore()
        watchlistStore = WatchlistStore(
            userDefaults: userDefaults,
            seed: preferences.favoriteCurrencies.elements
        )

        calculatorViewModel = CalculatorViewModel(
            loadExchangeRatesUseCase: loadExchangeRatesUseCase,
            calculateConversionUseCase: calculateConversionUseCase,
            ratesStore: ratesStore,
            preferences: preferences,
            appState: appState
        )

        historyViewModel = HistoryViewModel(
            ratesStore: ratesStore,
            watchlist: watchlistStore,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase,
            buildCurrencyList: BuildCurrencyListUseCase(),
            preferences: preferences,
            appState: appState,
            clock: clockService,
            logger: logger
        )

        settingsViewModel = SettingsViewModel(
            refreshAllDataUseCase: refreshAllDataUseCase,
            watchlist: watchlistStore,
            preferences: preferences,
            appState: appState,
            clock: clockService,
            logger: logger
        )

        cameraViewModel = CameraViewModel(
            ratesStore: ratesStore,
            appState: appState,
            permissionService: cameraPermissionService,
            scanConversionUseCase: scanConversionUseCase,
            calculateConversionUseCase: calculateConversionUseCase,
            stillTextRecognizer: stillTextRecognizer,
            torchService: torchService,
            fallbackBaseCurrency: preferences.defaultBaseCurrency,
            defaultTargetCurrency: preferences.defaultTargetCurrency,
            logger: logger
        )

        refreshAllDataUseCase.registerResetHandler { [calculatorViewModel] in
            calculatorViewModel.clearAllData()
        }
        refreshAllDataUseCase.registerResetHandler { [historyViewModel] in
            historyViewModel.clearAllData()
        }
        refreshAllDataUseCase.registerResetHandler { [dataOrchestrationUseCase, calculatorViewModel, historyViewModel] in
            dataOrchestrationUseCase.dropInFlightFetches()
            await calculatorViewModel.checkIfShouldFetch()
            Task {
                historyViewModel.loadDataForCurrentConfiguration()
                await historyViewModel.initializeTrendData()
                await historyViewModel.prefetchHistoricalWindow()
            }
        }
    }

    // MARK: - Bootstrap

    private static func inMemoryFallbackContainer() -> ModelContainer {
        do {
            return try ModelContainer.inMemoryCurrencySpot()
        } catch {
            fatalError("CurrencySpot cannot start: SwiftData is unavailable (\(error))")
        }
    }

    static func bootstrap(appState: AppState = .shared) -> DependencyContainer {
        let logger = OSLogLoggerService()

        #if DEBUG
            if CommandLine.arguments.contains("enable-testing") {
                if let testContainer = try? ModelContainer.inMemoryCurrencySpot() {
                    DataMigration.runIfNeeded(modelContainer: testContainer, logger: logger)
                    return DependencyContainer(modelContainer: testContainer, appState: appState)
                }
                logger.fault("Failed to create test container; continuing with production ladder", category: .app)
            }
        #endif

        do {
            let container = try ModelContainer(
                for: ModelContainer.currencySpotSchema,
                configurations: ModelConfiguration()
            )
            DataMigration.runIfNeeded(modelContainer: container, logger: logger)
            return DependencyContainer(modelContainer: container, appState: appState)
        } catch {
            logger.fault("Failed to create persistent ModelContainer: \(error)", category: .app)
        }

        do {
            let fallback = try ModelContainer.inMemoryCurrencySpot()
            logger.info("Fallback to in-memory storage successful", category: .app)
            appState.errorHandler.handle(AppError.initializationFailed("Persistent storage failed"))
            return DependencyContainer(modelContainer: fallback, appState: appState)
        } catch {
            logger.fault("Critical error: Failed to initialize in-memory container: \(error)", category: .app)
        }

        do {
            let minimal = try ModelContainer(for: Schema([]))
            appState.errorHandler.handle(AppError.initializationFailed("App initialization failed. Running in limited mode."))
            return DependencyContainer(modelContainer: minimal, appState: appState)
        } catch {
            logger.fault("Unrecoverable: failed to create an empty in-memory ModelContainer: \(error)", category: .app)
            fatalError("CurrencySpot cannot start: SwiftData is unavailable (\(error))")
        }
    }
}
