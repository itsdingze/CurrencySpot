import Foundation
import OSLog

nonisolated struct RateSeriesCache: Sendable {
    private static let logger = Logger(category: .cache)

    let directory: URL

    func load(for request: RateSeriesRequest) -> RateSeriesSnapshot? {
        guard let data = try? Data(contentsOf: fileURL(for: request)) else { return nil }
        return try? JSONDecoder().decode(RateSeriesSnapshot.self, from: data)
    }

    func save(_ snapshot: RateSeriesSnapshot, for request: RateSeriesRequest) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: fileURL(for: request), options: .atomic)
        } catch {
            Self.logger.error("Failed to save rate series: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fileURL(for request: RateSeriesRequest) -> URL {
        let currencies = request.currencies.map(\.rawValue).joined(separator: "-")
        return directory.appending(path: "\(request.base.rawValue)_\(currencies)_\(request.period.rawValue).json")
    }
}
