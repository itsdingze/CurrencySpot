import Foundation
import OSLog
import SwiftData

enum DataMigration {
    private static let migratedToV2Key = "DidMigrateToFrankfurterV2"
    private static let clearedHistoryForArchiveKey = "DidClearHistoryForArchiveBackfill"
    private static let removedLegacyStoreKey = "DidRemoveLegacyStore"

    private static let logger = Logger(category: .data)

    static func moveLegacyStoreIfNeeded(from legacyStoreURL: URL, to storeURL: URL) {
        guard !PersistentStoreFiles.isSameStore(legacyStoreURL, storeURL),
              PersistentStoreFiles.exists(at: legacyStoreURL),
              !PersistentStoreFiles.exists(at: storeURL)
        else { return }
        do {
            try PersistentStoreFiles.move(from: legacyStoreURL, to: storeURL)
        } catch {
            logger.error("Moving the earlier version's store failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func runIfNeeded(modelContainer: ModelContainer, defaults: UserDefaults, legacyStoreURL: URL) {
        migrateToV2IfNeeded(modelContainer: modelContainer, defaults: defaults)
        clearHistoryForArchiveIfNeeded(modelContainer: modelContainer, defaults: defaults)
        removeLegacyStoreIfNeeded(at: legacyStoreURL, unlessOpenIn: modelContainer, defaults: defaults)
        PartialHistoricalRowRepair.runIfNeeded(modelContainer: modelContainer, defaults: defaults)
    }

    private static func clearHistoryForArchiveIfNeeded(modelContainer: ModelContainer, defaults: UserDefaults) {
        guard !defaults.bool(forKey: clearedHistoryForArchiveKey) else { return }

        let context = modelContainer.mainContext
        do {
            try context.delete(model: HistoricalRateData.self)
            try context.delete(model: TrendData.self)
            try context.save()
        } catch {
            logger.error("Clearing history for the archive download failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        UserDefaultsHistoricalSyncStore(defaults: defaults).reset()
        defaults.set(true, forKey: clearedHistoryForArchiveKey)
    }

    private static func removeLegacyStoreIfNeeded(at legacyStoreURL: URL, unlessOpenIn modelContainer: ModelContainer, defaults: UserDefaults) {
        guard !defaults.bool(forKey: removedLegacyStoreKey),
              !modelContainer.configurations.contains(where: { PersistentStoreFiles.isSameStore($0.url, legacyStoreURL) })
        else { return }
        do {
            try PersistentStoreFiles.remove(at: legacyStoreURL)
            defaults.set(true, forKey: removedLegacyStoreKey)
        } catch {
            logger.error("Removing the earlier version's store failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func migrateToV2IfNeeded(modelContainer: ModelContainer, defaults: UserDefaults) {
        guard !defaults.bool(forKey: migratedToV2Key) else { return }

        let context = modelContainer.mainContext
        do {
            try context.delete(model: ExchangeRateData.self)
            try context.delete(model: HistoricalRateData.self)
            try context.delete(model: TrendData.self)
            try context.save()
        } catch {
            logger.error("Frankfurter v2 migration purge failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        defaults.removeObject(forKey: UserDefaultsKeys.lastFetchDate)
        UserDefaultsHistoricalSyncStore(defaults: defaults).reset()
        defaults.set(true, forKey: migratedToV2Key)
    }
}
