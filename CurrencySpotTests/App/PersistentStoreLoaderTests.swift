@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Suite("PersistentStoreLoader")
struct PersistentStoreLoaderTests {
    private let store: TemporaryStoreDirectory

    init() throws {
        store = try TemporaryStoreDirectory()
    }

    @Test("an unreadable store is deleted, the reset hook runs once, and a fresh store opens on disk")
    func corruptStoreIsRebuilt() throws {
        try Data("not a database".utf8).write(to: store.storeURL)
        var resetCount = 0

        let container = try PersistentStoreLoader(storeURL: store.storeURL).load(onStoreReset: { resetCount += 1 })

        #expect(resetCount == 1)
        let context = ModelContext(container)
        context.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.9))
        try context.save()
        let reopened = ModelContext(try ModelContainer.currencySpot(storeURL: store.storeURL))
        #expect(try reopened.fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
    }

    @Test("an unreadable store's file, -wal and -shm are all deleted before the reset hook runs")
    func storeFilesAreGoneWhenResetIsReported() throws {
        let storeFiles = ["", "-wal", "-shm"].map { URL(filePath: store.storeURL.path(percentEncoded: false) + $0) }
        for file in storeFiles {
            try Data("not a database".utf8).write(to: file)
        }
        var filesLeftAtReset: [String]?

        _ = try PersistentStoreLoader(storeURL: store.storeURL).load(onStoreReset: {
            filesLeftAtReset = storeFiles
                .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
                .map(\.lastPathComponent)
        })

        #expect(filesLeftAtReset == [])
    }

    @Test("a healthy store opens with its rows and never triggers a reset")
    func healthyStoreOpensUntouched() throws {
        let seeded = ModelContext(try ModelContainer.currencySpot(storeURL: store.storeURL))
        seeded.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.9))
        try seeded.save()
        var resetCount = 0

        let container = try PersistentStoreLoader(storeURL: store.storeURL).load(onStoreReset: { resetCount += 1 })

        #expect(resetCount == 0)
        #expect(try ModelContext(container).fetch(FetchDescriptor<ExchangeRateData>()).count == 1)
    }
}
