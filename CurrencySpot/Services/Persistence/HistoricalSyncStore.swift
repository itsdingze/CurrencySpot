//
//  HistoricalSyncStore.swift
//  CurrencySpot
//

import Foundation

/// Records the contiguous historical date window we have already fetched (and therefore "checked")
/// from the API, so absent-but-already-checked dates are treated as known-empty instead of
/// triggering pointless refetches.
///
/// Why this exists: Frankfurter v2 is multi-source and a given day may carry no data. Without a
/// record of what we've fetched, "data absent" is indistinguishable from "never fetched", so the
/// app would re-hit the network for the same empty days on every chart open. The window stays a
/// single contiguous `[from, through]` because required ranges always anchor at today and extend
/// backward (see `HistoricalDataAnalysisUseCase.calculateDateRange`).
protocol HistoricalSyncStore: AnyObject {
    /// Oldest date we have fetched through (start-of-day, CET). `nil` until the first fetch.
    var from: Date? { get }
    /// Newest date we have fetched through (start-of-day, CET). `nil` until the first fetch.
    var through: Date? { get }
    /// Timestamp of the most recent fetch, used to throttle live-edge rechecks.
    var checkedAt: Date? { get }

    /// Widens the coverage window to include `[from, through]` and stamps the check time.
    func record(from: Date, through: Date, at now: Date)

    /// Clears the window. Called by `DataMigration` so a purge doesn't leave a coverage claim
    /// over an empty store.
    func reset()
}

/// `UserDefaults`-backed coverage record.
final class UserDefaultsHistoricalSyncStore: HistoricalSyncStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var from: Date? { defaults.object(forKey: UserDefaultsKeys.historicalSyncFrom) as? Date }
    var through: Date? { defaults.object(forKey: UserDefaultsKeys.historicalSyncThrough) as? Date }
    var checkedAt: Date? { defaults.object(forKey: UserDefaultsKeys.historicalSyncCheckedAt) as? Date }

    func record(from newFrom: Date, through newThrough: Date, at now: Date) {
        // The window must stay contiguous: uniting across an unfetched middle would
        // claim those dates as checked, permanently hiding them from gap detection.
        // On a disjoint record, keep the window that reaches further forward (the
        // live edge drives freshness) instead of uniting.
        if let from, let through, !Self.overlapsOrAdjacent(from: from, through: through, newFrom: newFrom, newThrough: newThrough) {
            guard newThrough > through else { return } // keep the existing window; drop the record
            defaults.set(newFrom, forKey: UserDefaultsKeys.historicalSyncFrom)
            defaults.set(newThrough, forKey: UserDefaultsKeys.historicalSyncThrough)
            defaults.set(now, forKey: UserDefaultsKeys.historicalSyncCheckedAt)
            return
        }

        defaults.set(min(from ?? newFrom, newFrom), forKey: UserDefaultsKeys.historicalSyncFrom)
        defaults.set(max(through ?? newThrough, newThrough), forKey: UserDefaultsKeys.historicalSyncThrough)
        defaults.set(now, forKey: UserDefaultsKeys.historicalSyncCheckedAt)
    }

    /// True when `[newFrom, newThrough]` touches `[from, through]` (overlap or a gap
    /// of at most one day), so the min/max union introduces no unchecked middle.
    private static func overlapsOrAdjacent(from: Date, through: Date, newFrom: Date, newThrough: Date) -> Bool {
        let calendar = TimeZoneManager.cetCalendar
        guard let throughPlusDay = calendar.date(byAdding: .day, value: 1, to: through),
              let fromMinusDay = calendar.date(byAdding: .day, value: -1, to: from)
        else {
            return true // date math failure: fall back to the historical union behavior
        }
        return newFrom <= throughPlusDay && newThrough >= fromMinusDay
    }

    func reset() {
        defaults.removeObject(forKey: UserDefaultsKeys.historicalSyncFrom)
        defaults.removeObject(forKey: UserDefaultsKeys.historicalSyncThrough)
        defaults.removeObject(forKey: UserDefaultsKeys.historicalSyncCheckedAt)
    }
}
