import Foundation

nonisolated struct HistoricalLoadResult: Sendable {
    let snapshots: [HistoricalRateSnapshot]
    let newDataFetched: Bool
    let fetchedRanges: [DateRange]

    static func cached(_ snapshots: [HistoricalRateSnapshot]) -> HistoricalLoadResult {
        HistoricalLoadResult(snapshots: snapshots, newDataFetched: false, fetchedRanges: [])
    }
}
