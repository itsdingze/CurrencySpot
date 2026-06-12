//
//  RetryManagerTests.swift
//  CurrencySpotTests
//

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
        #expect(!snapshot.canRetry)

        await manager.recordSuccess(for: endpoint)
        snapshot = await manager.snapshot(for: endpoint)
        #expect(snapshot.attempt == 0)
        #expect(snapshot.canRetry)
    }
}
