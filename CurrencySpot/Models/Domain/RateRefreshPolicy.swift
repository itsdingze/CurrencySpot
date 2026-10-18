import Foundation

enum RateRefreshPolicy {
    static let defaultTTL: TimeInterval = 6 * 60 * 60

    static func shouldRefetch(now: Date, lastFetch: Date?, ttl: TimeInterval = defaultTTL) -> Bool {
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) >= ttl
    }
}
