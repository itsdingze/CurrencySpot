import Foundation

final class CurrencyCache {
    let data: [HistoricalRateSnapshot]

    var earliestDate: Date? { data.first?.date }
    var latestDate: Date? { data.last?.date }
    var isEmpty: Bool { data.isEmpty }

    init(data: [HistoricalRateSnapshot]) {
        self.data = data
    }
}
