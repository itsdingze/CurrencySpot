import Foundation

nonisolated struct RateSeriesRequest: Hashable, Sendable {
    let base: CurrencyCode
    let currencies: [CurrencyCode]
    let period: TimeRange

    var quotes: [CurrencyCode] {
        currencies.filter { $0 != base }
    }

    static func list(base: CurrencyCode, currencies: [CurrencyCode], period: TimeRange, limit: Int) -> RateSeriesRequest {
        var seen: Set = [base]
        let unique = currencies.filter { seen.insert($0).inserted }
        return RateSeriesRequest(base: base, currencies: Array(unique.prefix(limit)), period: period)
    }
}

nonisolated struct RateSeriesSnapshot: Equatable, Sendable, Codable {
    let series: [RateSeries]
}

nonisolated struct RateSeriesLoad: Equatable, Sendable {
    let snapshot: RateSeriesSnapshot?
    let isFresh: Bool

    private static let retryInterval: TimeInterval = 60 * 60

    func nextRefresh(after now: Date) -> Date {
        isFresh ? RateRefreshPolicy.nextRefetch(after: now) : now.addingTimeInterval(Self.retryInterval)
    }
}

nonisolated protocol HistoricalRatesFetching: Sendable {
    func fetchHistoricalRatesForRange(baseCurrency: String, startDate: Date, endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse
}

nonisolated struct LoadRateSeriesUseCase: Sendable {
    let fetcher: HistoricalRatesFetching
    let cache: RateSeriesCache

    func callAsFunction(_ request: RateSeriesRequest, now: Date) async -> RateSeriesLoad {
        guard !request.quotes.isEmpty else {
            let snapshot = RateSeriesSnapshot(series: request.currencies.map { RateSeries(currency: $0, rates: [1, 1]) })
            return RateSeriesLoad(snapshot: snapshot, isFresh: true)
        }
        do {
            let snapshot = try await fetch(request, now: now)
            cache.save(snapshot, for: request)
            return RateSeriesLoad(snapshot: snapshot, isFresh: true)
        } catch {
            return RateSeriesLoad(snapshot: cache.load(for: request), isFresh: false)
        }
    }

    private func fetch(_ request: RateSeriesRequest, now: Date) async throws -> RateSeriesSnapshot {
        let response = try await fetcher.fetchHistoricalRatesForRange(
            baseCurrency: request.base.rawValue,
            startDate: request.period.startDate(from: now),
            endDate: now,
            quotes: request.quotes.map(\.rawValue)
        )
        guard !response.rates.isEmpty else {
            throw AppError.dataValidationError("Rate series response contained no days")
        }
        return RateSeriesSnapshot(series: RateSeries.series(for: request.currencies, in: response))
    }
}
