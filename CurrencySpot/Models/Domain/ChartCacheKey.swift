import Foundation

nonisolated struct ChartCacheKey: Hashable, Sendable {
    let base: CurrencyCode
    let target: CurrencyCode
    let range: DateRange
    let snapshotCount: Int
    let firstSnapshot: Date?
    let lastSnapshot: Date?

    var storageKey: String {
        [
            base.rawValue,
            target.rawValue,
            String(range.start.timeIntervalSince1970),
            String(range.end.timeIntervalSince1970),
            String(snapshotCount),
            String(firstSnapshot?.timeIntervalSince1970 ?? 0),
            String(lastSnapshot?.timeIntervalSince1970 ?? 0),
        ].joined(separator: "-")
    }
}
