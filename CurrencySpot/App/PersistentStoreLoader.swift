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
        try PersistentStoreFiles.remove(at: storeURL)
        onStoreReset()
        return try ModelContainer.currencySpot(storeURL: storeURL)
    }
}
