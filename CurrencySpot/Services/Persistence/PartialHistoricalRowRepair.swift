import Foundation
import OSLog
import SwiftData

enum PartialHistoricalRowRepair {
    private static let repairedKey = "DidRepairPartialHistoricalRows"
    private static let partialQuoteShare = 0.9

    private static let logger = Logger(category: .data)

    static func runIfNeeded(modelContainer: ModelContainer, defaults: UserDefaults) {
        guard !defaults.bool(forKey: repairedKey) else { return }

        do {
            try repair(context: modelContainer.mainContext, syncStore: UserDefaultsHistoricalSyncStore(defaults: defaults))
        } catch {
            logger.error("Partial historical row repair failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        defaults.set(true, forKey: repairedKey)
    }

    private static func repair(context: ModelContext, syncStore: HistoricalSyncStore) throws {
        let rows = try context.fetch(FetchDescriptor<HistoricalRateData>(sortBy: [SortDescriptor(\.date)]))
        guard let newestPartialDay = newestPartialDay(in: rows) else { return }

        let keptDays = rows.map(\.date).filter { $0 > newestPartialDay }
        for row in rows where row.date <= newestPartialDay {
            context.delete(row)
        }
        try context.save()
        narrowCoverage(of: syncStore, to: keptDays)
        logger.info("Deleted \(rows.count - keptDays.count, privacy: .public) historical rows through partial day \(CETCalendar.dayString(for: newestPartialDay), privacy: .public)")
    }

    private static func newestPartialDay(in rows: [HistoricalRateData]) -> Date? {
        let days = rows.map { (date: $0.date, quoteCount: (try? $0.toDomain().rates.count) ?? 0) }
        let sortedCounts = days.map(\.quoteCount).sorted()
        guard !sortedCounts.isEmpty else { return nil }

        let threshold = Double(sortedCounts[sortedCounts.count / 2]) * partialQuoteShare
        return days.last { Double($0.quoteCount) < threshold }?.date
    }

    private static func narrowCoverage(of syncStore: HistoricalSyncStore, to keptDays: [Date]) {
        let (from, through, checkedAt) = (syncStore.from, syncStore.through, syncStore.checkedAt)
        syncStore.reset()
        guard let from, let through, let checkedAt, let firstKept = keptDays.first, let lastKept = keptDays.last else { return }

        let narrowedFrom = max(from, firstKept)
        let narrowedThrough = min(through, lastKept)
        guard narrowedFrom <= narrowedThrough else { return }
        syncStore.record(from: narrowedFrom, through: narrowedThrough, at: checkedAt)
    }
}
