import Foundation
import OSLog
import SwiftData

enum ModelContainerFactory {
    private static let logger = Logger(category: .app)

    static func persistentContainer(storeURL: URL, defaults: UserDefaults, errorHandler: ErrorHandler) -> ModelContainer {
        do {
            let container = try PersistentStoreLoader(storeURL: storeURL).load {
                logger.fault("Persistent store could not be opened; rebuilt it empty")
                UserDefaultsHistoricalSyncStore(defaults: defaults).reset()
                UserDefaultsRatesFetchDateStore(defaults: defaults).lastFetchDate = nil
            }
            DataMigration.runIfNeeded(modelContainer: container, defaults: defaults)
            return container
        } catch {
            logger.fault("Failed to create persistent ModelContainer: \(error.localizedDescription, privacy: .public)")
        }

        let fallback = inMemoryContainer()
        errorHandler.handle(AppError.initializationFailed("Persistent storage failed"))
        return fallback
    }

    static func inMemoryContainer() -> ModelContainer {
        do {
            return try ModelContainer.inMemoryCurrencySpot()
        } catch {
            logger.fault("Unrecoverable: failed to create an in-memory ModelContainer: \(error.localizedDescription, privacy: .public)")
            fatalError("CurrencySpot cannot start: SwiftData is unavailable (\(error))")
        }
    }
}
