import Foundation
import SwiftData

struct PersistentStoreLoader {
    let storeURL: URL

    func load(onStoreReset: () -> Void) throws -> ModelContainer {
        do {
            return try ModelContainer.currencySpot(storeURL: storeURL)
        } catch {
            return try rebuild(onStoreReset: onStoreReset)
        }
    }

    private func rebuild(onStoreReset: () -> Void) throws -> ModelContainer {
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(filePath: storeURL.path(percentEncoded: false) + suffix)
            if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: file)
            }
        }
        onStoreReset()
        return try ModelContainer.currencySpot(storeURL: storeURL)
    }
}
