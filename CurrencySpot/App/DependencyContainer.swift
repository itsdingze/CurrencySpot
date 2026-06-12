//
//  DependencyContainer.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation
import SwiftData

// MARK: - ModelContainer Factory

extension ModelContainer {
    /// The app's full schema in an in-memory store (tests, previews, fallback boot).
    static func inMemoryCurrencySpot() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            for: ExchangeRateData.self,
            HistoricalRateData.self,
            TrendData.self,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: ExchangeRateData.self,
            HistoricalRateData.self,
            TrendData.self,
            configurations: configuration
        )
    }
}

// MARK: - DependencyContainer

/// Centralized dependency injection container.
/// Every service/repository/provider parameter has a working default; tests and
/// previews override only what they need.
@MainActor
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

    /// Orchestrates the services above and implements every repository protocol.
    let dataCoordinator: DataCoordinator

    // MARK: - Use Cases

    let historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase
    let dataOrchestrationUseCase: DataOrchestrationUseCase
    let chartDataPreparationUseCase: ChartDataPreparationUseCase
    let trendDataUseCase: TrendDataUseCase
    let clearAllDataUseCase: ClearAllDataUseCase

    // MARK: - Shared State and ViewModels

    let ratesStore: ExchangeRatesStore
    let calculatorViewModel: CalculatorViewModel
    let historyViewModel: HistoryViewModel
    let settingsViewModel: SettingsViewModel
    let cameraViewModel: CameraViewModel

    // MARK: - Initialization

    /// Optional-with-nil parameters exist where a default would need another
    /// parameter (the persistence actor needs the model container).
    init(
        modelContainer: ModelContainer,
        appState: AppState = .shared,
        networkService: NetworkService? = nil,
        persistenceService: PersistenceService? = nil,
        cacheService: CacheService = InMemoryCacheService(),
        syncStore: HistoricalSyncStore = UserDefaultsHistoricalSyncStore(),
        dateProvider: DateProvider = SystemDateProvider(),
        clockService: ClockService = ContinuousClockService(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.modelContainer = modelContainer
        self.appState = appState
        self.networkService = networkService ?? FrankfurterNetworkService(dateProvider: dateProvider)
        self.persistenceService = persistenceService ?? SwiftDataPersistenceService(modelContainer: modelContainer)
        self.cacheService = cacheService
        self.syncStore = syncStore
        self.dateProvider = dateProvider
        self.clockService = clockService
        self.logger = logger

        dataCoordinator = DataCoordinator(
            networkService: self.networkService,
            persistenceService: self.persistenceService,
            cacheService: cacheService,
            syncStore: syncStore,
            dateProvider: dateProvider,
            logger: logger
        )

        historicalDataAnalysisUseCase = HistoricalDataAnalysisUseCase(
            syncStore: syncStore,
            dateProvider: dateProvider,
            logger: logger
        )

        dataOrchestrationUseCase = DataOrchestrationUseCase(
            repository: dataCoordinator,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dateProvider: dateProvider,
            logger: logger
        )

        chartDataPreparationUseCase = ChartDataPreparationUseCase(
            cacheService: cacheService,
            logger: logger
        )

        trendDataUseCase = TrendDataUseCase(
            trendRepository: dataCoordinator,
            historicalRateRepository: dataCoordinator,
            dateProvider: dateProvider,
            logger: logger
        )

        clearAllDataUseCase = ClearAllDataUseCase(repository: dataCoordinator)

        ratesStore = ExchangeRatesStore()

        calculatorViewModel = CalculatorViewModel(
            repository: dataCoordinator,
            ratesStore: ratesStore,
            appState: appState,
            logger: logger
        )

        historyViewModel = HistoryViewModel(
            ratesStore: ratesStore,
            historicalDataAnalysisUseCase: historicalDataAnalysisUseCase,
            dataOrchestrationUseCase: dataOrchestrationUseCase,
            chartDataPreparationUseCase: chartDataPreparationUseCase,
            trendDataUseCase: trendDataUseCase,
            appState: appState,
            clock: clockService,
            logger: logger
        )

        settingsViewModel = SettingsViewModel(
            clearAllDataUseCase: clearAllDataUseCase,
            appState: appState,
            clock: clockService,
            logger: logger
        )

        cameraViewModel = CameraViewModel(
            ratesStore: ratesStore,
            appState: appState
        )

        // The cross-cutting clear resets each feature's published state after the
        // repository wipe, without Settings holding sibling-ViewModel references.
        clearAllDataUseCase.registerResetHandler { [calculatorViewModel] in
            calculatorViewModel.clearAllData()
        }
        clearAllDataUseCase.registerResetHandler { [historyViewModel] in
            historyViewModel.clearAllData()
        }
    }

    // MARK: - Bootstrap

    /// App-entry factory owning the storage fallback ladder:
    /// persistent store → in-memory (with a user-visible warning) → empty-schema
    /// in-memory (unrecoverable storage failure, still no fake data in release).
    static func bootstrap(appState: AppState = .shared) -> DependencyContainer {
        let logger = OSLogLoggerService()

        #if DEBUG
            if CommandLine.arguments.contains("enable-testing") {
                if let testContainer = try? ModelContainer.inMemoryCurrencySpot() {
                    DataMigration.runIfNeeded(modelContainer: testContainer)
                    return DependencyContainer(modelContainer: testContainer, appState: appState)
                }
                logger.fault("Failed to create test container; continuing with production ladder", category: .app)
            }
        #endif

        do {
            let container = try ModelContainer(
                for: ExchangeRateData.self, HistoricalRateData.self, TrendData.self
            )
            // One-time data migrations, before any view's .task can fetch. This runs
            // synchronously on the main actor, so it completes before the ViewModels'
            // queued fetch tasks get a chance to execute.
            DataMigration.runIfNeeded(modelContainer: container)
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

        // Last resort: an empty-schema in-memory container. The app runs without
        // storage and surfaces the failure; no mock data ships in release.
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
