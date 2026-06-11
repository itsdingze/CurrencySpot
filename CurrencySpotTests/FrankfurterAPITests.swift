//
//  FrankfurterAPITests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation
import Testing

// MARK: - URLProtocol Stub

/// Intercepts every request on a stubbed session and serves canned responses keyed by
/// absolute URL. Keying by URL (instead of a single shared handler) keeps parallel
/// tests independent — each test registers its own unique URL.
private final class StubURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let data: Data
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var stubs: [String: Stub] = [:]

    static func register(_ stub: Stub, for url: String) {
        lock.lock()
        defer { lock.unlock() }
        stubs[url] = stub
    }

    private static func stub(for url: String) -> Stub? {
        lock.lock()
        defer { lock.unlock() }
        return stubs[url]
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stub = Self.stub(for: url.absoluteString) else {
            // An unregistered URL means the client built a different URL than the test
            // expected — fail the request so the test fails instead of hitting the network.
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = HTTPURLResponse(
            url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Tests

@Suite("FrankfurterAPI Tests")
struct FrankfurterAPITests {
    private let api = FrankfurterAPI(session: StubURLProtocol.makeSession())

    private static func v2JSON(_ entries: [(date: String, quote: String, rate: Double)], base: String = "USD") -> Data {
        let rows = entries.map {
            #"{"date": "\#($0.date)", "base": "\#(base)", "quote": "\#($0.quote)", "rate": \#($0.rate)}"#
        }
        return Data("[\(rows.joined(separator: ","))]".utf8)
    }

    @Test("fetchExchangeRates builds the latest endpoint URL and decodes through the v2 mapper")
    func latestEndpointHappyPath() async throws {
        // Registering the stub at exactly this URL also asserts URL construction:
        // any other URL fails with .unsupportedURL.
        StubURLProtocol.register(
            .init(statusCode: 200, data: Self.v2JSON([
                (date: "2025-03-14", quote: "EUR", rate: 0.91),
                (date: "2025-03-13", quote: "GBP", rate: 0.78),
            ], base: "CHF")),
            for: "https://api.frankfurter.dev/v2/rates?base=CHF"
        )

        let response = try await api.fetchExchangeRates(baseCurrency: "CHF")

        #expect(response.base == "CHF")
        #expect(response.date == "2025-03-14") // most recent across per-currency dates
        #expect(response.rates == ["EUR": 0.91, "GBP": 0.78])
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
        #expect(response.start_date == "2025-03-10")
        #expect(response.end_date == "2025-03-12")
        #expect(response.rates["2025-03-11"] == ["EUR": 0.91])
        #expect(response.rates.count == 3)
    }

    @Test("a non-2xx response maps to AppError.apiError with the status code")
    func httpErrorMapsToAPIError() async {
        // 404 is deliberately non-retryable, so the request fails immediately
        // instead of sleeping through the retry backoff.
        StubURLProtocol.register(
            .init(statusCode: 404, data: Data()),
            for: "https://api.frankfurter.dev/v2/rates?base=NOK"
        )

        await #expect(throws: AppError.apiError("HTTP Error: 404")) {
            _ = try await api.fetchExchangeRates(baseCurrency: "NOK")
        }
    }

    @Test("malformed JSON maps to AppError.decodingError")
    func malformedJSONMapsToDecodingError() async {
        StubURLProtocol.register(
            .init(statusCode: 200, data: Data(#"{"unexpected": "shape"}"#.utf8)),
            for: "https://api.frankfurter.dev/v2/rates?base=SEK"
        )

        do {
            _ = try await api.fetchExchangeRates(baseCurrency: "SEK")
            Issue.record("Expected a decoding error to be thrown.")
        } catch let error as AppError {
            guard case .decodingError = error else {
                Issue.record("Expected .decodingError, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected AppError.decodingError, got \(error)")
        }
    }

    @Test("an empty v2 array decodes to an empty rates dictionary")
    func emptyResponseDecodesToEmptyRates() async throws {
        StubURLProtocol.register(
            .init(statusCode: 200, data: Data("[]".utf8)),
            for: "https://api.frankfurter.dev/v2/rates?base=DKK"
        )

        let response = try await api.fetchExchangeRates(baseCurrency: "DKK")

        #expect(response.rates.isEmpty)
        #expect(response.date.isEmpty)
    }
}
