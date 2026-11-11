import Foundation

enum PersistentStoreFiles {
    private static let suffixes = ["", "-wal", "-shm"]

    static func exists(at storeURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false))
    }

    static func remove(at storeURL: URL) throws {
        for file in files(of: storeURL) where exists(at: file) {
            try FileManager.default.removeItem(at: file)
        }
    }

    static func move(from source: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try remove(at: destination)
        var moved: [(from: URL, to: URL)] = []
        do {
            for (from, to) in zip(files(of: source), files(of: destination)) where exists(at: from) {
                try FileManager.default.moveItem(at: from, to: to)
                moved.append((from, to))
            }
        } catch {
            for file in moved.reversed() {
                try? FileManager.default.moveItem(at: file.to, to: file.from)
            }
            throw error
        }
    }

    static func isSameStore(_ first: URL, _ second: URL) -> Bool {
        first.standardizedFileURL.resolvingSymlinksInPath() == second.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func files(of storeURL: URL) -> [URL] {
        suffixes.map { URL(filePath: storeURL.path(percentEncoded: false) + $0) }
    }
}
