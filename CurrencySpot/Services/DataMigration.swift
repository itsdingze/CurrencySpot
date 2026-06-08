//
//  DataMigration.swift
//  CurrencySpot
//

import Foundation
import SwiftData

/// One-time data migrations run at app startup, before any view or fetch.
enum DataMigration {
    private static let migratedToV2Key = "DidMigrateToFrankfurterV2"

    /// Purges v1 (ECB) cached rate data once, so the store repopulates from v2's blended,
    /// multi-source rates. v1 values differ slightly (different methodology) and would otherwise
    /// leave a seam in the historical series. The SwiftData schema is unchanged — this is data-only.
    ///
    /// The completion flag is only set after a successful save, so a failed purge retries on the
    /// next launch rather than silently leaving stale v1 data behind.
    @MainActor
    static func runIfNeeded(modelContainer: ModelContainer, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: migratedToV2Key) else { return }

        let context = modelContainer.mainContext
        do {
            try context.delete(model: ExchangeRateData.self)
            try context.delete(model: HistoricalRateData.self)
            try context.delete(model: TrendData.self)
            try context.save()
        } catch {
            AppLogger.error("Frankfurter v2 migration purge failed: \(error.localizedDescription)", category: .data)
            return
        }

        // Force the next launch to refetch from v2 instead of trusting the cleared cache.
        defaults.removeObject(forKey: UserDefaultsKeys.lastFetchDate)
        // Drop the historical coverage window too, or it would claim coverage over the now-empty
        // store and leave charts permanently blank.
        UserDefaultsHistoricalSyncStore(defaults: defaults).reset()
        defaults.set(true, forKey: migratedToV2Key)
    }
}
