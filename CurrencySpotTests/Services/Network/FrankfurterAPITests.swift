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

    static func register(_ stub: Stub, for url: String) {
        stubs.withLock { $0[url] = stub }
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
        guard let url = request.url, let stub = Self.stub(for: url.absoluteString) else {
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
    private let api = FrankfurterAPI(session: StubURLProtocol.makeSession(), retryManager: RetryManager())

    private static func v2JSON(_ entries: [(date: String, quote: String, rate: Double)], base: String = "USD") -> Data {
        let rows = entries.map {
            #"{"date": "\#($0.date)", "base": "\#(base)", "quote": "\#($0.quote)", "rate": \#($0.rate)}"#
        }
        return Data("[\(rows.joined(separator: ","))]".utf8)
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
}
