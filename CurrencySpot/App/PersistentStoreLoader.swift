import CoreData
import Foundation
import SwiftData

struct PersistentStoreLoader {
    let storeURL: URL

    func load(onStoreReset: () -> Void) throws -> ModelContainer {
        do {
            return try ModelContainer.currencySpot(storeURL: storeURL)
        } catch {
            guard storeIsUnusable() else { throw error }
            return try rebuild(onStoreReset: onStoreReset)
        }
    }

    private func storeIsUnusable() -> Bool {
        do {
            _ = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeURL)
            return true
        } catch let error as NSError {
            return Self.isDamagedFile(error)
        }
    }

    private static func isDamagedFile(_ error: NSError) -> Bool {
        switch (error.domain, error.code) {
        case (NSSQLiteErrorDomain, 11), (NSSQLiteErrorDomain, 26), (NSCocoaErrorDomain, NSFileReadCorruptFileError):
            true
        default:
            false
        }
    }

    private func rebuild(onStoreReset: () -> Void) throws -> ModelContainer {
        try PersistentStoreFiles.remove(at: storeURL)
        onStoreReset()
        return try ModelContainer.currencySpot(storeURL: storeURL)
    }
}
