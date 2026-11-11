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

        let snapshot = try #require(await load(request, now: now).snapshot)

        #expect(snapshot.series.map(\.currency) == ["JPY", "USD", "EUR"])
        #expect(snapshot.series.map(\.rates) == [[160.0, 150.0], [1, 1], [0.80, 0.88]])
        let call = try #require(fetcher.calls.first)
        #expect(call.base == "USD")
        #expect(call.quotes == ["JPY", "EUR"])
        #expect(call.start == TimeRange.oneMonth.startDate(from: now))
        #expect(call.end == now)
    }

    @Test("falls back to the last saved rates when the fetch fails")
    func fallsBackToSavedRates() async throws {
        let saved = try #require(await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: now).snapshot)
        let offline = LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .failure(URLError(.notConnectedToInternet))), cache: cache)

        #expect(await offline(request, now: now) == RateSeriesLoad(snapshot: saved, isFresh: false))
    }

    @Test("saved rates shown offline are dated when they were downloaded, not when they were shown")
    func offlineRatesKeepTheirDownloadDate() async throws {
        _ = await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: now)
        let offline = LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .failure(URLError(.notConnectedToInternet))), cache: cache)

        let load = await offline(request, now: now.addingTimeInterval(30 * 60 * 60))

        #expect(!load.isFresh)
        #expect(load.snapshot?.fetchedAt == now)
    }

    @Test("rates saved by the earlier version still load offline, dated when they were saved")
    func earlierVersionsSavedRatesStillLoad() async throws {
        _ = await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: now)
        let folder = directory.storeURL.deletingLastPathComponent()
        let savedFile = try #require(FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first)
        try Data(#"{"series":[{"currency":"JPY","rates":[160,150]},{"currency":"USD","rates":[1,1]},{"currency":"EUR","rates":[0.8,0.88]}]}"#.utf8)
            .write(to: savedFile)
        let savedAt = Date(timeIntervalSince1970: 1_790_000_000)
        try FileManager.default.setAttributes([.modificationDate: savedAt], ofItemAtPath: savedFile.path(percentEncoded: false))
        let offline = LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .failure(URLError(.notConnectedToInternet))), cache: cache)

        let snapshot = try #require(await offline(request, now: now).snapshot)

        #expect(snapshot.series.map(\.rates) == [[160, 150], [1, 1], [0.8, 0.88]])
        #expect(snapshot.fetchedAt == savedAt)
    }

    @Test("after a successful download the widget refreshes when the app would treat the rates as stale, weekends included")
    func freshDownloadRefreshesWithTheApp() async throws {
        let saturday = try #require(createCETDate(year: 2026, month: 10, day: 31))
        let load = await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: saturday)

        let next = load.nextRefresh(after: saturday)

        #expect(RateRefreshPolicy.shouldRefetch(now: next, lastFetch: saturday))
        #expect(!RateRefreshPolicy.shouldRefetch(now: next.addingTimeInterval(-60), lastFetch: saturday))
    }

    @Test("after a failed download the widget keeps retrying within the hour, even long after a missed publish")
    func failedDownloadRetriesSoon() async throws {
        _ = await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: now)
        let offline = LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .failure(URLError(.notConnectedToInternet))), cache: cache)
        let nextEvening = now.addingTimeInterval(45 * 60 * 60)

        let load = await offline(request, now: nextEvening)

        #expect(load.snapshot != nil)
        #expect(load.nextRefresh(after: nextEvening) <= nextEvening.addingTimeInterval(60 * 60))
    }

    @Test("an empty response keeps the last saved rates instead of replacing them")
    func emptyResponseKeepsSavedRates() async throws {
        let saved = try #require(await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: now).snapshot)
        let empty = HistoricalRatesResponse(base: "USD", startDate: "", endDate: "", rates: [:])
        let emptyLoad = LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(empty)), cache: cache)

        #expect(await emptyLoad(request, now: now).snapshot == saved)
    }

    @Test("a request with only the base currency answers one without going online")
    func baseOnlyRequestSkipsTheNetwork() async throws {
        let fetcher = StubHistoricalRatesFetcher(result: .failure(URLError(.notConnectedToInternet)))
        let load = LoadRateSeriesUseCase(fetcher: fetcher, cache: cache)

        let snapshot = try #require(await load(RateSeriesRequest(base: "USD", currencies: ["USD"], period: .oneWeek), now: now).snapshot)

        #expect(snapshot.series.map(\.currency) == ["USD"])
        #expect(snapshot.series.first?.latestRate == 1)
        #expect(fetcher.calls.isEmpty)
    }

    @Test("saved rates belong to their own settings")
    func savedRatesMatchTheirSettings() async throws {
        _ = await LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .success(response)), cache: cache)(request, now: now)
        let offline = LoadRateSeriesUseCase(fetcher: StubHistoricalRatesFetcher(result: .failure(URLError(.notConnectedToInternet))), cache: cache)
        let otherPeriod = RateSeriesRequest(base: "USD", currencies: ["JPY", "USD", "EUR"], period: .oneYear)

        #expect(await offline(otherPeriod, now: now).snapshot == nil)
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
