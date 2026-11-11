@testable import CurrencySpot
import Foundation
import SwiftData
import Testing

@Model
private nonisolated final class UnknownModel {
    var name: String

    init(name: String) {
        self.name = name
    }
}

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

    @Test("a store the app can't read right now stays on disk with its rows instead of being rebuilt")
    func unreadableStoreIsKept() throws {
        let seeded = ModelContext(try ModelContainer.currencySpot(storeURL: store.storeURL))
        seeded.insert(ExchangeRateData(currencyCode: "EUR", rate: 0.9))
        try seeded.save()
        let storeFiles = ["", "-wal", "-shm"]
            .map { store.storeURL.path(percentEncoded: false) + $0 }
            .filter { FileManager.default.fileExists(atPath: $0) }
        for file in storeFiles {
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file)
        }
        defer {
            for file in storeFiles {
                try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file)
            }
        }
        var resetCount = 0

        #expect(throws: (any Error).self) {
            _ = try PersistentStoreLoader(storeURL: store.storeURL).load(onStoreReset: { resetCount += 1 })
        }

        #expect(resetCount == 0)
        for file in storeFiles {
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file)
        }
        let reopened = ModelContext(try ModelContainer.currencySpot(storeURL: store.storeURL))
        #expect(try reopened.fetchCount(FetchDescriptor<ExchangeRateData>()) == 1)
    }

    @Test("a store written by a model this version doesn't know is rebuilt")
    func incompatibleStoreIsRebuilt() throws {
        let unknown = try ModelContainer(for: Schema([UnknownModel.self]), configurations: ModelConfiguration(url: store.storeURL))
        unknown.mainContext.insert(UnknownModel(name: "left over"))
        try unknown.mainContext.save()
        var resetCount = 0

        let container = try PersistentStoreLoader(storeURL: store.storeURL).load(onStoreReset: { resetCount += 1 })

        #expect(resetCount == 1)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExchangeRateData>()) == 0)
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
