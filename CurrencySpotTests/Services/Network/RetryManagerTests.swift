@testable import CurrencySpot
import Foundation
import Testing

@Suite("RetryManager Tests")
struct RetryManagerTests {
    @Test("snapshot reflects attempts, exhaustion, and reset under a single isolation hop")
    func snapshotTracksLifecycle() async {
        let manager = RetryManager(jitter: { _ in 1.0 })
        let endpoint = "snapshot-endpoint"

        var snapshot = await manager.snapshot(for: endpoint)
        #expect(snapshot.attempt == 0)
        #expect(snapshot.maxAttempts == 3)
        #expect(snapshot.canRetry)

        _ = await manager.recordAttempt(for: endpoint)
        snapshot = await manager.snapshot(for: endpoint)
        #expect(snapshot.attempt == 1)
        #expect(snapshot.canRetry)

        while await manager.recordAttempt(for: endpoint) != nil {}
        snapshot = await manager.snapshot(for: endpoint)
        #expect(snapshot.attempt == snapshot.maxAttempts)
        #expect(snapshot.canRetry == false)

        await manager.recordSuccess(for: endpoint)
        snapshot = await manager.snapshot(for: endpoint)
        #expect(snapshot.attempt == 0)
        #expect(snapshot.canRetry)
    }

    @Test("server errors are retried, client errors are not", arguments: [
        (500, true), (503, true), (599, true), (400, false), (404, false), (429, false),
    ])
    func retriesOnlyServerErrors(statusCode: Int, isRetryable: Bool) {
        let manager = RetryManager()

        #expect(manager.shouldRetry(error: AppError.httpError(statusCode: statusCode)) == isRetryable)
    }

    @Test("a success opens a fresh retry ladder instead of freezing the endpoint")
    func retriesResumeAfterSuccess() async {
        let manager = RetryManager(jitter: { _ in 1.0 })
        let endpoint = "post-success-endpoint"

        await manager.recordSuccess(for: endpoint)

        let firstRetry = await manager.recordAttempt(for: endpoint)
        #expect(firstRetry?.attempt == 1)

        var snapshot = await manager.snapshot(for: endpoint)
        #expect(snapshot.attempt == 1)
        #expect(snapshot.canRetry)

        while await manager.recordAttempt(for: endpoint) != nil {}
        snapshot = await manager.snapshot(for: endpoint)
        #expect(snapshot.attempt == snapshot.maxAttempts)
        #expect(snapshot.canRetry == false)
    }
}
