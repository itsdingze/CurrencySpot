@testable import CurrencySpot
import Foundation
import Testing

@Suite("LoadRateSeriesUseCase")
struct LoadRateSeriesUseCaseTests {
    private let directory: TemporaryStoreDirectory
    private let cache: RateSeriesCache
    private let now: Date
    private let request = RateSeriesRequest(base: "USD", currencies: ["JPY", "USD", "EUR"], period: .oneMonth)
    private let response = HistoricalRatesResponse(
        base: "USD",
        startDate: "2026-09-28",
        endDate: "2026-10-27",
        rates: [
            "2026-09-28": ["EUR": 0.80, "JPY": 160.0],
            "2026-10-27": ["EUR": 0.88, "JPY": 150.0],
        ]
    )

    init() throws {
        directory = try TemporaryStoreDirectory()
        cache = RateSeriesCache(directory: directory.storeURL.deletingLastPathComponent())
        now = try #require(createCETDate(year: 2026, month: 10, day: 27))
    }

    @Test("fetches the period for the base and the other currencies, keeping the requested order")
    func fetchesThePeriod() async throws {
        let fetcher = StubHistoricalRatesFetcher(result: .success(response))
        let load = LoadRateSeriesUseCase(fetcher: fetcher, cache: cache)

        let snapshot = try #require(await load(request, now: now))

        #expect(snapshot.series.map(\.currency) == ["JPY", "USD", "EUR"])
        #expect(snapshot.series.map(\.rates) == [[160.0, 150.0], [1, 1], [0.80, 0.88]])
        #expect(snapshot.latestRateDay == createCETDate(year: 2026, month: 10, day: 27))
        let call = try #require(fetcher.calls.first)
        #expect(call.base == "USD")
        #expect(call.quotes == ["JPY", "EUR"])
        #expect(call.start == TimeRange.oneMonth.startDate(from: now))
        #expect(call.end == now)
    }

    @Test("falls back to the last saved rates when the fetch fails")
    func fallsBackToSavedRates() async throws {
        let saved = try #require(await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: now))
        let offline = LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .failure(URLError(.notConnectedToInternet))), cache: cache)

        #expect(await offline(request, now: now) == saved)
    }

    @Test("an empty response keeps the last saved rates instead of replacing them")
    func emptyResponseKeepsSavedRates() async throws {
        let saved = try #require(await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: now))
        let empty = HistoricalRatesResponse(base: "USD", startDate: "", endDate: "", rates: [:])
        let emptyLoad = LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(empty)), cache: cache)

        #expect(await emptyLoad(request, now: now) == saved)
    }

    @Test("a request with only the base currency answers one without going online")
    func baseOnlyRequestSkipsTheNetwork() async throws {
        let fetcher = StubHistoricalRatesFetcher(result: .failure(URLError(.notConnectedToInternet)))
        let load = LoadRateSeriesUseCase(fetcher: fetcher, cache: cache)

        let snapshot = try #require(await load(RateSeriesRequest(base: "USD", currencies: ["USD"], period: .oneWeek), now: now))

        #expect(snapshot.series.map(\.currency) == ["USD"])
        #expect(snapshot.series.first?.latestRate == 1)
        #expect(fetcher.calls.isEmpty)
    }

    @Test("saved rates belong to their own settings")
    func savedRatesMatchTheirSettings() async throws {
        _ = await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: now)
        let offline = LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .failure(URLError(.notConnectedToInternet))), cache: cache)
        let otherPeriod = RateSeriesRequest(base: "USD", currencies: ["JPY", "USD", "EUR"], period: .oneYear)

        #expect(await offline(otherPeriod, now: now) == nil)
    }
}

nonisolated private final class StubHistoricalRatesFetcher: HistoricalRatesFetching, @unchecked Sendable {
    struct Call {
        let base: String
        let start: Date
        let end: Date
        let quotes: [String]
    }

    private let result: Result<HistoricalRatesResponse, Error>
    private(set) var calls: [Call] = []

    init(result: Result<HistoricalRatesResponse, Error>) {
        self.result = result
    }

    func fetchHistoricalRatesForRange(baseCurrency: String, startDate: Date, endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse {
        calls.append(Call(base: baseCurrency, start: startDate, end: endDate, quotes: quotes))
        return try result.get()
    }
}
