import Foundation
import SwiftData

enum DataMigration {
    private static let migratedToV2Key = "DidMigrateToFrankfurterV2"
    private static let migratedToBlobHistoryKey = "DidMigrateToBlobHistoricalSchema"

    static func runIfNeeded(
        modelContainer: ModelContainer,
        defaults: UserDefaults = .standard,
        logger: LoggerService = OSLogLoggerService()
    ) {
        migrateToV2IfNeeded(modelContainer: modelContainer, defaults: defaults, logger: logger)
        migrateToBlobHistoryIfNeeded(modelContainer: modelContainer, defaults: defaults, logger: logger)
    }

    private static func migrateToV2IfNeeded(modelContainer: ModelContainer, defaults: UserDefaults, logger: LoggerService) {
        guard !defaults.bool(forKey: migratedToV2Key) else { return }

        let context = modelContainer.mainContext
        do {
            try context.delete(model: ExchangeRateData.self)
            try context.delete(model: HistoricalRateData.self)
            try context.delete(model: TrendData.self)
            try context.save()
        } catch {
            logger.error("Frankfurter v2 migration purge failed: \(error.localizedDescription)", category: .data)
            return
        }

        defaults.removeObject(forKey: UserDefaultsKeys.lastFetchDate)
        UserDefaultsHistoricalSyncStore(defaults: defaults).reset()
        defaults.set(true, forKey: migratedToV2Key)
    }

    private static func migrateToBlobHistoryIfNeeded(modelContainer: ModelContainer, defaults: UserDefaults, logger: LoggerService) {
        guard !defaults.bool(forKey: migratedToBlobHistoryKey) else { return }

        let context = modelContainer.mainContext
        do {
            try context.delete(model: HistoricalRateData.self)
            try context.delete(model: TrendData.self)
            try context.save()
        } catch {
            logger.error("Blob-history migration purge failed: \(error.localizedDescription)", category: .data)
            return
        }

        UserDefaultsHistoricalSyncStore(defaults: defaults).reset()
        defaults.set(true, forKey: migratedToBlobHistoryKey)
    }
}
