import Foundation

enum PersistentStoreFiles {
    static func remove(at storeURL: URL) throws {
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(filePath: storeURL.path(percentEncoded: false) + suffix)
            if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: file)
            }
        }
    }

    static func isSameStore(_ first: URL, _ second: URL) -> Bool {
        first.standardizedFileURL.resolvingSymlinksInPath() == second.standardizedFileURL.resolvingSymlinksInPath()
    }
}
