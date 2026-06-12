//
//  PersistenceThreadingTests.swift
//  CurrencySpotTests
//
//  Regression guard for the launch-freeze bug: @ModelActor's DefaultSerialModelExecutor
//  runs jobs on the main thread (regardless of where the actor is created), so the
//  persistence actor uses its own DispatchSerialQueue executor instead. If this test
//  fails, SwiftData saves and fetches are blocking the UI again.
//

@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Persistence threading")
struct PersistenceThreadingTests {
    @Test("SwiftData work runs off the main thread even when the service is built on it")
    func persistenceRunsOffMainThread() async throws {
        // Built on the main actor, exactly like DependencyContainer.bootstrap does.
        let container = try ModelContainer.inMemoryCurrencySpot()
        let service = SwiftDataPersistenceService(modelContainer: container)

        #expect(await service.isExecutingOnMainThread() == false)
    }
}
