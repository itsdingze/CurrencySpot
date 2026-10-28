import Foundation
import Observation
import os

@Observable
final class ConversionHistoryStore {
    private(set) var records: [ConversionRecord]

    private let defaults: UserDefaults
    private let key = UserDefaultsKeys.conversionHistory
    private static let limit = 100
    private static let logger = Logger(category: .data)

    init(defaults: UserDefaults) {
        self.defaults = defaults
        records = Self.load(from: defaults.data(forKey: key))
    }

    func add(_ record: ConversionRecord) {
        records = Array(([record] + records).prefix(Self.limit))
        persist()
    }

    func delete(ids: Set<ConversionRecord.ID>) {
        records.removeAll { ids.contains($0.id) }
        persist()
    }

    func clear() {
        records = []
        persist()
    }

    private func persist() {
        do {
            defaults.set(try JSONEncoder().encode(records), forKey: key)
        } catch {
            Self.logger.error("Conversion history was not saved: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load(from data: Data?) -> [ConversionRecord] {
        guard let data else { return [] }
        do {
            let entries = try JSONDecoder().decode([StoredEntry].self, from: data)
            let records = entries.compactMap(\.record)
            if records.count < entries.count {
                logger.error("Skipped \(entries.count - records.count) unreadable conversion history entries")
            }
            return records
        } catch {
            logger.error("Conversion history could not be read: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

private nonisolated struct StoredEntry: Decodable {
    let record: ConversionRecord?

    init(from decoder: Decoder) throws {
        record = try? ConversionRecord(from: decoder)
    }
}
