import WidgetKit

struct RateSeriesEntry: TimelineEntry {
    let date: Date
    let request: RateSeriesRequest
    let snapshot: RateSeriesSnapshot?
    let isFresh: Bool

    var rows: [RateSeries] {
        request.currencies.map { currency in
            snapshot?.series.first { $0.currency == currency } ?? RateSeries(currency: currency, rates: [])
        }
    }

    var outdatedFetchDate: Date? {
        isFresh ? nil : snapshot?.fetchedAt
    }
}
