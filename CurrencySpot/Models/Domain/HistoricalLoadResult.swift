import Foundation

nonisolated struct HistoricalLoadResult: Sendable {
    let snapshots: [HistoricalRateSnapshot]
    let newDataFetched: Bool
    let fetchedRanges: [DateRange]
    var updateFailed = false

    static func cached(_ snapshots: [HistoricalRateSnapshot], updateFailed: Bool = false) -> HistoricalLoadResult {
        HistoricalLoadResult(snapshots: snapshots, newDataFetched: false, fetchedRanges: [], updateFailed: updateFailed)
    }
}
