//
//  RateRefreshPolicy.swift
//  CurrencySpot
//

import Foundation

/// Decides when cached exchange rates are stale enough to refetch.
///
/// Pure and time-injected so the decision is deterministically testable. Replaces the old
/// ECB-specific publish schedule: Frankfurter v2 blends 84 sources that update on different
/// cadences across time zones, so a plain staleness window is both simpler and more correct.
enum RateRefreshPolicy {
    /// How long fetched rates stay fresh before a refetch is warranted.
    static let defaultTTL: TimeInterval = 6 * 60 * 60

    static func shouldRefetch(now: Date, lastFetch: Date?, ttl: TimeInterval = defaultTTL) -> Bool {
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) >= ttl
    }
}
