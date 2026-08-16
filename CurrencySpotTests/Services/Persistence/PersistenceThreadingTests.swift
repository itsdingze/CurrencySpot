@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("Persistence threading")
struct PersistenceThreadingTests {
    @Test("SwiftData work runs off the main thread even when the service is built on it")
    func persistenceRunsOffMainThread() async throws {
        let container = try ModelContainer.inMemoryCurrencySpot()
        let service = SwiftDataPersistenceService(modelContainer: container)

        #expect(await service.isExecutingOnMainThread() == false)
    }
}
