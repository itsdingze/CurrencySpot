import Foundation

nonisolated final class TemporaryStoreDirectory {
    private let directory: URL
    let storeURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "TemporaryStoreDirectory-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appending(path: "default.store")
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}
