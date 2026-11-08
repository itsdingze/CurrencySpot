import Foundation

nonisolated enum FrankfurterV2Mapper {
    static func latest(from entries: [FrankfurterV2Rate], base: String) throws -> ExchangeRatesResponse {
        let currencies = currencyEntries(entries)
        guard !currencies.isEmpty else {
            throw AppError.dataValidationError("Rate response contained no entries")
        }
        try validate(currencies)
        let rates = Dictionary(currencies.map { ($0.quote, $0.rate) }, uniquingKeysWith: { _, latest in latest })
        let date = currencies.map(\.date).max() ?? ""
        return ExchangeRatesResponse(base: base, date: date, rates: rates)
    }

    private static func currencyEntries(_ entries: [FrankfurterV2Rate]) -> [FrankfurterV2Rate] {
        entries.filter { CurrencyCode($0.quote) != nil }
    }

    static func historical(from entries: [FrankfurterV2Rate], base: String, startingOn firstDay: String) throws -> HistoricalRatesResponse {
        let currencies = currencyEntries(entries)
        try validate(currencies)
        var grouped: [String: [String: Double]] = [:]
        for entry in currencies {
            grouped[entry.date, default: [:]][entry.quote] = entry.rate
        }

        let sortedDates = grouped.keys.sorted()
        let allCurrencies = Set(currencies.map(\.quote))
        var lastKnown: [String: Double] = [:]
        var rates: [String: [String: Double]] = [:]

        for date in sortedDates {
            var row = grouped[date] ?? [:]
            for currency in allCurrencies {
                if let rate = row[currency] {
                    lastKnown[currency] = rate
                } else if let carried = lastKnown[currency] {
                    row[currency] = carried
                }
            }
            guard date >= firstDay else { continue }
            rates[date] = row
        }

        let requestedDates = rates.keys.sorted()
        return HistoricalRatesResponse(
            base: base,
            startDate: requestedDates.first ?? "",
            endDate: requestedDates.last ?? "",
            rates: rates
        )
    }

    private static func validate(_ entries: [FrankfurterV2Rate]) throws {
        var validDates = Set<String>()
        for entry in entries {
            guard entry.rate.isFinite, entry.rate > 0 else {
                throw AppError.dataValidationError("Invalid rate \(entry.rate) for \(entry.quote)")
            }
            guard validDates.contains(entry.date) || CETCalendar.date(fromDayString: entry.date) != nil else {
                throw AppError.dataValidationError("Unparseable date '\(entry.date)' for \(entry.quote)")
            }
            validDates.insert(entry.date)
        }
    }
}
