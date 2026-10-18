@testable import CurrencySpot
import Foundation
import Testing

// MARK: - Failing URLProtocols

private nonisolated final class CancelledURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }

    override func stopLoading() {}
}

private nonisolated final class ServerErrorURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeSession(_ protocolClass: URLProtocol.Type) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [protocolClass]
    return URLSession(configuration: configuration)
}

// MARK: - Tests

@Suite("NetworkRequestRunner Tests")
struct NetworkRequestRunnerTests {
    private static let retryPolicy = RetryPolicy(jitter: { _ in 1.0 })

    @Test("URLSession cancellation surfaces as CancellationError", .timeLimit(.minutes(1)))
    func cancellationMapsToCancellationError() async throws {
        let url = try #require(URL(string: "https://stub.test/cancelled"))

        await #expect(throws: CancellationError.self) {
            let _: [String] = try await NetworkRequestRunner.performRequestWithRetry(
                url: url,
                urlSession: makeSession(CancelledURLProtocol.self),
                responseType: [String].self,
                endpoint: "cancelled-endpoint",
                retryPolicy: Self.retryPolicy,
                clock: ImmediateClock()
            )
        }
    }

    @Test("Retryable server errors exhaust all retries through the injected clock", .timeLimit(.minutes(1)))
    func serverErrorsExhaustRetries() async throws {
        let url = try #require(URL(string: "https://stub.test/server-error"))

        let error = await #expect(throws: AppError.self) {
            let _: [String] = try await NetworkRequestRunner.performRequestWithRetry(
                url: url,
                urlSession: makeSession(ServerErrorURLProtocol.self),
                responseType: [String].self,
                endpoint: "exhaust-endpoint",
                retryPolicy: Self.retryPolicy,
                clock: ImmediateClock()
            )
        }
        guard case let .retryExhausted(_, attempts) = error else {
            Issue.record("expected retryExhausted, got \(String(describing: error))")
            return
        }
        #expect(attempts == 3)
    }

    @Test("a request after an exhausted one gets its own full set of retries", .timeLimit(.minutes(1)))
    func exhaustionDoesNotCarryOverToTheNextRequest() async throws {
        let url = try #require(URL(string: "https://stub.test/server-error"))

        for _ in 0 ..< 2 {
            let error = await #expect(throws: AppError.self) {
                let _: [String] = try await NetworkRequestRunner.performRequestWithRetry(
                    url: url,
                    urlSession: makeSession(ServerErrorURLProtocol.self),
                    responseType: [String].self,
                    endpoint: "repeat-endpoint",
                    retryPolicy: Self.retryPolicy,
                    clock: ImmediateClock()
                )
            }
            guard case let .retryExhausted(_, attempts) = error else {
                Issue.record("expected retryExhausted, got \(String(describing: error))")
                return
            }
            #expect(attempts == 3)
        }
    }
}
