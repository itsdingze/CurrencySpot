import Foundation

nonisolated struct ChartCacheKey: Hashable, Sendable {
    let base: CurrencyCode
    let target: CurrencyCode
    let range: DateRange
    let snapshotCount: Int
    let firstSnapshot: Date?
    let lastSnapshot: Date?
}
