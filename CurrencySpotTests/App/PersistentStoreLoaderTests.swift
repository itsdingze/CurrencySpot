@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("PersistentStoreLoader")
struct PersistentStoreLoaderTests {
    private let directory: URL
    private let storeURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "PersistentStoreLoaderTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appending(path: "default.store")
    }

    private func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("an unreadable store is deleted, the reset hook runs once, and a fresh store opens on disk")
    func corruptStoreIsRebuilt() throws {
        defer { removeDirectory() }
        try Data("not a database".utf8).write(to: storeURL)
        var resetCount = 0

        let container = try PersistentStoreLoader(storeURL: storeURL).load(onStoreReset: { resetCount += 1 })

        #expect(resetCount == 1)
        let context = ModelContext(container)
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.9))
        try context.save()
        let reopened = ModelContext(try ModelContainer.currencySpot(storeURL: storeURL))
        #expect(try reopened.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
    }

    @Test("a healthy store opens with its rows and never triggers a reset")
    func healthyStoreOpensUntouched() throws {
        defer { removeDirectory() }
        let seeded = ModelContext(try ModelContainer.currencySpot(storeURL: storeURL))
        seeded.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.9))
        try seeded.save()
        var resetCount = 0

        let container = try PersistentStoreLoader(storeURL: storeURL).load(onStoreReset: { resetCount += 1 })

        #expect(resetCount == 0)
        #expect(try ModelContext(container).fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
    }
}
