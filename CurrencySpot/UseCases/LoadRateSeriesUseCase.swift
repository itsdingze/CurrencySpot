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
    let latestRateDay: Date?
    let series: [RateSeries]
}

nonisolated protocol HistoricalRatesFetching: Sendable {
    func fetchHistoricalRatesForRange(baseCurrency: String, startDate: Date, endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse
}

nonisolated struct LoadRateSeriesUseCase: Sendable {
    let fetcher: HistoricalRatesFetching
    let cache: RateSeriesCache

    func callAsFunction(_ request: RateSeriesRequest, now: Date) async -> RateSeriesSnapshot? {
        guard !request.quotes.isEmpty else {
            return RateSeriesSnapshot(
                latestRateDay: now,
                series: request.currencies.map { RateSeries(currency: $0, rates: [1, 1]) }
            )
        }
        do {
            let snapshot = try await fetch(request, now: now)
            cache.save(snapshot, for: request)
            return snapshot
        } catch {
            return cache.load(for: request)
        }
    }

    private func fetch(_ request: RateSeriesRequest, now: Date) async throws -> RateSeriesSnapshot {
        let response = try await fetcher.fetchHistoricalRatesForRange(
            baseCurrency: request.base.rawValue,
            startDate: request.period.startDate(from: now),
            endDate: now,
            quotes: request.quotes.map(\.rawValue)
        )
        guard let latestRateDay = CETCalendar.date(fromDayString: response.endDate), !response.rates.isEmpty else {
            throw AppError.dataValidationError("Rate series response contained no days")
        }
        return RateSeriesSnapshot(
            latestRateDay: latestRateDay,
            series: RateSeries.series(for: request.currencies, in: response)
        )
    }
}
