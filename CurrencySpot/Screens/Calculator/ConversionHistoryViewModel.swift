import Foundation
import Observation

@Observable
final class ConversionHistoryViewModel {
    struct Section: Identifiable {
        let day: Date
        let records: [ConversionRecord]

        var id: Date { day }
    }

    private let store: ConversionHistoryStore
    private let calendar: Calendar
    private let locale: Locale
    private let restoreRecord: (ConversionRecord) -> Void
    private let dayFormatter: DateFormatter

    init(
        store: ConversionHistoryStore,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        restore: @escaping (ConversionRecord) -> Void
    ) {
        self.store = store
        self.calendar = calendar
        self.locale = locale
        restoreRecord = restore
        dayFormatter = DateFormatter()
        dayFormatter.locale = locale
        dayFormatter.calendar = calendar
        dayFormatter.timeZone = calendar.timeZone
        dayFormatter.dateStyle = .medium
        dayFormatter.doesRelativeDateFormatting = true
    }

    var sections: [Section] {
        let newestFirst = store.records.sorted { $0.date > $1.date }
        let days = Dictionary(grouping: newestFirst) { calendar.startOfDay(for: $0.date) }
        return days.keys.sorted(by: >).map { day in Section(day: day, records: days[day] ?? []) }
    }

    var isEmpty: Bool { store.records.isEmpty }

    func title(for section: Section) -> String {
        dayFormatter.string(from: section.day)
    }

    func summary(for record: ConversionRecord) -> String {
        let amount = text(for: record.amount, in: record.base)
        guard let calculation = record.calculation else { return amount }
        return "\(calculation.steps(locale: locale)) = \(amount)"
    }

    func convertedAmount(for record: ConversionRecord) -> String {
        text(for: record.converted, in: record.target)
    }

    private func text(for amount: Decimal, in currency: CurrencyCode) -> String {
        amount.amountText(in: currency, locale: locale)
    }

    func choose(_ record: ConversionRecord) {
        restoreRecord(record)
    }

    func delete(ids: Set<ConversionRecord.ID>) {
        store.delete(ids: ids)
    }

    func clearAll() {
        store.clear()
    }
}
