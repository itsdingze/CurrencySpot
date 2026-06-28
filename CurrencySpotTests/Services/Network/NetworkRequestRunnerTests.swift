//
//  NetworkRequestRunnerTests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation
import Testing

// MARK: - Failing URLProtocols

/// Fails every request the way URLSession reports a cancelled task.
private nonisolated final class CancelledURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }

    override func stopLoading() {}
}

/// Serves HTTP 500 for every request, making each attempt a retryable failure.
private nonisolated final class ServerErrorURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 500, httpVersion: "HTTP/1.1", headerFields: nil
        )!
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
    @Test("URLSession cancellation surfaces as CancellationError and records no retry state", .timeLimit(.minutes(1)))
    func cancellationMapsToCancellationError() async {
        let retryManager = RetryManager(jitter: { _ in 1.0 })
        let endpoint = "cancelled-endpoint"

        await #expect(throws: CancellationError.self) {
            let _: [String] = try await NetworkRequestRunner.performRequestWithRetry(
                url: URL(string: "https://stub.test/cancelled")!,
                urlSession: makeSession(CancelledURLProtocol.self),
                responseType: [String].self,
                endpoint: endpoint,
                retryManager: retryManager,
                clock: ImmediateClock()
            )
        }

        // Cancellation must not leave attempt state behind for the next request.
        let snapshot = await retryManager.snapshot(for: endpoint)
        #expect(snapshot.attempt == 0)
        #expect(snapshot.canRetry)
    }

    @Test("Retryable server errors exhaust all attempts through the injected clock", .timeLimit(.minutes(1)))
    func serverErrorsExhaustRetries() async {
        let retryManager = RetryManager(jitter: { _ in 1.0 })
        let endpoint = "exhaust-endpoint"

        do {
            let _: [String] = try await NetworkRequestRunner.performRequestWithRetry(
                url: URL(string: "https://stub.test/server-error")!,
                urlSession: makeSession(ServerErrorURLProtocol.self),
                responseType: [String].self,
                endpoint: endpoint,
                retryManager: retryManager,
                clock: ImmediateClock()
            )
            Issue.record("expected retryExhausted, got success")
        } catch let error as AppError {
            guard case let .retryExhausted(_, attempts) = error else {
                Issue.record("expected retryExhausted, got \(error)")
                return
            }
            #expect(attempts == 3)
        } catch {
            Issue.record("expected AppError.retryExhausted, got \(error)")
        }

        let snapshot = await retryManager.snapshot(for: endpoint)
        #expect(!snapshot.canRetry)
    }
}
