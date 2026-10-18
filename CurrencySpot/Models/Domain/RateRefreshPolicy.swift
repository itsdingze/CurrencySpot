import Foundation

enum RateRefreshPolicy {
    private static let ttl: TimeInterval = 6 * 60 * 60

    static func shouldRefetch(now: Date, lastFetch: Date?) -> Bool {
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) >= ttl
    }
}
