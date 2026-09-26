import Foundation

nonisolated struct HistoricalRatePoint: Identifiable, Equatable, Sendable {
    let currencyCode: CurrencyCode
    let rate: Double

    var id: CurrencyCode { currencyCode }
}

nonisolated struct HistoricalRateSnapshot: Identifiable, Equatable, Sendable {
    let date: Date
    let rates: [HistoricalRatePoint]

    var id: Date { date }

    init(dateString: String, rates: [HistoricalRatePoint]) throws {
        guard let date = TimeZoneManager.parseAPIDate(dateString) else {
            throw AppError.dataValidationError("Invalid date string: \(dateString)")
        }
        self.date = date
        self.rates = rates
    }

    init(date: Date, rates: [HistoricalRatePoint]) {
        self.date = date
        self.rates = rates
    }
}

nonisolated extension HistoricalRateSnapshot {
    static func merge(existing: [HistoricalRateSnapshot], new: [HistoricalRateSnapshot]) -> [HistoricalRateSnapshot] {
        let calendar = TimeZoneManager.cetCalendar
        var byDay: [Date: HistoricalRateSnapshot] = [:]
        for item in existing {
            byDay[calendar.startOfDay(for: item.date)] = item
        }
        for item in new {
            byDay[calendar.startOfDay(for: item.date)] = item
        }
        return byDay.values.sorted { $0.date < $1.date }
    }
}
