//
//  DataMigration.swift
//  CurrencySpot
//

import Foundation
import SwiftData

/// One-time data migrations run at app startup, before any view or fetch.
enum DataMigration {
    private static let migratedToV2Key = "DidMigrateToFrankfurterV2"
    private static let migratedToBlobHistoryKey = "DidMigrateToBlobHistoricalSchema"

    static func runIfNeeded(modelContainer: ModelContainer, defaults: UserDefaults = .standard) {
        migrateToV2IfNeeded(modelContainer: modelContainer, defaults: defaults)
        migrateToBlobHistoryIfNeeded(modelContainer: modelContainer, defaults: defaults)
    }

    /// Purges v1 (ECB) cached rate data once, so the store repopulates from v2's blended,
    /// multi-source rates. v1 values differ slightly (different methodology) and would otherwise
    /// leave a seam in the historical series. The SwiftData schema is unchanged — this is data-only.
    ///
    /// The completion flag is only set after a successful save, so a failed purge retries on the
    /// next launch rather than silently leaving stale v1 data behind.
    private static func migrateToV2IfNeeded(modelContainer: ModelContainer, defaults: UserDefaults) {
        guard !defaults.bool(forKey: migratedToV2Key) else { return }

        let context = modelContainer.mainContext
        do {
            try context.delete(model: ExchangeRateData.self)
            try context.delete(model: HistoricalRateData.self)
            try context.delete(model: TrendData.self)
            try context.save()
        } catch {
            OSLogLoggerService().error("Frankfurter v2 migration purge failed: \(error.localizedDescription)", category: .data)
            return
        }

        // Force the next launch to refetch from v2 instead of trusting the cleared cache.
        defaults.removeObject(forKey: UserDefaultsKeys.lastFetchDate)
        // Drop the historical coverage window too, or it would claim coverage over the now-empty
        // store and leave charts permanently blank.
        UserDefaultsHistoricalSyncStore(defaults: defaults).reset()
        defaults.set(true, forKey: migratedToV2Key)
    }

    /// Purges historical rows once after the per-currency child-row schema was replaced
    /// by per-date blobs. Lightweight migration leaves pre-blob rows with empty
    /// `ratesData` (and drops the orphaned point rows), so those rows are unusable; the
    /// launch warm-up refetches the window (~262 KB) and trends recompute from it.
    private static func migrateToBlobHistoryIfNeeded(modelContainer: ModelContainer, defaults: UserDefaults) {
        guard !defaults.bool(forKey: migratedToBlobHistoryKey) else { return }

        let context = modelContainer.mainContext
        do {
            try context.delete(model: HistoricalRateData.self)
            try context.delete(model: TrendData.self)
            try context.save()
        } catch {
            OSLogLoggerService().error("Blob-history migration purge failed: \(error.localizedDescription)", category: .data)
            return
        }

        // The coverage watermark must not outlive the rows it described.
        UserDefaultsHistoricalSyncStore(defaults: defaults).reset()
        defaults.set(true, forKey: migratedToBlobHistoryKey)
    }
}
