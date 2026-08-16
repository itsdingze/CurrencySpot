import Foundation

nonisolated enum FrankfurterV2Mapper {
    static func latest(from entries: [FrankfurterV2Rate], base: String) throws -> ExchangeRatesResponse {
        guard !entries.isEmpty else {
            throw AppError.dataValidationError("Rate response contained no entries")
        }
        try validate(entries)
        let rates = Dictionary(entries.map { ($0.quote, $0.rate) }, uniquingKeysWith: { _, latest in latest })
        let date = entries.map(\.date).max() ?? ""
        return ExchangeRatesResponse(base: base, date: date, rates: rates)
    }

    // An empty range is a legitimate answer here (no publication days), and it must map to an
    // empty response rather than throw: the caller records the coverage watermark only on a
    // successful fetch, so throwing would leave those days permanently un-checked and refetched.
    static func historical(from entries: [FrankfurterV2Rate], base: String) throws -> HistoricalRatesResponse {
        try validate(entries)
        var grouped: [String: [String: Double]] = [:]
        for entry in entries {
            grouped[entry.date, default: [:]][entry.quote] = entry.rate
        }

        let sortedDates = grouped.keys.sorted()
        let allCurrencies = Set(entries.map(\.quote))
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
            rates[date] = row
        }

        return HistoricalRatesResponse(
            base: base,
            startDate: sortedDates.first ?? "",
            endDate: sortedDates.last ?? "",
            rates: rates
        )
    }

    private static func validate(_ entries: [FrankfurterV2Rate]) throws {
        for entry in entries {
            _ = try CurrencyCode(validating: entry.quote)
            guard entry.rate.isFinite, entry.rate > 0 else {
                throw AppError.dataValidationError("Invalid rate \(entry.rate) for \(entry.quote)")
            }
            guard TimeZoneManager.parseAPIDate(entry.date) != nil else {
                throw AppError.dataValidationError("Unparseable date '\(entry.date)' for \(entry.quote)")
            }
        }
    }
}
