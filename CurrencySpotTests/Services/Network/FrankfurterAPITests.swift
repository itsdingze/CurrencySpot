@testable import CurrencySpot
import Foundation
import Synchronization
import Testing

// MARK: - URLProtocol Stub

private nonisolated final class StubURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let data: Data
    }

    private static let stubs = Mutex<[String: Stub]>([:])
    private static let cachePolicies = Mutex<[String: URLRequest.CachePolicy]>([:])

    static func register(_ stub: Stub, for url: String) {
        stubs.withLock { $0[url] = stub }
    }

    static func cachePolicy(requestedFor url: String) -> URLRequest.CachePolicy? {
        cachePolicies.withLock { $0[url] }
    }

    private static func stub(for url: String) -> Stub? {
        stubs.withLock { $0[url] }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url {
            Self.cachePolicies.withLock { $0[url.absoluteString] = request.cachePolicy }
        }
        guard let url = request.url,
              let stub = Self.stub(for: url.absoluteString),
              let response = HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Tests

@Suite("FrankfurterAPI Tests")
struct FrankfurterAPITests {
    private let api = FrankfurterAPI(
        session: StubURLProtocol.makeSession(),
        retryPolicy: RetryPolicy(jitter: { _ in 1.0 }),
        clock: ImmediateClock(),
        now: { .now }
    )

    private static func v2JSON(_ entries: [(date: String, quote: String, rate: Double)], base: String = "USD") -> Data {
        let rows = entries.map {
            #"{"date": "\#($0.date)", "base": "\#(base)", "quote": "\#($0.quote)", "rate": \#($0.rate)}"#
        }
        return Data("[\(rows.joined(separator: ","))]".utf8)
    }

    @Test("clearCachedResponses empties the session's response cache")
    func clearCachedResponsesEmptiesTheCache() throws {
        let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = cache
        let api = FrankfurterAPI(
            session: URLSession(configuration: configuration),
            retryPolicy: RetryPolicy(jitter: { _ in 1.0 }),
            clock: ImmediateClock(),
            now: { .now }
        )
        let url = try #require(URL(string: "https://api.frankfurter.dev/v2/rates?base=USD"))
        let request = URLRequest(url: url)
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        cache.storeCachedResponse(CachedURLResponse(response: response, data: Data("[]".utf8)), for: request)
        try #require(cache.cachedResponse(for: request) != nil)

        api.clearCachedResponses()

        #expect(cache.cachedResponse(for: request) == nil)
    }

    @Test("fetchExchangeRates builds the latest endpoint URL and decodes through the v2 mapper")
    func latestEndpointHappyPath() async throws {
        StubURLProtocol.register(
            .init(statusCode: 200, data: Self.v2JSON([
                (date: "2025-03-14", quote: "EUR", rate: 0.91),
                (date: "2025-03-13", quote: "GBP", rate: 0.78),
            ], base: "CHF")),
            for: "https://api.frankfurter.dev/v2/rates?base=CHF"
        )

        let response = try await api.fetchExchangeRates(baseCurrency: "CHF")

        #expect(response.base == "CHF")
        #expect(response.date == "2025-03-14")
        #expect(response.rates == ["EUR": 0.91, "GBP": 0.78])
    }

    @Test("latest rates are checked with the server instead of answered from the local cache")
    func latestRatesRevalidate() async throws {
        let url = "https://api.frankfurter.dev/v2/rates?base=HUF"
        StubURLProtocol.register(
            .init(statusCode: 200, data: Self.v2JSON([(date: "2025-03-14", quote: "EUR", rate: 0.0025)], base: "HUF")),
            for: url
        )

        _ = try await api.fetchExchangeRates(baseCurrency: "HUF")

        #expect(StubURLProtocol.cachePolicy(requestedFor: url) == .reloadRevalidatingCacheData)
    }

    @Test("a range ending today is checked with the server, a range that ended earlier may come from the local cache")
    func onlyRangesEndingTodayRevalidate() async throws {
        let today = try #require(createCETDate(year: 2025, month: 5, day: 20)).addingTimeInterval(15 * 60 * 60)
        let api = FrankfurterAPI(
            session: StubURLProtocol.makeSession(),
            retryPolicy: RetryPolicy(jitter: { _ in 1.0 }),
            clock: ImmediateClock(),
            now: { today }
        )
        let endingToday = "https://api.frankfurter.dev/v2/rates?base=USD&from=2025-05-19&to=2025-05-20"
        let endedYesterday = "https://api.frankfurter.dev/v2/rates?base=USD&from=2025-05-18&to=2025-05-19"
        for url in [endingToday, endedYesterday] {
            StubURLProtocol.register(.init(statusCode: 200, data: Self.v2JSON([(date: "2025-05-19", quote: "EUR", rate: 0.9)])), for: url)
        }

        _ = try await api.fetchHistoricalRatesForRange(
            startDate: try #require(createCETDate(year: 2025, month: 5, day: 19)),
            endDate: today
        )
        _ = try await api.fetchHistoricalRatesForRange(
            startDate: try #require(createCETDate(year: 2025, month: 5, day: 18)),
            endDate: try #require(createCETDate(year: 2025, month: 5, day: 19)).addingTimeInterval(23 * 60 * 60)
        )

        #expect(StubURLProtocol.cachePolicy(requestedFor: endingToday) == .reloadRevalidatingCacheData)
        #expect(StubURLProtocol.cachePolicy(requestedFor: endedYesterday) == .useProtocolCachePolicy)
    }

    @Test("fetchHistoricalRatesForRange builds the range endpoint URL and decodes the series")
    func historicalRangeEndpointHappyPath() async throws {
        let startDate = try #require(createCETDate(year: 2025, month: 3, day: 10))
        let endDate = try #require(createCETDate(year: 2025, month: 3, day: 12))
        StubURLProtocol.register(
            .init(statusCode: 200, data: Self.v2JSON([
                (date: "2025-03-10", quote: "EUR", rate: 0.90),
                (date: "2025-03-11", quote: "EUR", rate: 0.91),
                (date: "2025-03-12", quote: "EUR", rate: 0.92),
            ])),
            for: "https://api.frankfurter.dev/v2/rates?base=USD&from=2025-03-10&to=2025-03-12"
        )

        let response = try await api.fetchHistoricalRatesForRange(startDate: startDate, endDate: endDate)

        #expect(response.base == "USD")
        #expect(response.startDate == "2025-03-10")
        #expect(response.endDate == "2025-03-12")
        #expect(response.rates["2025-03-11"] == ["EUR": 0.91])
        #expect(response.rates.count == 3)
    }

    @Test("a quoted range request narrows the endpoint to the requested currencies")
    func quotedRangeEndpoint() async throws {
        let startDate = try #require(createCETDate(year: 2025, month: 4, day: 1))
        let endDate = try #require(createCETDate(year: 2025, month: 4, day: 2))
        StubURLProtocol.register(
            .init(statusCode: 200, data: Self.v2JSON([
                (date: "2025-04-01", quote: "EUR", rate: 0.90),
                (date: "2025-04-01", quote: "JPY", rate: 150.0),
            ])),
            for: "https://api.frankfurter.dev/v2/rates?base=USD&from=2025-04-01&to=2025-04-02&quotes=EUR,JPY"
        )

        let response = try await api.fetchHistoricalRatesForRange(startDate: startDate, endDate: endDate, quotes: ["EUR", "JPY"])

        #expect(response.rates["2025-04-01"] == ["EUR": 0.90, "JPY": 150.0])
    }

    @Test("a non-2xx response maps to AppError.httpError with the status code")
    func httpErrorMapsToAppError() async {
        StubURLProtocol.register(
            .init(statusCode: 404, data: Data()),
            for: "https://api.frankfurter.dev/v2/rates?base=NOK"
        )

        await #expect(throws: AppError.httpError(statusCode: 404)) {
            _ = try await api.fetchExchangeRates(baseCurrency: "NOK")
        }
    }

    @Test("malformed JSON maps to AppError.decodingError")
    func malformedJSONMapsToDecodingError() async {
        StubURLProtocol.register(
            .init(statusCode: 200, data: Data(#"{"unexpected": "shape"}"#.utf8)),
            for: "https://api.frankfurter.dev/v2/rates?base=SEK"
        )

        let error = await #expect(throws: AppError.self) {
            _ = try await api.fetchExchangeRates(baseCurrency: "SEK")
        }
        guard case .decodingError = error else {
            Issue.record("Expected .decodingError, got \(String(describing: error))")
            return
        }
    }

    @Test("a persistent server error is retried before surfacing as retryExhausted", .timeLimit(.minutes(1)))
    func serverErrorIsRetriedThroughThePublicAPI() async {
        StubURLProtocol.register(
            .init(statusCode: 503, data: Data()),
            for: "https://api.frankfurter.dev/v2/rates?base=PLN"
        )

        let error = await #expect(throws: AppError.self) {
            _ = try await api.fetchExchangeRates(baseCurrency: "PLN")
        }
        guard case let .retryExhausted(_, attempts) = error else {
            Issue.record("Expected .retryExhausted, got \(String(describing: error))")
            return
        }
        #expect(attempts == 3)
    }

    @Test("an empty v2 array is rejected rather than accepted as a rateless snapshot")
    func emptyResponseIsRejected() async throws {
        StubURLProtocol.register(
            .init(statusCode: 200, data: Data("[]".utf8)),
            for: "https://api.frankfurter.dev/v2/rates?base=DKK"
        )

        await #expect(throws: AppError.self) {
            _ = try await api.fetchExchangeRates(baseCurrency: "DKK")
        }
    }

    @Test("a range with no publication days decodes to an empty series rather than throwing")
    func emptyHistoricalRangeDecodesToEmptySeries() async throws {
        let startDate = try #require(createCETDate(year: 2025, month: 3, day: 15))
        let endDate = try #require(createCETDate(year: 2025, month: 3, day: 16))
        StubURLProtocol.register(
            .init(statusCode: 200, data: Data("[]".utf8)),
            for: "https://api.frankfurter.dev/v2/rates?base=USD&from=2025-03-15&to=2025-03-16"
        )

        let response = try await api.fetchHistoricalRatesForRange(startDate: startDate, endDate: endDate)

        #expect(response.rates.isEmpty)
    }

    @Test("a range padded with rates dated before the requested start keeps only the requested days")
    func paddedRangeKeepsOnlyRequestedDays() async throws {
        let startDate = try #require(createCETDate(year: 2026, month: 10, day: 10))
        let endDate = try #require(createCETDate(year: 2026, month: 10, day: 12))
        StubURLProtocol.register(
            .init(statusCode: 200, data: Self.v2JSON([
                (date: "2026-10-08", quote: "KPW", rate: 130.02),
                (date: "2026-10-09", quote: "ALL", rate: 82.1),
                (date: "2026-10-10", quote: "EUR", rate: 0.8913),
                (date: "2026-10-11", quote: "EUR", rate: 0.8912),
                (date: "2026-10-12", quote: "EUR", rate: 0.8926),
            ])),
            for: "https://api.frankfurter.dev/v2/rates?base=USD&from=2026-10-10&to=2026-10-12"
        )

        let response = try await api.fetchHistoricalRatesForRange(startDate: startDate, endDate: endDate)

        #expect(response.rates.keys.sorted() == ["2026-10-10", "2026-10-11", "2026-10-12"])
        #expect(response.startDate == "2026-10-10")
    }

    @Test("the first requested day carries rates the padding dated before it")
    func firstRequestedDayCarriesPaddedRates() async throws {
        let startDate = try #require(createCETDate(year: 2026, month: 10, day: 17))
        let endDate = try #require(createCETDate(year: 2026, month: 10, day: 18))
        StubURLProtocol.register(
            .init(statusCode: 200, data: Self.v2JSON([
                (date: "2026-10-15", quote: "KPW", rate: 130.02),
                (date: "2026-10-16", quote: "ALL", rate: 82.1),
                (date: "2026-10-17", quote: "EUR", rate: 0.8906),
                (date: "2026-10-18", quote: "EUR", rate: 0.8905),
            ])),
            for: "https://api.frankfurter.dev/v2/rates?base=USD&from=2026-10-17&to=2026-10-18"
        )

        let response = try await api.fetchHistoricalRatesForRange(startDate: startDate, endDate: endDate)

        #expect(response.rates["2026-10-17"] == ["EUR": 0.8906, "KPW": 130.02, "ALL": 82.1])
    }

    @Test("a range answered only with padding decodes to an empty series rather than throwing")
    func paddingOnlyRangeDecodesToEmptySeries() async throws {
        let startDate = try #require(createCETDate(year: 2026, month: 10, day: 24))
        let endDate = try #require(createCETDate(year: 2026, month: 10, day: 25))
        StubURLProtocol.register(
            .init(statusCode: 200, data: Self.v2JSON([
                (date: "2026-10-23", quote: "EUR", rate: 0.8901),
            ])),
            for: "https://api.frankfurter.dev/v2/rates?base=USD&from=2026-10-24&to=2026-10-25"
        )

        let response = try await api.fetchHistoricalRatesForRange(startDate: startDate, endDate: endDate)

        #expect(response.rates.isEmpty)
        #expect(response.startDate.isEmpty)
    }
}
