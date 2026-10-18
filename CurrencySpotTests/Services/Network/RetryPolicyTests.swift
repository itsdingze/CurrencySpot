@testable import CurrencySpot
import Foundation
import Testing

@Suite("RetryPolicy Tests")
struct RetryPolicyTests {
    @Test("server errors are retried, client errors are not", arguments: [
        (500, true), (503, true), (599, true), (400, false), (404, false), (429, false),
    ])
    func retriesOnlyServerErrors(statusCode: Int, isRetryable: Bool) {
        #expect(RetryPolicy().shouldRetry(AppError.httpError(statusCode: statusCode)) == isRetryable)
    }

    @Test("transient connection failures are retried, a bad URL is not", arguments: [
        (URLError.Code.timedOut, true), (.networkConnectionLost, true), (.notConnectedToInternet, true), (.badURL, false),
    ])
    func retriesTransientURLErrors(code: URLError.Code, isRetryable: Bool) {
        #expect(RetryPolicy().shouldRetry(URLError(code)) == isRetryable)
    }

    @Test("delays never shrink from one retry to the next and stay within the cap")
    func delaysGrowWithinTheCap() {
        let policy = RetryPolicy(maxRetries: 6, baseDelay: 1, maxDelay: 8, jitter: { _ in 1.0 })

        let delays = (1 ... 6).map(policy.delay(beforeRetry:))

        #expect(zip(delays, delays.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(delays.allSatisfy { $0 > 0 && $0 <= 8 })
    }
}
