import Foundation
import OSLog
import SwiftData

enum DataMigration {
    private static let migratedToV2Key = "DidMigrateToFrankfurterV2"

    private static let logger = Logger(category: .data)

    static func runIfNeeded(modelContainer: ModelContainer, defaults: UserDefaults) {
        migrateToV2IfNeeded(modelContainer: modelContainer, defaults: defaults)
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
